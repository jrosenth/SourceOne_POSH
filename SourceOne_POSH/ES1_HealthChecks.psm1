<#	
	.NOTES
	===========================================================================
 
	Copyright © 2018 Dell Inc. or its subsidiaries. All Rights Reserved.

    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at
	       http://www.apache.org/licenses/LICENSE-2.0
	===========================================================================
	THIS CODE AND INFORMATION IS PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND,
	WHETHER EXPRESSED OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE IMPLIED
	WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A PARTICULAR PURPOSE.
	IF THIS CODE AND INFORMATION IS MODIFIED, THE ENTIRE RISK OF USE OR RESULTS IN
	CONNECTION WITH THE USE OF THIS CODE AND INFORMATION REMAINS WITH THE USER. 

	.DESCRIPTION
		Functions for inspecting SourceOne operations and getting health and status information
		Functions adapted from Mike Tramonts Health Check scripts

#>

#requires -Version 4

<#
.SYNOPSIS
	Gets Status and health information about all servers that make up the SourceOne implmentation
.DESCRIPTION
  Gets Status and health information about all servers that make up the SourceOne implmentation.
  This includes the results of a "ping" and whether all the SourceOne services installed on a machine are
  in the running state.

.OUTPUTS

.EXAMPLE

#>
Function Get-ES1ServersStatus
{
	[CmdletBinding()]
	PARAM ()
	BEGIN {}
	#
	# TODO - Add parameter to pass in additional servers that are not discoverable...
	#

PROCESS {
		$MachineProps=[ordered]@{'ComputerName'='';'Ping'='N/A';'AllServicesRunning'='N/A';'Uptime'='N/A';'Services'=@()}
		$MachineAccess =@()

		try {
        
        $servers=@()
	    # Get all es1 servers from DB, includes workers and archivers
		$servers=@(Get-ES1Servers)

		$dbServers=@()
		$dbServers = @(Get-ES1ArchiveDatabases | Select-Object DBServer -Unique )
		$activityDBInfo = Get-ES1ActivityDatabase | Select-Object DBServer
		$dbServers +=  $activityDBInfo

		$dbServers = $dbServers| Select-Object -unique
		
		# Add database servers to the list, parse the instance name if there is one
        foreach($DBServer in $dbservers)
        {
            if ($DBServer.DBServer.Contains('\'))
            {
                $names=$DBServer.DBServer.Split('\\')
                $svrName= $names[0]
            }
            else
            {
                $svrName = $DBServer.DBServer
            }
            $servers += $svrName
        }
		

	    $Available = Invoke-Ping -Computer $servers -Quiet

		# Build Unavailable/Unreachable
		if ($Available.Count -ne $servers.Count)
		{
			$unavailable = Compare-Object $servers $Available | where { $_.SideIndicator -eq '<=' }
			foreach ($noping in $unavailable)
			{
				$machineobject = New-Object -TypeName psobject -prop $MachineProps
				$machineobject.ComputerName = $noping.InputObject
				$machineobject.Ping = 'Fail'

				$MachineAccess += $machineobject
			}

  
		}
  
		$local = hostname

		foreach ($pingOK in $Available)
		{
			$machineobject = New-Object -TypeName psobject -prop $MachineProps
			$machineobject.ComputerName = $pingOK
            $machineobject.Ping="Pass"
        
			$uptime = Get-Uptime -ComputerName  $machineobject.ComputerName
			$machineobject.Uptime=$uptime.Uptime           # TODO - Drop the milliseconds 
			

			$services = Get-ES1Services -ComputerName $pingOK
            
            if ($services.Count -gt 0)
            {
               $machineobject.AllServicesRunning='Pass'
            }

			$installPath = S1Dir $pingOK

			# Append * so the -Include filter works...
			$installPath += '\*'

  			if ($pingOK -eq $local)
				{
					$exeFiles = Get-ChildItem -recurse -path $installpath -Include @("*.exe") | select-object -ExpandProperty VersionInfo 
					$AllBinaries = $exeFiles
				}
				else
				{

					if (Test-PsRemoting $pingOK)
					{

						$files = Invoke-Command -Cn $pingOK  -ScriptBlock{
							$exeFiles = Get-ChildItem -recurse -path $Args[0] -Include @("*.exe") | select-object -ExpandProperty VersionInfo 
							$exeFiles
						} -Args $installPath -ErrorVariable remoteErr -ErrorAction SilentlyContinue

						# $remoteErr contains any error message from the remote system
						if ($remoteErr)
						{
							write-warning $remoteErr
							$props = [ordered]@{'PSComputerName'=$pingOK ;'FileName'=$remoteErr ;'FileVersion'="ERROR"}
							$AllBinaries = New-object -TypeName PSObject -Prop $props
						}
						else
						{
							$AllBinaries = $files
						}
					}
					else
					{
						write-warning "**** Ps Remoting is not enabled on remote machine: $pingOK  ******"
						$props = [ordered]@{'PSComputerName'=$server;'FileName'='NA' ;'FileVersion'="Unreachable - Powershell remoting not enabled"}
						$AllBinaries += New-object -TypeName PSObject -Prop $props

					}
				}

                
                $services | Add-Member NoteProperty -Name "FileVersion" -Value ""
                foreach ($service in $services)
                {
                    #
                    #  Would be good to check the startType but it isn't exposed until .Net 4.6
                    if (($service.Status -eq 'Stopped') -or ($service.Status -eq 'Stop_Pending'))
                    {
                        $machineobject.AllServicesRunning='Fail'
                    }
                    $wmiService = get-wmiobject -ComputerName $pingOK -query "select * from win32_service where name='$($service.Name)'"
           
                    $exePath=$wmiService.PathName.Trim('"')

                    foreach ($binary in $AllBinaries)
                    {
                        if ($exePath -eq $binary.FileName)
                        {

                            $service.FileVersion = $binary.FileVersion
                        }
                    }

                }
                 $machineobject.Services = $services
  
                $MachineAccess += $machineobject
        
            }

	 }
	 catch
	 {
		throw $_
	 }

	 $MachineAccess

	}

	END{}
}


<#
.SYNOPSIS
  
.DESCRIPTION
  
.OUTPUTS

.EXAMPLE

#>
Function Get-ArchiveFolderStatus
{
	[CmdletBinding()]
	PARAM ()
	BEGIN {}

PROCESS {
	$folderStatus=@()

	$folderStatus = Get-ArchiveFolderSummary

	foreach($folder in $folderSummary)
	{
		$folder | Add-Member NoteProperty -Name "Status" -Value "Pass"

		if (($folder."Volume Items" -ne $folder."Index Items") -or ($folder.Errors -gt 0))
		{
			$folder.Status = "Fail"
		}
		
	}

	$folderStatus
}
END {}



}



## Temporary to help porting Mike T's stuff
function Add-Log
{
   Param
    (
        [Parameter(Position=0)]
        [string] $Msg = '',

        [Parameter(Position=1)]
        [string] $Level = 'Info'
    )

	Write-Host $($Msg)
}


<#
.SYNOPSIS

	Adapted from S1emServerStorageMon.ps1  
.DESCRIPTION
  
.OUTPUTS

.EXAMPLE

#>
Function Get-ES1ServerStorageStatus
{
	[CmdletBinding()]
	PARAM (
	[Parameter(Position=0,Mandatory=$false)]
	$threshold_perc = 10.0,
	[Parameter(Position=1,Mandatory=$false)]
	 $threshold_drive_free = 100.0
	)
BEGIN {}

PROCESS {

Try
{
    $returnCode = 0
    
    #
    # Get Storage Percent Free Threshold
    #
   
        
    if ($threshold_perc -gt 100)
    {
        $threshold_perc = 100.0
    }
    elseif ($threshold_perc -lt 0)
    {
        $threshold_perc = 0.0
    }
   
    #
    # Get Drive Free Threshold
    #
	# from commandline

    #
    # Initialize Server Collection
    #

	#  TODO - Load servers we might not be able to discover, like master, exchange, search , etc

    $cServers = @()
    
    $aServers = @()
	
	# Get all es1 servers from DB, includes workers and archivers
	$aServers=@(Get-ES1Servers)

	$dbServers=@()
	$dbServers = @(Get-ES1ArchiveDatabases | Select-Object DBServer -Unique )
	$activityDBInfo = Get-ES1ActivityDatabase | Select-Object DBServer
	$dbServers +=  $activityDBInfo

	$dbServers = $dbServers| Select-Object -unique
	# Add database servers to the list, parse the instance name if there is one
    foreach($DBServer in $dbServers)
    {
        if ($DBServer.DBServer.Contains('\'))
        {
            $names=$DBServer.DBServer.Split('\\')
            $svrName= $names[0]
        }
        else
        {
            $svrName = $DBServer.DBServer
        }
        $aSservers += $svrName
    }
	
	# Get SourceOne Master Server
    #if ($hConfig.ContainsKey('MASTER'))
    #{
    #    $aServers += $hConfig.MASTER
    #}
    #else
    #{
    #    $aServers += $scriptComputerName
    #}
    
    
    # Remove Duplicates from SourceOne Server List
    $aServers = @($aServers | Sort-Object | Select-Object -uniq)

    # Add SourceOne Servers
    if ($aServers)
    {
        $cServers += $aServers
    }

    #
    # Process Each Server
    #
    $warning = $false
    $cDrives = @()

    foreach ($server in $cServers)
    {
    
        Add-Log "Processing Server:  $server"
        $wmiDrives = Get-DriveInfo $server
        if (!($wmiDrives))
        {
            $warning = $true
			$status = 'Failed'
            Add-Log "Cannot access server:  $server" Warn
			$props = [ordered] @{'ComputerName'=$server;'Drive'='N/A'; `
						           'Volume_Name'='N/A'; 'Free'= 'N/A'; `
								   'Size_GB'= 'N/A'; 'Free_GB'='N/A';`
								   'Used_GB' = 'N/A';'Status'=$status}

			$oDrive = New-object -TypeName PSObject -Prop $props    
            $cDrives += $oDrive  


        }
        else
        {
           
            foreach ($drive in $wmiDrives)
            {        
                $size = [long]$drive.Size
                $free = [long]$drive.FreeSpace
                [long]$used = $size - $free
                [double]$free_percent = $free/$size
                
                [double]$size_gb = $size/(1024.0*1024.0*1024.0)
                [double]$free_gb = $free/(1024.0*1024.0*1024.0)
                [double]$used_gb = $used/(1024.0*1024.0*1024.0)
                
                if (($free_percent * 100 -le $threshold_perc) -and ($free_gb -lt $threshold_drive_free))
                {
                    $status = 'Warning'
                    $warning = $true
                }
                else
                {
                    $status = 'Pass'
                }            
            
				$props = [ordered] @{'ComputerName'=$server; 'Drive'=$drive.Name; `
						           'Volume_Name'=$drive.VolumeName; 'Free'= $("{0:P1}" -f $free_percent); `
								   'Size_GB'= $("{0:N1}" -f $size_gb); 'Free_GB'=$("{0:N1}" -f $free_gb);`
								   'Used_GB' = $("{0:N1}" -f $used_gb); 'Status'=$status}

				$oDrive = New-object -TypeName PSObject -Prop $props       
                $cDrives += $oDrive                              
            }
   
		   $cDrives

        }     
    }
	}
	Catch
	{
		throw $_
	}
}
END {}
}

<#
.SYNOPSIS
	Gets the disk space characteristics for the various CIFS shares used by an archive.

.DESCRIPTION
	Gets the disk space characteristics for the various CIFS shares used by an archive.
	
	The location type is returned in shorthand as follows:
	'MCL' = Message Center location
	'AFL' = Archive Container location
	'FTL' = Full Text Index location (for ISYS indexes)

  Adapted from Mike Tramont's S1emCIFSShareMon.ps1
    
.OUTPUTS

.PARAMETER threshold
	Percent Free Threshold to use for issuing a warning on the Message Center location. 

.EXAMPLE
Get-ES1CIFSShareStatus | ft -AutoSize

DATABASE ES1Archive on sql2008-j1:  Querying CIFS Shares
DATABASE IPMArchive on sql2008-j1:  Querying CIFS Shares
DATABASE SecondIPMArchive on sql2008-j1:  Querying CIFS Shares

DateTime            Share                                          Type Free   Size_GB Free_GB Used_GB Status
--------            -----                                          ---- ----   ------- ------- ------- ------
2018-05-15 13:36:43 \\S1MASTER64\PBA                               AFL  98.7 % 30.0    29.6    0.4     Ok
2018-05-15 13:36:43 \\S1MASTER64\MSGCENTER                         MCL  45.4 % 30.0    13.6    16.4    Ok
2018-05-15 13:36:43 \\S1MASTER64\INDEXSHARE                        FTL  45.4 % 30.0    13.6    16.4    Ok
2018-05-15 13:36:43 \\S1NASServer\ARCHIVES\ARCHIVE1                AFL  64.1 % 931.5   597.3   334.2   Ok

.EXAMPLE
Get-ES1CIFSShareStatus -threshold 50.0 | where {$_.Status -eq 'Failed' -or $_.Status -eq 'Warning'} | select Share, Type,Status | ft -AutoSize

DATABASE ES1Archive on sql2008-j1:  Querying CIFS Shares
DATABASE IPMArchive on sql2008-j1:  Querying CIFS Shares
DATABASE SecondIPMArchive on sql2008-j1:  Querying CIFS Shares
Cannot access CIFS Share:  \\ESQLEXT4-J\EX-INDEXES
Cannot access CIFS Share:  \\ESQLEX4-J\EX_INDEXES
Cannot access CIFS Share:  \\ESQLEXT4-J\EXINDEXMIRROR
Cannot access CIFS Share:  \\S1MASTER7-J1\MSGCENTER
Cannot access CIFS Share:  \\ESQLEXT4-J\ESQLEXT4-EMAILXTENDER
Cannot access CIFS Share:  \\ESQLEX4-J\EX_CONTAINERS
Cannot access CIFS Share:  \\ESQLEXT4-J\ESQLEXT4-CONTAINERS

Share                              Type Status
-----                              ---- ------
\\ESQLEXT4-J\EX-INDEXES            FTL  Failed
\\ESQLEX4-J\EX_INDEXES             FTL  Failed
\\ESQLEXT4-J\EXINDEXMIRROR         FTL  Failed
\\S1MASTER7-J1\MSGCENTER           MCL  Failed
\\S1MASTER64\MSGCENTER             MCL  Warning
\\ESQLEXT4-J\ESQLEXT4-EMAILXTENDER FTL  Failed
\\ESQLEX4-J\EX_CONTAINERS          AFL  Failed
\\ESQLEXT4-J\ESQLEXT4-CONTAINERS   AFL  Failed

#>
Function Get-ES1CIFSShareStatus
{
	[CmdletBinding()]
	PARAM (
		[Parameter(Position=0,Mandatory=$false)]
		[double] $threshold= 10.0
	)
BEGIN {
	$scriptStart = Get-Date
    
	# Change to script location
   	$scriptDirectory  = Split-Path -parent $PSCommandPath
    Set-Location $scriptDirectory

}

PROCESS {
Try
{
    $returnCode = 0
 
    #
    # Get Storage Percent Free Threshold
    #
        
    if ($threshold -gt 100)
    {
        $threshold = 100.0
    }
    elseif ($threshold -lt 0)
    {
        $threshold = 0.0
    }
    
    #
    # Get Cifs Shares from the Archive Databases
    #
    $hCifsShares = @{} 
	$Archives = Get-ES1ArchiveDatabases

    foreach ($archive in $Archives)
	{
       
            $dbName = $archive.DBName
            $dbServer = $archive.DBServer
     
            Add-Log "DATABASE $dbName on $dbServer`:  Querying CIFS Shares"

			# For expediancy I kept this as SQL queries, but the shares are accessible in the COM
			#   archive folder object... too
            $hTemp = Get-S1CifsShares -DBServer $dbServer -DBName $dbName
            foreach ($key in $hTemp.Keys)
            {
                if ($hCifsShares.ContainsKey($key) -eq $false)
                {
                    $hCifsShares[$key] = $hTemp[$key]
                } 
            }                    
	  }
    
    # TODO
    # Get Additional Cifs Shares from Input file
    #
  #  $infile = 'CIFSshares-SourceOne.txt'
  #  if (Test-Path $infile)
  #  {
  #      $aLines = @((Get-Content $infile) | ? {$_.trim() -ne "" } | Sort-Object)
        
  #      if ($aLines)
  #      {
  #  		foreach ($line in $aLines)
  #          {
  #              $lineupper = $line.Trim().ToUpper()
		#if ($lineupper.Contains('FTL'))
		#{
  #              	$hCifsShares[$lineupper] = 'FTL'
		#}
		#elseif ($lineupper.Contains('AFL'))
		#{
  #              	$hCifsShares[$lineupper] = 'AFL'
		#}
		#else
		#{
  #              	$hCifsShares[$lineupper] = 'OTHER'
		#}
  #          }        
  #      }
  #  }    

     
    #
    # Process each CIFS Share
    #
    $warning = $false
    $oFSO = New-Object -com  Scripting.FileSystemObject
    $cShares = @()
  
    foreach ($share in $hCifsShares.Keys)
    {   
        $shareType = $hCifsShares[$share].ToString()
        $shareprops = [ordered] @{'DateTime'=$(Get-Date -Date $scriptStart -Format “yyyy-MM-dd HH:mm:ss”); `
						'Share'=$share; 'Type'=$shareType; 'Free'=''; 'Size_GB'=''; 'Free_GB'=''; `
						'Used_GB'=''; 'Status'=''}

        $oShare = New-Object -TypeName PSObject -Property $shareprops

        
       try
       {
            #
            # Size of Folder in MB:
            #
            # "{0:N2}" -f (($oFSO.GetFolder("\\SOURCEONE1B\C$\S1CIFS\S1FTL001").Size) / 1MB) + " MB"

            #
            # Count of Files in Folder:
            #
            # (Get-ChildItem "\\SOURCEONE1B\C$\S1CIFS\S1FTL001" -Recurse).Count
            
            #$oDrive = $oFSO.GetDrive($share)
            $oDrive = $oFSO.GetFolder($share).Drive
            $size = [long]$oDrive.TotalSize
            $free = [long]$oDrive.FreeSpace
            [long]$used = $size - $free
            [double]$free_percent = $free/$size
            
            [double]$size_gb = $size/(1024.0*1024.0*1024.0)
            [double]$free_gb = $free/(1024.0*1024.0*1024.0)
            [double]$used_gb = $used/(1024.0*1024.0*1024.0)
            
            $status = 'Ok'
            if ($shareType -eq 'FTL')
            {
                if ($free_percent * 100 -lt 4)
                {
                    $status = 'Warning'
                    $warning = $true
                }
            }
            elseif ($shareType -eq 'AFL')
            {
                if ($free_percent * 100 -lt 4)
                {
                    $status = 'Warning'
                    $warning = $true
                }
            }            
            else
            {
                if ($free_percent * 100 -le $threshold)
                {
                    $status = 'Warning'
                    $warning = $true
                }            
            }
            
            $oShare.Status = $status
            $oShare.Free = $("{0:P1}" -f $free_percent)
            $oShare.Size_GB = $("{0:N1}" -f $size_gb)
            $oShare.Free_GB = $("{0:N1}" -f $free_gb)
            $oShare.Used_GB = $("{0:N1}" -f $used_gb)
            
            $cShares += $oShare  
     
		}
        catch
        {
            $warning = $true        
        
            Add-Log "Cannot access CIFS Share:  $share" Info
            
            $oShare.Status = 'Failed'

            $cShares += $oShare        
        
        }
      }

	}        
  
	Catch
	{
		throw $_
 
	}

	$cShares 

}
END {}
}


<#
.SYNOPSIS
	Gets the ContainerLocations,IndexLocations, and MsgCenterPaths for archive folders defined in the given archive database.  
	NOTE: uses direct SQL queries for legacy reasons.
	Returns a hashmap of the UNC path and short name for the location type.

.DESCRIPTION
	Gets the ContainerLocations,IndexLocations, and MsgCenterPaths for archive folders defined in the given archive database.
	NOTE: uses direct SQL queries for legacy reasons.
	Returns a HashMap of the UNC path and short name for the location type.

	'MCL' = Message Center location
	'AFL' = Archive Container location
	'FTL' = Full Text Index location (for ISYS indexes)

.OUTPUTS

.EXAMPLE

#>
Function Get-S1CifsShares
{
[CmdletBinding()]
Param
    (
        [Parameter(Position=0,Mandatory=$true,
					ValueFromPipeLine=$true, 
					ValueFromPipeLineByPropertyName=$true)]
        [string] $dbServer,
        [Parameter(Position=1,Mandatory=$true,
				ValueFromPipeLine=$true, 
		ValueFromPipeLineByPropertyName=$true)]
        [string] $dbName
    )

BEGIN {}

PROCESS {

    #
    # Define SQL Queries
    #
    $sqlQueryContainer = @'
SELECT DISTINCT NodeProps.value('(/fpprops/ContainerLocation)[1]','nvarchar(max)') AS ContainerLocation
FROM FolderPlan (NOLOCK)
WHERE Type = 1      
'@
    $sqlQueryIndex = @'
SELECT DISTINCT NodeProps.value('(/fpprops/IndexLocation)[1]','nvarchar(max)') AS IndexLocation
FROM FolderPlan (NOLOCK)
WHERE Type = 1     
'@
    $sqlQueryMsgCenter = @'
SELECT DISTINCT REPLACE(ConfigXML.value('(/ExAsSrvCfg/ArchiveService/MsgCenterPath)[1]','nvarchar(max)'), '\Message_Center', '') AS MsgCenter
FROM ServerInfo (NOLOCK)
WHERE LEN(MacAddress) > 0     
'@

    #
    # Hashtable to collect and dedup the Cifs Shares
    #
    $hShares = @{}

    #
    # Process Message Center Shares
    #
    $dtResults = Invoke-ES1SQLQuery $dbServer $dbName $sqlQueryMsgCenter
    foreach ($row in $dtResults)
    {
        if ($row.MsgCenter.StartsWith('\\'))
        {
            $hShares[$row.MsgCenter.ToUpper()] = 'MCL'
        }
    }

    #
    # Process Container Shares
    #
    $dtResults = Invoke-ES1SQLQuery $dbServer $dbName $sqlQueryContainer
    foreach ($row in $dtResults)
    {
        if ($row.ContainerLocation.StartsWith('\\'))
        {
            $hShares[$row.ContainerLocation.ToUpper()] = 'AFL'
        }
    }

    #
    # Process Index Shares
    #
    $dtResults = Invoke-ES1SQLQuery $dbServer $dbName $sqlQueryIndex
    foreach ($row in $dtResults)
    {      
        if ($row.IndexLocation.Contains(';'))
        {
            $aValues = $row.IndexLocation.Split(';')
            foreach ($val in $aValues)
            {
                if ($val -match '\\\\.+\\.+')
                {
                    $hShares[$matches[0].ToUpper()] = 'FTL'
                }
            }
        }
        elseif ($row.IndexLocation -match '\\\\.+\\.+')
        {
            $hShares[$matches[0].ToUpper()] = 'FTL'
        }
    }

    #
    # Return Hash Table
    #
    , $hShares
 }
 
 END{}
    
}




#-------------------------------------------------------------------------------
# Function:  Get-DriveInfo
#-------------------------------------------------------------------------------
function Get-DriveInfo {

    Param
    (
        [Parameter(Position=0)]
        [string] $Server
    )

    $connect = $false
    
    if (test-connection -computername $server -quiet  -count 1)
    { 
        try
        {
            $wmiDrives = Get-WmiObject -ComputerName $Server -Class Win32_LogicalDisk -Filter "DriveType = 3" -ErrorAction SilentlyContinue
            $connect = $true
        }
        catch
        {
			Write-Error $_
        }
    }
    
    if ($connect)
    {
        $wmiDrives
    }
    else
    {
        , @()  # Comma Operator forces the return of an empty array -- otherwise only $null is returned    
    }
}


#-------------------------------------------------------------------------------
# Function:  Get-SpaceMB
#-------------------------------------------------------------------------------
function Get-SpaceMB {

    Param
    (
        [Parameter(Position=0)]
        [string] $InputPath
    )

    $results = @()

    if (Test-Path $InputPath)
    {
        try
        {
            if ($InputPath.StartsWith('\\'))
            {
                $InputPath = $InputPath.TrimEnd('\')           
                $aValues = $InputPath.Split('\')
                if ($aValues.Length -ge 4)
                {
                    $drive = '\\' + $aValues[2] + '\' + $aValues[3]
                }
                
                $oFSO = New-Object -com  Scripting.FileSystemObject
                $oDrive = $oFSO.GetDrive($drive)

                $size = [long]$oDrive.TotalSize
                $free = [long]$oDrive.FreeSpace
            
                $size_mb = $size/(1024.0*1024.0)
                $free_mb = $free/(1024.0*1024.0)
                $used_mb = $size_mb - $free_mb               
                  
            }
            else
            {
                $drive = (Split-Path $InputPath -qualifier).TrimEnd(':')
                $free = (Get-PSDrive $drive).Free
                $used = (Get-PSDrive $drive).Used
                $size = $free + $used
                
                $size_mb = $size/(1024.0*1024.0)
                $free_mb = $free/(1024.0*1024.0)
                $used_mb = $used/(1024.0*1024.0)
            }
           
            $size_mb_formatted = $("{0:N1}" -f $size_mb)
            $free_mb_formatted = $("{0:N1}" -f $free_mb)
            $used_mb_formatted = $("{0:N1}" -f $used_mb)
            
            $results = ($size_mb, $free_mb, $used_mb, [double]$size_mb_formatted, [double]$free_mb_formatted, [double]$used_mb_formatted)
        
        }
        catch
        {    
			Write-Error $_
        }
    }

    if ($results.Count -gt 0)
    {
        $results
    }
    else
    {
        , @()  # Comma Operator forces the return of an empty array -- otherwise only $null is returned    
    }
}







<#
.SYNOPSIS
  
.DESCRIPTION
  
.OUTPUTS

.EXAMPLE

#>
Function FunctionTemplate
{
	[CmdletBinding()]
	PARAM ()
	BEGIN {}
	#
	# TODO - Add parameter to pass in additional servers that are not discoverable...
	#

PROCESS {
}
END {}
}

Export-ModuleMember -Function * -Alias *

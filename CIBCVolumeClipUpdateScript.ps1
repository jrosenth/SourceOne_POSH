<#	
	.NOTES
	===========================================================================
	 Created on:   	10/19/2015
	 Created by:   	Jay Rosenthal
	 Organization: 	EMC Corp. PS Americas
	 Filename:     	CIBCVolumeClipUpdateSrcipt.ps1

     Copyright © 2015 EMC Corporation, All rights reserved.
	===========================================================================

.SYNOPSIS
	Create a file of SQL commands to Update the clipID for a volume

	This script must be run on a SourceOne worker machine.

.DESCRIPTION
	Create a file of SQL commands to Update the clipID for a volume

.OUTPUTS

.LINK
	SR  
	

.EXAMPLE


#>

 [CmdletBinding()]
 Param([Parameter(Position=0,Mandatory=$True)]
        [Alias('f')]
        [string]$csvfile="" )     

 begin
	{


	}
process
	{
    $MyDebug=$false
    # Do both these check to take advantage of internal parsing of syntaxes like -Debug:$false
    If ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey("Debug") -and $PSCmdlet.MyInvocation.BoundParameters["Debug"].IsPresent)
    {
	    $DebugPreference = "Continue"
	    Write-Debug "Debug Output activated"
	    # for convenience
	    $MyDebug = $true
    }

    # Change to script location
    $scriptDirectory = Split-Path $myinvocation.mycommand.path
    Set-Location $scriptDirectory


    $scriptVersion = '2015.10.19'

  

    try {

        #-------------------------------------------------------------------------------
        # Start
        #-------------------------------------------------------------------------------

        import-module ".\ES1_IPM_Utils\ES1_IPM_Utils.psd1"
          . .\EMCPS_S1VolumeUtils.ps1
     
        $ComputerName =[System.Net.DNS]::GetHostByName('').HostName

        $scriptUserDomain = [Environment]::UserDomainName
        $scriptUserName = [Environment]::UserName
        $scriptComputerName = [Environment]::MachineName
        $scriptComputerOS = (Get-WmiObject Win32_OperatingSystem).Caption.ToString()
        $scriptName = $MyInvocation.MyCommand.Name
        $scriptNameBase = [System.IO.Path]::GetFileNameWithoutExtension($scriptName)

        $registeredOrganization = (Get-ItemProperty -Path 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion').RegisteredOrganization
        $POSHVersion = Get-POSHVersionAndArchitecture
        $IPMModuleVersion= (Get-Module ES1_IPM_Utils).Version

        $outTimeStamp = (Get-Date).ToString("MMMddhhmm")
        

        Write-Host
        Write-Host '===================================================='
        Write-Host "$(Date), SCRIPT VERSION:  $scriptversion"
        Write-Host '===================================================='
        Write-Host
        Write-Host "Organization           :  $registeredOrganization"
        Write-Host "Server                 :  $scriptComputerName"
        Write-Host "Script User            :  $scriptUserDomain\$scriptUserName"
        Write-Host "Current Directory      :  $scriptDirectory"
        Write-Host "PowerShell Version     :  $POSHVersion"
        Write-Host "IPM POSH Module Version:  $IPMModuleVersion"

        $dtIPMDatabases = @()
	
        Write-Progress -Activity " Getting IPM Archive Databases" -Status "Please wait..."

	    try
	    {
		    #-------------------------------------------------------------------------------
		    # Get IPM Archive Databases
		    #-------------------------------------------------------------------------------
		    $dtIPMDatabases = @(Get-S1IPMArchiveDatabases $actDbServer $actDb)
		
	    }
	    catch
	    {
		    Write-Error "Error finding IPM Archive databases, Check your configuration or SQL connections"
		    throw $_
	    }
	

	    if ($dtIPMDatabases.Length -eq 0)
	    {
		    throw 'No IPM Archive databases could be found'
	    }
	
	    Write-Host '----------------------------------------------------'
	    Write-Host "IPM Database Settings:"
	    Write-Host '----------------------------------------------------'
	    Format-Table -InputObject $dtIPMDatabases -AutoSize | Out-String -Width 10000 
	
        Write-Progress -Activity " Getting IPM Archive Databases" -Completed -Status "Loading file with new clip IDs..."


        $seconds = (Measure-Command { $newClipFile = Import-Csv $csvfile}).TotalSeconds
        Write-host Seconds to load CSV file : $seconds

        $count=$newClipFile.length
        Write-Host Loaded : ($count-1) volume names from file
    
        Write-Progress -Activity " Getting IPM Archive Databases" -Completed -Status "Done"

        $VolumeNewClipInfo = @()

        #Format-Table -InputObject $newClipFile -AutoSize | Out-String -Width 10000 
        $SQLFindVolumeByName=@'
        select * from [Volume] where VolumeName like @VOLNAME
'@

   
	[int]$i = 0
    $cntVols = $newClipFile.Length

    foreach ($newVol in $newClipFile )
    {

        $volumeName=$newVol.VolumeName
        $volumeName=[io.path]::GetFileNameWithoutExtension($volumeName)

        [int]$dispCnt = ($i + 1)
         Write-Progress -Activity "Processing Volumes in file" -Status "Progress - $cntVols total volumes " -percentcomplete (($i/$cntVols) * 100) `
					   -Currentoperation "($dispCnt) Current Volume: $volumeName" -Id 1
		$i++

        
        $volumeName="%"+$volumeName+"%"
       
        #$volumeName
   
        foreach ($archiveDB in $dtIPMDatabases)
        {
            $sqlserver=$archiveDB.DBServer
            $sqlDB = $archiveDB.DBName
        
            #Write-host $sqlserver $sqlDB $volumeName
            $volume=@()
            $volumes = @(ES1_ExecuteSQLParams $sqlserver $sqlDB $SQLFindVolumeByName `
                        -parameters @{VOLNAME= $volumeName})

            if ($volumes.Length -eq 1)
            {
                # Get the Current clip ID from the VolStubXML that was returned
                #
                $OldClipID='NA'
                if ($volumes[0].VolStubXml.Length -gt 0)
                {
                    $volstubxml=[xml]$volumes[0].VolStubXml
                    $OldClipID=$volstubxml.Cf.Gp.CCLIPID
                }
                

		        # Create the summary info
		        $props = @{'SQLServer' = $sqlserver; `
			    'ArchiveDB' = $sqlDB; 'VolumeName'=$volumes[0].VolumeName; 'OldClipID'=$OldClipID;  'NewClipID'=$newVol.NewClipID			
		         }
		
		        $VolumeNewClipInfo += New-Object -TypeName PSObject -Property $props
            }

            if ($volumes.Length -gt 1)
            {
            #
            #  Really only ever expect 1, but depending on how IPM was done there could be 
            #    more than one with different server names
                foreach($dbVol in $volumes)
                {
                    $dbVolName = $dbVol.VolumeName
                    Write-host Found multiple matching volumes: $dbVolName  on $sqlserver in $sqlDB
                }
            }
            else{
                # not found in the current db...

            }
        }
       
    }

    if ($MyDebug)
    {
        Write-Debug 'Dumping New ClipInfo table'
        $VolumeNewClipInfo | format-table -AutoSize | Out-String -Width 10000 
    
    }
    
     foreach ($archiveDB in $dtIPMDatabases)
     {
            $sqlserver=$archiveDB.DBServer
            $sqlDB = $archiveDB.DBName

            # Creat the SQL commands file
            $outfile = $sqlDB + "_UpdateVolumesClipID_"+ $outTimeStamp +".SQL"
            Create-VolumeUpdateVolStubXMLSQL $sqlserver $sqlDB $VolumeNewClipInfo $outfile "  SQL command to update volumes with new clipIDs"
    
            # Create a csv file too
            $outfile = $sqlDB + "_UpdateVolumesClipID_" + $outTimeStamp + ".csv"
			$VolumeNewClipInfo | select-object SQLServer,ArchiveDB,VolumeName,OldClipID,NewClipID |sort VolumeName | export-csv -notype $outfile

     }
    
    }
    catch
    {
        Write-Error $_
    
    }

    }  #end Process
    end
    {

    }







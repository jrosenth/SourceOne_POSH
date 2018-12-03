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
		Functions for managing and configuring Archive Connections and servers

#>


Add-Type -TypeDefinition @"
public enum ArchiveType{
	IPM,
	NATIVE
}
"@


function New-ES1ArchiveConnection {
<#
.SYNOPSIS
	Create a new "Native" or "IPM" archive connection.
.DESCRIPTION
	Create a new "Native" or "IPM" archive connection.  
	The SQL database should be created using the documented process.  At least one archive server must be installed and setup to use
	the same SQL database specified.

.PARAMETER ArchiveName
	The name to be used for the new archive connection
.PARAMETER ArchiveType
	The type (NATIVE or IPM) of archive to be created.
.PARAMETER ArchiveDbServer
	Name of SQL server (and instance if applicable) hosting the new archive database
.PARAMETER ArchiveDbName
	Name of the database on the SQL server 
.PARAMETER Description
	Text description of the new archive connection.

.EXAMPLE
	New-ES1ArchiveConnection -ArchiveName Archive2 -ArchiveDbServer sql2008 -ArchiveDbName ES1Archive2 -Description "Second Native Archive" -ArchiveType NATIVE 


#>
[CmdletBinding()]
PARAM( [Parameter(Mandatory=$true)]
		[Alias('archive')]
		[string] $ArchiveName,
		[Parameter(Mandatory=$true)]
		[ArchiveType] $ArchiveType,
		[Parameter(Mandatory=$true)]
		[string] $ArchiveDbServer,
		[Parameter(Mandatory=$true)]
		[string] $ArchiveDbName,
		[Parameter(Mandatory=$false)]
		[string] $Description
		)

BEGIN{
		$MyDebug = $false
		# Do both these checks to take advantage of internal parsing of syntaxes like -Debug:$false
		if ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey("Debug") -and $PSCmdlet.MyInvocation.BoundParameters["Debug"].IsPresent)
		{
			$DebugPreference = "Continue"
			Write-Debug "Debug Output activated"
			# for convenience
			$MyDebug = $true
		}

	try {
		 [bool] $loaded = Add-ES1Types 

        if (-not $loaded )
        {
            Write-Error 'Error loading SourceOne Objects and Types'
            break
        }
	}
	catch
	{
		Write-Error $_ 
		break
	}
}

PROCESS {
 
    [EMC.Interop.ExBase.exDataProviderType] $S1ArchiveType= [EMC.Interop.ExBase.exDataProviderType]::exDataProviderType_Unknown

	try {

		$JDFAPIMgrClass = new-object -TypeName EMC.Interop.ExJDFAPI.CoExJDFAPIMgrClass
		$JDFAPIMgrClass.SetTraceInfo($Global:S1LogFile)

        $SQLServer = $ArchiveDbServer
        # Get only the server name, there might be a SQL instance specified
        if ($ArchiveDbServer.Contains('\'))
        {
            $names=$ArchiveDbServer.Split('\\')
            $SQLServer= $names[0]
        }
      
		
		# Make sure the DB server is reachable, archive database exists and some servers are configured
        $Available = Invoke-Ping -Computer $SQLServer 
        if ($Available.STATUS -eq 'Responding')
        {
            try {
                
                $PBAServers = @(Get-ES1NAServers -dbServer $ArchiveDbServer -dbName $ArchiveDbName)

             #  $PBAServers = @(Invoke-ES1SQLQuery -SqlServer $ArchiveDbServer -DbName $ArchiveDbName -SqlQuery $SQLPBAServers)
              
               Write-Verbose "Found PBAServers : $($PBAServers)"

               if ($PBAServers.Length -le 0)
               {
                    throw "No Archive servers are installed for this connection.  At least one archive server must be configured for $($ArchiveDbName)"
               }

            }
            catch [System.Management.Automation.MethodException]
            {
                throw "Cannot open connection to SQL Server $($ArchiveDbServer) and/or database $($ArchiveDbName) "
            }
            catch
            {
                # Re-throw other exceptions
                throw $_
            }
        }
        else
        {
            throw "SQL server $($SQLServer) is unreachable"
        }

        # Map type argument to ENUM value
        switch($ArchiveType)
        {
             IPM
             {
                $S1ArchiveType = [EMC.Interop.ExBase.exDataProviderType]::exDataProviderType_ExAsIPM
             }

             NATIVE
             {
                $S1ArchiveType = [EMC.Interop.ExBase.exDataProviderType]::exDataProviderType_ExAS
             }

        }

        if ($S1ArchiveType -eq [EMC.Interop.ExBase.exDataProviderType]::exDataProviderType_Unknown)
        {
            throw "Unsupported or Uknknown archive type specified"
        }

        
		# Create an Archive Provider Config object and put in the properties
		$providerCfg= new-object -ComObject ExAsProviderCfg.CoExAsProviderCfg
		$providerCfg.SetTraceInfo($Global:S1LogFile)
		$providerCfg.dbName =$ArchiveDbName
		$providerCfg.dbServer=$ArchiveDbServer
		$providerCfg.SetProperty('ProviderTypeID', $S1ArchiveType)

		# This does not validate access to the SQL server and DB.  We did that above 
		# TODO - Does this throw ??
		$cfgResults = $providerCfg.Validate()

		# Get properly formatted XML to pass into the Initialize for the ProviderTypeConfig
		$providerCfgXML = $providerCfg.GetXML()

		$newProvider = $JDFAPIMgrClass.CreateNewObject([EMC.Interop.ExJDFAPI.exJDFObjectType]::exJDFObjectType_ProviderTypeConfig)
		$newProvider.SetTraceInfo($Global:S1LogFile)
 
		$newProvider.name=$ArchiveName
		$newProvider.providerTypeID =  $S1ArchiveType   
		$newProvider.xConfig = $providerCfgXML
        $newProvider.description = $Description
  

		#  This may throw for problems connecting to the activity DB
		$results = $newProvider.Validate()      
		
		# Validation errors are in the results
		foreach ($valResult in $results)
		{
			# Check the "IsWarning" attibute, false means fatal error
			if ($valResult.IsWarning -eq $false)
            {
                throw $valResult.errorDescription
            }
    
		}


        # Create a new archive repository object
        $newRepoClass = new-object -TypeName EMC.Interop.ExAsAdminAPI.CoExASRepositoryClass       
        $newRepoClass.SetTraceInfo($Global:S1LogFile)

		$propset = new-object -comobject ExDataSet.CoExPropertySet.1
        $propset.Item.InvokeSet($newProvider.xConfig,0)
        [string]$pName = $newProvider.name
     
        # Initialize the repository
        # this should work but doesn't.  Which is why reflection and Invoke is used
        #$newRepoClass.Initialize($pName, $propset)

        $initMethod = $newRepoClass.GetType().GetMethod('Initialize')
        $initMethod.Invoke($newRepoClass, @($pName;$propset))
        
     	#
		# 7.2+ Has Index validation setting which should be put into the new provider
		#
        $funcExists = $JDFAPIMgrClass | Get-Member -MemberType Method | where {$_.Name -eq 'GetSystemIndexValSettings'} 
        if ($funcExists)
        {
            $common = $newRepoClass.GetCommonConfig()
		    $indexsettings = $JDFAPIMgrClass.GetSystemIndexValSettings()

            $common.EnableIndexVal  = $indexsettings.enableIndexVal;
            $common.EnableSchedule  = $indexsettings.enableSchedule;
            $common.EnableFixMode   = $indexsettings.enableFixMode;
            $common.ScheduleDay     = $indexsettings.scheduleDay;
            $common.StartTimeHour   = $indexsettings.startTimeHour;
            $common.StartTimeMin    = $indexsettings.startTimeMin;
            $common.NumbersToRepair = $indexsettings.numbersToRepair;
            $common.ScanMode        = $indexsettings.scanMode;
            
            $common.Save()
        }
  

        #
        # Since this is a new archive there are not too many shares to validate, if any
        #   (I think the GUI does this for Edit use case not necessarily create)
        #   Haven't been able to test this error path...
        $NetworkResults = @($newRepoClass.ValidateNetworkShare())
        
        if ($NetworkResults -and ($NetworkResults.Length -gt 0))
        {
            Write-Verbose "Error Validating network shares : $($NetworkResults)"
            throw "Error Validating network shares"
        }

        # Now Save it to create Archive Connection
		try
		{
                $claims = $newRepoClass.ClaimNetworkShare();

				$newProvider.Save()
                Write-Host "If the SourceOne Console is running you must restart it to refresh the Archive list" -BackgroundColor DarkYellow

		}
		catch
		{
			Write-Error $_

		}
        

	}
	catch {
        Write-Error $_

	}
    finally
    {
         if ($JDFAPIMgrClass)
         {
            [System.Runtime.Interopservices.Marshal]::ReleaseComObject($JDFAPIMgrClass) > $null
         }
         if ($providerCfg)    
         {
            [System.Runtime.Interopservices.Marshal]::ReleaseComObject($providerCfg) > $null
         }
         if( $newRepoClass)
         {
            [System.Runtime.Interopservices.Marshal]::ReleaseComObject($newRepoClass) > $null
            [System.Runtime.Interopservices.Marshal]::ReleaseComObject($propset) > $null
         }


    }


}

END{}

}




function Show-ArchiverRoles {
<#
.SYNOPSIS
	Display a list of SourceOne Archive machines and their enabled roles
	
.DESCRIPTION
	Display a list of SourceOne Archive machines and their enabled roles
.PARAMATER 	ArchiveName
	If specified get only the archive server roles for the archive connection specified.  Otherwise servers for
	all archives are returned.
.EXAMPLE
	Show-ArchiverRoles

Number of Archives: 3

ArchiveName ServerName                RolesValue Enabled Roles
----------- ----------                ---------- -------------
Archive1    s1Master7-J1.qagsxpdc.com         15 {Archive, Index, Query, Retrieval}
IPMArchive  IPMWorker02.qagsxpdc.com          14 {Index, Query, Retrieval}
SecondIPM   IPMArchive2.qagsxpdc.com          14 {Index, Query, Retrieval}

#>
	[CmdletBinding()]
	param( 
	[Parameter(Mandatory=$false)]
	[Alias('archive')]
	[string] $ArchiveName)

	begin {
		try {
			[bool] $loaded = Add-ES1Types #-ErrorAction SilentlyContinue

			if (-not $loaded )
			{
				Write-Error 'Error loading SourceOne Objects and Types'
				break
			}
		}
		catch
		{
			Write-Error $_ 
			break
		}


	}

	process {
		$asmgr = new-object -ComObject ExAsAdminAPI.CoExASAdminAPI

		$asmgr.Initialize()

		$ASRoles = [enum]::GetNames([EMC.Interop.ExASBaseAPI.exASServerPersonalities])
		Write-Debug "$($ASRoles)"

		if ($ArchiveName)
		{
			 try {
			    $ASRepos = @($asmgr.GetRepository($ArchiveName))
            }
            catch {
                throw "Error getting repository for connection $($ArchiveName).  Check the name "
            }
		}
		else
		{
			$ASRepos = $asmgr.EnumerateRepositories()
		}

		Write-host Number of Archives: $ASRepos.Count
		$AllArchives = @()

		foreach ($repo in $ASRepos)
		{
			$Servers = @($repo.EnumerateServers())
			Write-Debug "Archive:  $($repo.Name) has $($Servers.Count) servers"

			#
			# Add some new columns
			$Servers | Add-Member NoteProperty -Name "ArchiveName" -Value $repo.Name
			$Servers | Add-Member NoteProperty -Name "ArchiveRoles" -Value ""

			foreach ($server in $Servers)
			{
				$roles = @()
				$personality = $server.ServerPersonality

				for ($i = 0 ; $i -lt ($ASRoles.Length-1); $i++)
				{

					[int] $bits = [EMC.Interop.ExASBaseAPI.exASServerPersonalities]$ASRoles[$i]

					if ($personality -band $bits)
					{
						$roles += ([EMC.Interop.ExASBaseAPI.exASServerPersonalities]$ASRoles[$i]).ToString().Substring(10)
					}

				}

				$server.ArchiveRoles=$roles

			}
			$AllArchives += $Servers

		} 

		$fmt = @{ Expression = { $_.ArchiveName }; label = "ArchiveName" },
		@{ Expression = { $_.FullName }; label = "ServerName" },
		@{ Expression = { $_.ServerPersonality }; label = "RolesValue" },
		@{ Expression = { $_.ArchiveRoles }; label = "Enabled Roles" }

		$AllArchives | Format-Table -AutoSize $fmt | Out-String -Width 10000

	}

	end {}
}

<#
.SYNOPSIS
	Get a list of SourceOne Archive server objects and their properties
	
.DESCRIPTION
	Get a list of SourceOne Archive server objects and their properties.  The list of objects returned contains
	IExASServer objects with two additional properties added (ArchiveName and ArchiveRoles) for convenience.
.PARAMETER ArchiveName
	Optional, The archive connection name to get the server configruation for.  If not provided the server configurations for all
	archives is returned.
	
.EXAMPLE
	$arServers=Get-ES1ArchiveServerConfig	
	$arServers | Select ArchiveName,ArchiveRoles,MessageCenterDir,VersionInfo | ft -AutoSize

	ArchiveName ArchiveRoles                       MessageCenterDir                        VersionInfo
    ----------- ------------                       ----------------                        -----------
    Archive1    {Archive, Index, Query, Retrieval} \\S1MASTER64\MsgCenter\Message_Center   7.1.3.3054
    IPMArchive  {Index, Query, Retrieval}                                                  7.1.3.3054
    SecondIPM   {Index, Query, Retrieval}                                                  7.1.3.3054

#>
function Get-ES1ArchiveServerConfig
{
	[CmdletBinding()]
	param( 
	[Parameter(Mandatory=$false)]
	[Alias('archive')]
	[string] $ArchiveName)

	BEGIN {
		try {
			[bool] $loaded = Add-ES1Types #-ErrorAction SilentlyContinue

			if (-not $loaded )
			{
				Write-Error 'Error loading SourceOne Objects and Types'
				break
			}
		}
		catch
		{
			Write-Error $_ 
			break
		}


	}

  PROCESS {
		$asmgr = new-object -ComObject ExAsAdminAPI.CoExASAdminAPI

		$asmgr.Initialize()

		$ASRoles = [enum]::GetNames([EMC.Interop.ExASBaseAPI.exASServerPersonalities])
		Write-Debug "$($ASRoles)"

		if ($ArchiveName)
		{
			 try {
			    $ASRepos = @($asmgr.GetRepository($ArchiveName))
            }
            catch {
                throw "Error getting repository for connection $($ArchiveName).  Check the name "
            }
		}
		else
		{
			$ASRepos = $asmgr.EnumerateRepositories()
		}
		
		$AllArchives = @()

		foreach ($repo in $ASRepos)
		{
			$Servers = @($repo.EnumerateServers())
			Write-Debug "Archive:  $($repo.Name) has $($Servers.Count) servers"

			#
			# Add some new columns
			$Servers | Add-Member NoteProperty -Name "ArchiveName" -Value $repo.Name
			$Servers | Add-Member NoteProperty -Name "ArchiveRoles" -Value ""

			foreach ($server in $Servers)
			{
				$roles = @()

				# Decode the personality bits to something human readable
				$personality = $server.ServerPersonality

				for ($i = 0 ; $i -lt ($ASRoles.Length-1); $i++)
				{
					[int] $bits = [EMC.Interop.ExASBaseAPI.exASServerPersonalities]$ASRoles[$i]

					if ($personality -band $bits)
					{
						$roles += ([EMC.Interop.ExASBaseAPI.exASServerPersonalities]$ASRoles[$i]).ToString().Substring(10)
					}

				}

				$server.ArchiveRoles=$roles

			}
			$AllArchives += $Servers

		} 

		$AllArchives

	}
	END {}

}

function Set-ArchiveServerRoles {
<#
.SYNOPSIS
	Set or change the Roles for an archive server
.DESCRIPTION
	Set or change the Roles for archive server(s) specified

	DYNAMIC PARAMETERS
	-MessageCenterLoc [string]
	If the "Archive" role is selected, the MessageCenter location for the server must be specified.

.PARAMETER ArchiveName
	Archive Connection name of the archive whose servers' roles will be modified
.PARAMETER ArchiveServerName
	Specific server name (fully qualified) which will be modified
	
.PARAMETER ServerRoles
	The roles (Archive,Index,Search,Retrieval) to be enabled.  This will overwrite existing roles with only the roles specified here.

.PARAMETER ServersToIndex
	If the "Index" role is selected, a list of archive servers to index must be provided.  This list of servers will overwrite any existing ones.

.EXAMPLE
	

#>
[CmdletBinding()]
PARAM( [Parameter(Mandatory=$true)]
		[Alias('archive')]
		[string] $ArchiveName,
		[Parameter(Mandatory=$true,
		ValueFromPipeLine=$true, 
		ValueFromPipeLineByPropertyName=$true)]
		[Alias("FullName")]
		[string[]] $ArchiveServerName,               # 
		[Parameter(Mandatory=$true)]
        [ValidateSet ("ALL","ARCHIVE","INDEX", "SEARCH", "RETRIEVAL")]
		[string[]] $ServerRoles,             # handle a list of Roles...
		[Parameter(Mandatory=$false)]
		[string[]]$ServersToIndex            # handle a list of servers
		)

 DynamicParam {
        # Set up parameter attribute
        $MessageCenterLoc = New-Object System.Management.Automation.ParameterAttribute
        $MessageCenterLoc.Mandatory = $false
        $MessageCenterLoc.HelpMessage ="UNC to message center location "

        # Set up ValidateScript param with actual file name values
        $fileValidateParam = New-Object System.Management.Automation.ValidateScriptAttribute { 
            if (($ServerRoles -contains "ARCHIVE") -or ($ServerRoles -contains "All"))
            {
                if( -not (Test-Path $_) )
                {
                     throw "Message Center location does not exist or is not accessible"
                } 
                else 
                {
                    $true
                }
            }
            else 
            {
                $true
            }
        }

        # Add the parameter attributes to an attribute collection
        $attributeCollection = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
        $attributeCollection.Add($MessageCenterLoc)
        $attributeCollection.Add($fileValidateParam)

        # Create the actual $MessageCenterLoc', parameter
        $fileParam = New-Object System.Management.Automation.RuntimeDefinedParameter('MessageCenterLoc', [string], $attributeCollection)

        # Push the parameter(s) into a parameter dictionary
        $paramDictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary
        $paramDictionary.Add('MessageCenterLoc', $fileParam)

        # Return the dictionary
        return $paramDictionary
    }


BEGIN {

		# Do some variable parameter validation
		if ((($ServerRoles -contains "ARCHIVE") -or ($ServerRoles -contains "All")) -and (-not $PSCmdlet.MyInvocation.BoundParameters.ContainsKey("MessageCenterLoc")))
		{
				Write-Error "ARCHIVE role requires the MessageCenterLoc parameter"
				break
		}

		if ((($ServerRoles -contains "INDEX") -or ($ServerRoles -contains "All"))-and (-not $PSCmdlet.MyInvocation.BoundParameters.ContainsKey("ServersToIndex")))
		{
				Write-Error "INDEX role requires ServersToIndex parameter"
				break
		}
		#
		# Because we used a DynamicParam to only validate if the "ARCHIVE" role is set,
		#   we have to create the $MessageCenterLoc variable from the $PSBoundParameters
		#
		$MessageCenterLoc = $PSBoundParameters.MessageCenterLoc

		$MyDebug = $false
		# Do both these checks to take advantage of internal parsing of syntaxes like -Debug:$false
		if ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey("Debug") -and $PSCmdlet.MyInvocation.BoundParameters["Debug"].IsPresent)
		{
			$DebugPreference = "Continue"
			Write-Debug "Debug Output activated"
			# for convenience
			$MyDebug = $true
		}

	try {
		 [bool] $loaded = Add-ES1Types 

        if (-not $loaded )
        {
            Write-Error 'Error loading SourceOne Objects and Types'
            break
        }
	}
	catch
	{
		Write-Error $_ 
		break
	}
}

PROCESS {

	$asmgr = new-object -ComObject ExAsAdminAPI.CoExASAdminAPI
	$asmgr.Initialize()

	try {
		#  Get the repository requested
		$repo=$asmgr.GetRepository($ArchiveName)

		# Get the servers configured for this archive/repository
		$Servers = @($repo.EnumerateServers())

		#  Create the bitmask of roles
		[int] $newRoles=0
		foreach ($role in $ServerRoles)
		{
			switch ($role)
			{
				ARCHIVE
				{
					$newRoles = $newRoles -bor [EMC.Interop.ExASBaseAPI.exASServerPersonalities]::exASServerArchive
				}
				INDEX
				{
					$newRoles = $newRoles -bor [EMC.Interop.ExASBaseAPI.exASServerPersonalities]::exASServerIndex
				}

				SEARCH
				{
					$newRoles = $newRoles -bor [EMC.Interop.ExASBaseAPI.exASServerPersonalities]::exASServerQuery
				}

				RETRIEVAL
				{
					$newRoles = $newRoles -bor [EMC.Interop.ExASBaseAPI.exASServerPersonalities]::exASServerRetrieval
				}

				ALL
				{
					$newRoles = [EMC.Interop.ExASBaseAPI.exASServerPersonalities]::exASServerAll
				}
			}
	    }


		foreach ($machine in $Servers)
		{
			# Is this the machine we want to change roles on ?
			if ($machine.Fullname -eq $ArchiveServerName)
			{
				Write-Verbose "Found server to modify: $($machine.FullName)"
				# Yes it is...
				$machine.SetTraceInfo($Global:S1LogFile)
				$machine.ServerPersonality = $newRoles
    
               if ($newRoles -band [EMC.Interop.ExASBaseAPI.exASServerPersonalities]::exASServerArchive )
               {
					Write-Verbose "Server $($machine.FullName) : Message Center Location set to $($MessageCenterLoc)"
                    $machine.MessageCenterDir = $MessageCenterLoc
               }

               if ($newRoles -band [EMC.Interop.ExASBaseAPI.exASServerPersonalities]::exASServerIndex )
               {                    
					Write-Verbose "Server $($machine.FullName) : Enabling Indexing for $($ServersToIndex)"
                    $ArchiversToIndex = New-Object -ComObject ExSTLContainers.CoExVector

					# The server names MUST match the same case as in the configruation so the UI
					# will show the role enabled.  We'll use the name S1 knows 
					foreach($S1host in $ServersToIndex)
					{
						$S1Name = $Servers | where {$_.FullName -eq $S1host}
						if ($S1Name)
						{
							$ArchiversToIndex.Add($S1Name.FullName)
						}
						else
                        {
                            throw "Error: $($S1host) is not a server for this archive" 
                        }
					}
                    
					$machine.ArchiveServerNames=$ArchiversToIndex
                  
               }

			   # Validate and Save if everything is OK
			   	Write-Verbose "Validating new roles for Server $($machine.FullName)"
				$results = $machine.Validate()
				foreach ($valResult in $results)
				{
					# Check the "IsWarning" attibute, false means fatal error
					if ($valResult.IsWarning -eq $false)
					{
						throw $valResult.errorDescription
					}
					else
					{
						Write-Warning "$($valResult.errorDescription)"
					}
    
				}

				Write-Verbose "Saving new configuration for Server $($machine.FullName)"
				$machine.Save()

				break
			}

		}

	}
	catch
	{
		Write-Error $_

	}
	 finally
    {
         if ($asmgr)
         {
            [System.Runtime.Interopservices.Marshal]::ReleaseComObject($asmgr) > $null
         }


    }
 
}
END{}
}
<#
.SYNOPSIS
	
.DESCRIPTION

.PARAMETER ArchiveName
	Optional, The archive connection name to get the server configruation for.  If not provided the server configurations for all
	archives is returned.
	
.EXAMPLE

#>
function Get-ES1ArchiveConnection
{
	[CmdletBinding()]
	param( 
	[Parameter(Mandatory=$false)]
	[Alias('archive')]
	[string] $ArchiveName)

	BEGIN {
		try {
			[bool] $loaded = Add-ES1Types #-ErrorAction SilentlyContinue

			if (-not $loaded )
			{
				Write-Error 'Error loading SourceOne Objects and Types'
				break
			}
		}
		catch
		{
			Write-Error $_ 
			break
		}


	}

  PROCESS {

  try {
			
		$JDFAPIMgrClass = new-object -TypeName EMC.Interop.ExJDFAPI.CoExJDFAPIMgrClass
		$JDFAPIMgrClass.SetTraceInfo($Global:S1LogFile)

		$providerCfgs = $JDFAPIMgrClass.GetProviderTypeConfigs()
		
		# If a single archive was passed in find it.
		if ($ArchiveName)
		{
			$ASRepos = @($providerCfgs | where {$_.Name -eq $ArchiveName} )
			if ($ASRepos.Length -le 0)
			{
				throw "Argument Error:  Could not find any archive named $($ArchiveName))"
			}
		}
		else
		{
			$ASRepos = $providerCfgs
		}
		
		$AllArchives = @()

		foreach ($repo in $ASRepos)
		{
			$archiveDB='NA'
			$archiveDBServer='NA'

	        $typeName = ([EMC.Interop.ExBase.exDataProviderType]$repo.providerTypeID).ToString().Substring(19)
			[System.Xml.XmlDocument] $XMLcfg=$repo.XConfig
			
			if (($repo.providerTypeID -eq [EMC.Interop.ExBase.exDataProviderType]::exDataProviderType_ExAS) -or `
				($repo.providerTypeID -eq [EMC.Interop.ExBase.exDataProviderType]::exDataProviderType_ExAsIPM))
				{
					$archiveDB=$XMLcfg.ExASProviderConfig.DBName
					$archiveDBServer=$XMLcfg.ExASProviderConfig.DBServer
				}
			
			if ($repo.providerTypeID -eq [EMC.Interop.ExBase.exDataProviderType]::exDataProviderType_Ex4X) 
				{
					$archiveDB=$XMLcfg.GeneralCfgProps.Servers.Server.DbConnection.SQLDBName
					$archiveDBServer=$XMLcfg.GeneralCfgProps.Servers.Server.DBConnection.SQLServer
				}


			$props = [ordered]@{'ArchiveName'=$repo.Name;'ID'=$repo.Id ;'ProviderTypeID'=$repo.providerTypeID ; `
			                     'TypeName'=$typeName; 'DBServer'=$archiveDBServer; 'DBName'=$archiveDB; `
								 'Created'=$repo.createTime; 'LastModfied'=$repo.lastModified; `
								 'ModifiedBy'= $repo.modifiedBy}
			
			$AllArchives += New-object -TypeName PSObject -Prop $props
		} 

	}
 catch {
			Write-Error $_
		}
		finally
		{
		}

		$AllArchives

	}
	END {}

}

New-Alias -Name Get-ArchiveServerConfig -Value Get-ES1ArchiveServerConfig

Export-ModuleMember -Function * -Alias *


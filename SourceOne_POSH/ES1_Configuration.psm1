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
		Functions for inspecting the SourceOne configuration

#>

#requires -Version 3

<#
.SYNOPSIS
 Displays a list of S1 machines and the S1 installed executables and DLL 
files in the S1 installation directory
.DESCRIPTION
Displays a list of S1 machines and the S1 installed executables and DLL
files in the S1 installation directory
.OUTPUTS

.EXAMPLE

#>
function Show-ES1Executables
{
[CmdletBinding()]
param( )

begin{}
process {
	[bool] $onMaster = Test-IsOnS1Master
	$scriptComputerName = [environment]::MachineName

	#-------------------------------------------------------------------------------
	# Get Activity Database
	#-------------------------------------------------------------------------------
	Get-ES1ActivityDB | out-null

	#-------------------------------------------------------------------------------
	# Get List of SourceOne Servers
	#-------------------------------------------------------------------------------
	$cServers = @()
	$cServers += $scriptComputerName

	# Get SourceOne Worker Servers
	$dtResults = Get-ES1Workers 
	foreach ($row in $dtResults)
	{
		$cServers += ($row[0].Split("."))[0]
	}


	$dtResults = @(Get-ES1Archivers)
	foreach ($row in $dtResults)
	{
		$cServers += ($row.Split("."))[0]
	} 


	# Remove Duplicates from SourceOne Server List
	$cServers = @($cServers | Select -uniq | Sort)
	$AllBinaries = @()

	Write-Debug "Server Count is: $($cServers.Count)"
	$local = hostname

	# Process each Server
	foreach ($server in $cServers)
	{
		Write-Host 'Getting binaries from server : ' $server

		try {
			$installPath = S1Dir $server

			# Append * so the -Include filter works...
			$installPath += '\*'

			if ($server -eq $local)
			{
				$exeFiles = ls -recurse -path $installpath -Include @("*.exe","*.dll") | select-object -ExpandProperty VersionInfo 
				$AllBinaries += $exeFiles
			}
			else
			{

				if (Test-PsRemoting $server)
				{

					$files = Invoke-Command -Cn $server -ScriptBlock{
						$exeFiles = ls -recurse -path $Args[0] -Include @("*.exe","*.dll") | select-object -ExpandProperty VersionInfo 
						$exeFiles
					} -Args $installPath -ErrorVariable remoteErr -ErrorAction SilentlyContinue

					# $remoteErr contains any error message from the remote system
					if ($remoteErr)
					{
						write-warning $remoteErr
						$props = [ordered]@{'PSComputerName'=$server;'FileName'=$remoteErr ;'FileVersion'="ERROR"}
						$AllBinaries += New-object -TypeName PSObject -Prop $props
					}
					else
					{
						$AllBinaries += $files
					}
				}
				else
				{
					write-warning "**** Ps Remoting is not enabled on remote $server ******"
					$props = [ordered]@{'PSComputerName'=$server;'FileName'='NA' ;'FileVersion'="Unreachable - Powershell remoting not enabled"}
					$AllBinaries += New-object -TypeName PSObject -Prop $props
				}
			}
		}
		catch 
		{
			Write-Warning "Error Reading registry on machine : $server"
			Write-Warning "Make sure the machine is up and reachable on the network"
			$props = [ordered]@{'PSComputerName'=$server;'FileName'=$_.Exception.Message ;'FileVersion'="NA"}
			$AllBinaries += New-object -TypeName PSObject -Prop $props

			continue
		} 

	} 

	#$AllBinaries | select-object PSComputerName, FileName, FileVersion | Format-Table -AutoSize #| Out-String -Width 10000
	
	# Now that POSH 4 or greater is required the [ordered] type above should mean the select to order things is not needed anymore
	
	$AllBinaries | Format-Table -AutoSize #| Out-String -Width 10000
}
end{}

}

<#
.SYNOPSIS
 Gets a list of S1 machines and the S1 installed executables and DLL 
files in the S1 installation directory
.DESCRIPTION
Gets a list of S1 machines and the S1 installed executables and DLL
files in the S1 installation directory
.OUTPUTS

.EXAMPLE

#>
function Get-ES1Executables
{
[CmdletBinding()]
param( )

begin{}
process {
	[bool] $onMaster = Test-IsOnS1Master
	$scriptComputerName = [environment]::MachineName

	#-------------------------------------------------------------------------------
	# Get Activity Database
	#-------------------------------------------------------------------------------

	Get-ES1ActivityDB | out-null

	#-------------------------------------------------------------------------------
	# Get List known of SourceOne Servers
	#-------------------------------------------------------------------------------
	$cServers = @()
	$cServers += $scriptComputerName

	# Get SourceOne Worker Servers
	$dtResults = Get-ES1Workers 
	foreach ($row in $dtResults)
	{
		$cServers += ($row[0].Split("."))[0]
	}


	$dtResults = @(Get-ES1Archivers)
	foreach ($row in $dtResults)
	{
		$cServers += ($row.Split("."))[0]
	} 


	# Remove Duplicates from SourceOne Server List
	$cServers = @($cServers | Select -uniq | Sort)
	$AllBinaries = @()

	Write-Debug "Server Count is: $($cServers.Count)"
	$local = hostname

	# Process each Server
	foreach ($server in $cServers)
	{
		# Write-Host 'Getting binaries from server : ' $server

		try {
			$installPath = S1Dir $server

			# Append * so the -Include filter works...
			$installPath += '\*'

			if ($server -eq $local)
			{
				$exeFiles = ls -recurse -path $installpath -Include @("*.exe","*.dll") | select-object -ExpandProperty VersionInfo 
				$AllBinaries += $exeFiles
			}
			else
			{

				if (Test-PsRemoting $server)
				{

					$files = Invoke-Command -Cn $server -ScriptBlock{
						$exeFiles = ls -recurse -path $Args[0] -Include @("*.exe","*.dll") | select-object -ExpandProperty VersionInfo 
						$exeFiles
					} -Args $installPath -ErrorVariable remoteErr -ErrorAction SilentlyContinue

					# $remoteErr contains any error message from the remote system
					if ($remoteErr)
					{
						write-warning $remoteErr
						$props = [ordered]@{'PSComputerName'=$server;'FileName'=$remoteErr ;'FileVersion'="ERROR"}
						$AllBinaries += New-object -TypeName PSObject -Prop $props
					}
					else
					{
						$AllBinaries += $files
					}
				}
				else
				{
					write-warning "**** Ps Remoting is not enabled on remote $server ******"
					$props = [ordered]@{'PSComputerName'=$server;'FileName'='NA' ;'FileVersion'="Unreachable - Powershell remoting not enabled"}
					$AllBinaries += New-object -TypeName PSObject -Prop $props
				}
			}
		}
		catch 
		{
			Write-Warning "Error Reading registry on machine : $server"
			Write-Warning "Make sure the machine is up and reachable on the network"
			$props = [ordered]@{'PSComputerName'=$server;'FileName'=$_.Exception.Message ;'FileVersion'="NA"}
			$AllBinaries += New-object -TypeName PSObject -Prop $props

			continue
		} 

	} 

	
	$AllBinaries

}
end{}

}

<#
.SYNOPSIS
 Returns a string containing the S1 install directory from the machine specified (defaults to current machine)

.DESCRIPTION
 Returns a string containing the S1 install directory from the machine specified
 The Value is retrieved from the machine registry.

.PARAMETER server
 server or host Name to get the S1 install directory from

.OUTPUTS
 Set a session variable $S1InstallDir

.EXAMPLE 
    Get-ES1InstallDir
    D:\Program Files\EMC SourceOne
.EXAMPLE 
    Get-ES1InstallDir | out-null
    D:\Program Files\EMC SourceOne
#>
function Get-ES1InstallDir
{
[CmdletBinding()]
param( 
	[string] $server = $env:computername
)

begin{}
process {

	try {
		$reg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine', $server)
	}
	catch {

		Throw $_
	}

	# Try the 64 bit location first as 64 bit OS's are most common these days.
	$keypath = 'SOFTWARE\Wow6432Node\EMC\SourceOne'
	$regkey = $reg.OpenSubkey($keypath)
	if ($regkey -eq $null)
	{
		$keypath = 'SOFTWARE\EMC\SourceOne'
		$regkey = $reg.OpenSubkey($keypath)
	}

	if ($regkey -ne $null)
	{
		#
		# Get the install dir
		#
		$valuename ='InstallDir' 

		$readvalue = $regkey.GetValue($valuename) 
		if ($readvalue -ne 0)
		{
			Write-Debug "$server`t$regkey`t$valuename`t$readvalue" 
		}

		$reg.Close()
	}

	# Return the value from the registry...
	$readvalue
	$Script:S1InstallDir = $readvalue
}
end {}
}

$s1JobLogDir = ''
$emcRegEntry = ''
$emcRegLoc = ''
$s1ActServer = ''
$s1ActDb = ''
$s1ActObject = @{}

$s1Archivers = @()
$s1serverList = @()
$s1servers = @()
$S1RegBase = ''
$s1ServerInfoObjects = @()
$s1InstallObjects = @()


$AgentTable = @{'EMC SourceOne Console' = 'Console';
	'EMC SourceOne Native Archive Services' = 'Archive';
	'EMC SourceOne Master Services' = 'Master';
	'EMC SourceOne Search' = 'Search';
	'EMC SourceOne Worker Services' = 'Worker';
	'EMC SourceOne Web Services' = 'WebServices';
	'EMC SourceOne Mobile Services' = 'Mobile';
	'EMC SourceOne Discovery Manager Server' = 'DiscoveryManagerServer';
	'EMC SourceOne Discovery Express Manager Server' = 'DiscoveryManagerExpressServer';
	'EMC SourceOne Business Component Extensions for File Archiving' = 'FilearchiveBCE';
	'EMC SourceOne Business Component Extensions for Microsoft SharePoint' = 'SharepointBCE';
	'EMC SourceOne Discovery Manager Web' = 'DiscoveryManagerWeb'}


<#
.SYNOPSIS
  Returns a string containing the HKLM base path in the windows registry where SourceOne settings are found based on the
  OS architecture (64 bit or 32 bit)

.DESCRIPTION
   Returns a string containing the HKLM base path in the windows registry where SourceOne settings are found based on the
   OS architecture (64 bit or 32 bit).  Depending on the OS either "HKLM:\SOFTWARE\Wow6432Node"  or "HKLM:\SOFTWARE" will be returned.

.OUTPUTS
  <TBD>

.EXAMPLE
   $OSRegBase = Get-ES1RegBase
#>
function Get-ES1RegBase
{

[CmdletBinding()]
Param()

Begin{}
Process {
if ($Script:s1RegBase -eq '')
{
	if (Test-Path -Path HKLM:\SOFTWARE\Wow6432Node\EMC\SourceOne)
		{

			$Script:s1RegBase = "HKLM:\SOFTWARE\Wow6432Node"

		}
		else
		{
			$Script:s1RegBase = "HKLM:\SOFTWARE"

		} 

	}
	$script:S1RegBase
}

END {}

}

<#
.SYNOPSIS
  Returns a string containing the HKLM full path in the windows registry where SourceOne settings are found based on the
  OS architecture (64 bit or 32 bit).

.DESCRIPTION
  Returns a string containing the HKLM full path in the windows registry where SourceOne settings are found based on the
  OS architecture (64 bit or 32 bit).  Depending on the OS architecture either "HKLM:\SOFTWARE\Wow6432Node\EMC\SourceOne\"  
  or "HKLM:\SOFTWARE\EMC\SourceOne\" will be returned.

.OUTPUTS
  <TBD>

.EXAMPLE

#>
function Get-ES1RegEntry
 {
	[CmdletBinding()]
	param()
	Get-ES1RegBase | out-null
	if ($Script:emcRegEntry -eq '')
	{
		$Script:emcRegEntry = $script:S1RegBase + "\EMC\SourceOne\"
	}

	$Script:emcRegEntry
} 

<#
.SYNOPSIS
  Returns a string containing full provider name and HKLM path in the windows registry where SourceOne settings are found 
  based on the OS architecture (64 bit or 32 bit).

.DESCRIPTION
  Returns a string containing full provider name and HKLM path in the windows registry where SourceOne settings are found 
  based on the OS architecture (64 bit or 32 bit).  Either "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Wow6432Node\EMC\SourceOne\"
  or "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\EMC\SourceOne\"

.OUTPUTS
  <TBD>

.EXAMPLE
  $s1Registry= Get-ES1RegLocation

#>
function Get-ES1RegLocation
{
 [CmdletBinding()]
param()
get-ES1RegEntry | Out-Null
$Script:emcRegLoc = $Script:emcRegEntry.Replace("HKLM:","HKEY_LOCAL_MACHINE")
$Script:emcRegLoc = "Registry::" + $Script:emcRegLoc

$Script:emcRegLoc

}

<#
.SYNOPSIS
   Returns a string containing the full path of the SourceOne install directory on the current machine.  This is obtained from the 
   Windows registry.

.DESCRIPTION
   Returns a string containing the full path of the SourceOne install directory on tghe current machine.  This is obtained from the 
   Windows registry.

.OUTPUTS
  <TBD>

.EXAMPLE
	$S1InstallDir=Get-ES1InstallFolders
#>
function Get-ES1InstallFolders
 {
	[CmdletBinding()]
	param()

	get-ES1RegLocation | Out-Null

	$Node = get-itemproperty -path $Script:emcRegEntry -name installdir
	$Script:s1InstallDir = $Node.InstallDir
	$Script:s1LogDir = $Script:s1InstallDir + "logs\"
	$Script:s1InstallDir

}

<#
.SYNOPSIS
   Get-ES1JobLogDir
.DESCRIPTION
   Retrieve the location of the SourceOne JobLogs share
.OUTPUTS
 Sets a session variable $s1JobLogDir
.EXAMPLE
   Get-ES1JobLogDir
   \\master\JobLogs
#>
function Get-ES1JobLogDir
 {
	[CmdletBinding()]
	param()

	if ($Script:s1JobLogDir -eq '')
	{
		get-ES1RegLocation | Out-Null

		$Node = get-itemproperty -path $Script:emcRegEntry -name joblogdir -ErrorAction SilentlyContinue
		$Script:s1JobLogDir = $Node.JobLogDir

		if ($Script:s1JobLogDir -ne $null)
		{
			$Script:s1JobLogDir = $Node.JobLogDir
		}
		else
		{
			$Script:s1JobLogDir = Read-Host "JobLogDir entry not found $Script:emcRegEntry - Enter location "
			Write-Verbose $Script:s1JobLogDir
			if (!(Test-Path $Script:s1JobLogDir)) 
			{
				# this statement is not viewable if this function is called indirectly.
				Write-Host "Job share location is not valid"
				$Script:s1JobLogDir = ''
			}
		}
	} 
	$Script:s1JobLogDir

}



<#
.SYNOPSIS
   <A brief description of the script>
.DESCRIPTION
   <A detailed description of the script>
.PARAMETER <paramName>
   <Description of script parameter>
.EXAMPLE
   <An example of using the script>
#>


function Get-ES1ActivityDatabase
{
<#
.SYNOPSIS
  Gets the SourceOne SQL server and activity DB Name and if not already set, sets the session global
  variables $s1ActServer and $s1actDb
.DESCRIPTION
 Gets the SourceOne SQL server and activity DB Name and if not already set, sets the session global
  variables $s1ActServer and $s1actDb

.PARAMETER Force
	the Force parameter will cause the session global values to be updated/refreshed
.EXAMPLE
	$activityDB=Get-ES1ActivityDatabase

.EXAMPLE
	Get-ES1ActivityDatabase -force
	
DBName      DBServer
----------  --------------
ES1Activity SQL2008   

.OUTPUTS

#>
[CmdletBinding()]
param(
	[switch]$force
)
try
{
	if ($force -or ($Script:s1ActServer -eq '') -or ($Script:s1ActDb -eq ''))
	{

		$s1R = get-ES1RegLocation 
		#$s1RegVersion = $s1R + "versions"

		$script:s1ActServer = (Get-ItemProperty -Path $s1R).Server_JDF
		$script:s1actDb = (Get-ItemProperty -Path $s1R).DB_JDF

		if (!($script:s1ActServer))
		{
			$script:s1ActServer = Read-Host "Information cannot be retrieved from the registry, enter the name of the SourceOne SQL server"
			$script:s1ActDb = Read-Host "enter the name of the SourceOne Activity Database"
		}

		$script:s1ActInfo = @{'DBServer'=$script:S1ActServer;'DBName'=$script:s1ActDb}
		$script:s1ActObject = New-Object -TypeName psobject -Property $s1ActInfo
		$script:s1ActObject
	}
	else
	{

		$script:s1ActObject
	}

}
catch
{
	Write-Warning "Unable to access SourceOne registry information?"

}
}

<#
.SYNOPSIS
  Get-ES1Archivers
.DESCRIPTION
  Retrieve information from SQL about SourceOne Archive servers
.OUTPUTS
 Sets session array $s1Archivers
.EXAMPLE
   Get-ES1Archivers
   
   Archive01
   IPMArchive
   
#>
function Get-ES1Archivers
{
 [CmdletBinding()]
param()
#-------------------------------------------------------------------------------
# Get Activity Database
#-------------------------------------------------------------------------------
Get-ES1ActivityDB | out-null

$sqlQuery = @'
Select Name AS Connection,
       xConfig.value('(/ExASProviderConfig/DBServer)[1]','nvarchar(max)') AS DBServer,
       xConfig.value('(/ExASProviderConfig/DBName)[1]','nvarchar(max)') AS DBName
From ProviderConfig (nolock)
Where ProviderTypeID <> 5 AND State = 1    
'@

$dtConnections = Invoke-ES1SQLQuery $Script:s1ActServer $Script:S1Actdb $sqlQuery


$cServers = @() 

# Get SourceOne Archiver Servers
foreach ($row in $dtConnections)
{
	$dbname = $row.DBName
	$dbserver = $row.DBServer 

	$dtResults = Get-ES1NAServers $dbServer $dbName
	#$dtResults

	foreach ($row in $dtResults)
	{
		$cServers += ($row[0].Split("."))[0]
	} 
} 

# Remove Duplicates from SourceOne Server List
$cServers = $cServers | Select -uniq | Sort
$cServers
$Script:s1Archivers = $cServers

}


#-------------------------------------------------------------------------------
# Function:  Get-ES1NAServers
#-------------------------------------------------------------------------------
function Get-ES1NAServers
{
 [CmdletBinding()]

param
(
	[Parameter(Position=0,Mandatory=$true)]
	[string] $dbServer,

	[Parameter(Position=1,Mandatory=$true)]
	[string] $dbName
)

#
# Define SQL Query
#
$sqlQuery = @'
SELECT DISTINCT UPPER(ServerName) AS ServerName FROM ServerInfo (NOLOCK) WHERE LEN(MacAddress) > 0
'@

$dtResults = Invoke-ES1SQLQuery $dbServer $dbName $sqlQuery

$dtResultsMod = New-Object system.Data.DataTable 'Archivers'
$col1 = New-Object system.Data.DataColumn HostName,([string])
$dtResultsMod.columns.add($col1)

if ($dtResults -ne $null)
{
	foreach ($row in $dtResults)
	{
		$rowMod = $dtResultsMod.NewRow()
		if ($row.ServerName.Contains('.'))
		{
			$rowMod.HostName = $row.ServerName.Split('.')[0]
		}
		else
		{
			$rowMod.HostName = $row.ServerName 
		}
		$dtResultsMod.Rows.Add($rowMod)
	} 
}

$dtResultsMod 
}

<#
.SYNOPSIS
   Gets a list of all the SourceOne workers and archive servers
.DESCRIPTION
   Gets a list of all the SourceOne workers and archive servers using direct SQL queries.  
   Does not return machine names which are in the "deleted" state (state=32767).

.EXAMPLE
   Get-ES1ServerList
 
 .EXAMPLE
   $allServers=Get-ES1ServerList

#>
function Get-ES1ServerList
{
 [CmdletBinding()]
param()
$serverList = @()

Write-verbose "Start - Number of Archivers $($Script:s1Archivers.count) "

if ($Script:s1Archivers.count -eq 0)
{
	Write-Verbose "Getting archive servers..."
	$Script:s1Archivers = @(Get-ES1Archivers)
}

Write-verbose "Number of Archivers found : $($Script:s1Archivers.count) "

foreach ($server in $Script:s1Archivers)
{
	Write-Verbose "Archiver Server : $($server)"
	$props = @{computername=$server}
	$obj = New-Object -TypeName psobject -Property $props
	$serverList += $obj
}

#
# s1Workers is exported from ES1_WorkerRolesUtils.psm1
#
Write-Verbose "Number of workers: $($Script:s1workers.count)"
if ($Script:s1Workers.count -eq 0)
{
	Write-Verbose "Getting worker servers..."
	$Script:s1Workers = @(Get-ES1Workers)
}

foreach ($s in $Script:s1Workers)
{

	$server = $s.servername.tostring()
	Write-Verbose "Worker Server: $($s | out-string )"

	$parts = $server.split('.')
	$props = @{computername=$parts[0]}
	$obj = New-Object -TypeName psobject -Property $props
	$serverList += $obj

}

write-verbose "Server List before dedup $($serverlist | Out-String)" 

$Script:s1serverList = $serverList | Select-Object computername -uniq 
$Script:s1serverList

} 

<#
.SYNOPSIS
   Retrieve a list/array of all SourceOne servers (workers and archivers)
.DESCRIPTION
   Retrieve a list/array of all SourceOne servers (workers and archivers)
.OUTPUTS s1servers
  Sets a session (global) array called $s1Servers with machine name of all workers and archiver servers

.EXAMPLE
   Get-ES1Servers
   
   master
   worker01
   IPMArchive
   Worker02
#>
function Get-ES1Servers
{
 [CmdletBinding()]
param()
$Script:s1servers = @()
if ($Script:s1serverList.Count -eq 0)
{
	write-verbose "Updating S1ServerList"
	Get-ES1ServerList | out-null
}
foreach ($s in $Script:s1serverlist)
{

	write-verbose $s.computername
	$Script:s1servers += $s.computername

}
$Script:s1servers
}

<#
.SYNOPSIS
   Get-ES1ServerSoftwareInfo
.DESCRIPTION
   Get a list of the EMC Sourceone Software on the specified server
   The uninstall registry key is queried
.PARAMETER computername
   name or IP of the server to query
.OUTPUTS
  a session array $s1SWObjects is populated and displayed
.EXAMPLE
   Get-ES1ServerSoftwareInfo master
   
  DisplayName								Version
  EMC SourceOne Native Archive Services		7.20.2524
  EMC SourceOne Console						7.20.2524
  EMC SourceOne Web Services				7.20.2524
   
#>
function Get-ES1ServerSoftwareInfo
{
[CmdletBinding()]
param
(
 [string] $computername)



$Script:s1SWObjects = @()



$b = get-ES1RegBase
$b = $b.replace('HKLM:\','')
$entry = $b + "\Microsoft\Windows\CurrentVersion\Uninstall"
write-verbose $ComputerName

$Reg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine', $ComputerName)
$Key = $Reg.OpenSubKey($entry)

if ($Key)
{

	foreach ($prop in $Key.GetSubKeyNames())
	{

		$KeyObj = $key.OpenSubKey($prop)
		if ($keyobj)
		{
			foreach ($entry in $KeyObj.GetValueNames())
			{


				if ($entry -eq "DisplayName")
				{

					$dname = $keyobj.Getvalue("DisplayName")
					#$dname
					if ($dname -match "EMC")
					{

						write-verbose "$prop.ToString()"
						$dvers = $keyobj.Getvalue("DisplayVersion")
						$agentname = ''
						if ($AgentTable.Contains($dname))
						{
							$agentname = $AgentTable.$dname
						}

						$swInfo = [ordered]@{'DisplayName'=$dname;'Version'=$dvers;'AgentName'=$agentname}
						$swobj = New-Object -TypeName psobject -Property $swinfo
						$Script:s1SWObjects += $swobj

					}

				}
			}
		}
	}
}


$Script:s1SWObjects 


}


<#
.SYNOPSIS
  Returns an array of all the SourceOne services, software and version number installed on all
   discoverable machines in a SourceOne implementation

.DESCRIPTION
   Returns an array of all the SourceOne services, software and version number installed on all
   discoverable machines in a SourceOne implementation

.EXAMPLE
   $s1serversinfo = Get-ES1AllServerInfoObjects

#>
function Get-ES1AllServerInfoObjects
{

[CmdletBinding()]
param
()

if ($Script:s1servers.count -eq 0)
{
	get-ES1servers | out-null

} 



$Script:s1ServerInfoObjects = @()

foreach ($comp in $Script:s1servers)
{
	$swObjects = @()
	$srvObjects = @()
	Write-Verbose $comp


	try
	{
		$srvObjects = @(get-es1Services $comp)
		$swObjects = @(get-ES1ServerSoftwareInfo $comp)

		$mainprops = [ordered] @{servername=$comp;
			Software = $swObjects;
			Services = $srvObjects}
		$mainobject = New-Object -Type psobject -Property $mainprops
		Write-Verbose $mainobject
		$Script:s1ServerInfoObjects += $mainobject
	}
	catch
	{
		Write-Error $_
	}

}


$Script:s1ServerInfoObjects
}

<#
.SYNOPSIS
   Shows all the SourceOne services, software and version number installed on all
   discoverable machines in a SourceOne implementation
.DESCRIPTION
   Shows all the SourceOne services, software and version number installed on all
   discoverable machines in a SourceOne implementation

.EXAMPLE
 Show-ES1ServerInfo

Information for SourceOne server IPMARCHIVE2
Services on SourceOne server     IPMARCHIVE2

Status  Name                        DisplayName
------  ----                        -----------
Running ES1AddressResolutionService EMC SourceOne Address Resolution
Running ES1InPlaceMigService        EMC SourceOne Inplace Migration
Running ExAsAdmin                   EMC SourceOne Administrator
Stopped ExAsArchive                 EMC SourceOne Archive
Stopped ExAsIndex                   EMC SourceOne Indexer
Running ExAsQuery                   EMC SourceOne Query
Running ExJobDispatcher             EMC SourceOne Job Dispatcher

Software Installed on SourceOne server IPMARCHIVE2

DisplayName                               Version   AgentName
-----------                               -------   ---------
EMC SourceOne Native Archive Services     7.13.3054 Archive
EMC SourceOne In Place Migration Services 7.30.0084
EMC SourceOne Worker Services             7.13.3054 Worker


#>
function Show-ES1ServerInfo
{
[CmdletBinding()]
param
()

if ($Script:s1ServerInfoObjects.count -eq 0)
{

	Get-ES1AllServerInfoObjects > $null
}

foreach ($obj in $Script:s1ServerInfoObjects)
{

	write-output "Information for SourceOne server $($obj.servername)"
	write-output "Services on SourceOne server     $($obj.servername)"
	$obj.services | Format-Table
	write-output "Software Installed on SourceOne server $($obj.servername)"
	$obj.software | Format-Table
}


}


<#
.SYNOPSIS
   Gets a list of objects containing simplified name for each installed service  
   for each discoverable SourceOne machine.
.DESCRIPTION
   Gets a list of objects containing simplified name for each installed service  
   for each discoverable SourceOne machine.  The simple name if derived from an internal table
   lookup.

.EXAMPLE
   Get-ES1AgentListObjs

#>
function Get-ES1AgentListObjs
{
[CmdletBinding()]
param
([Parameter(Mandatory=$false,
		ValueFromPipeLine=$true, 
		ValueFromPipeLineByPropertyName=$true)]
	[string[]]$ComputerArray )

# TODO - Finish implementing the $ComputerArray ...

$Script:s1InstallObjects=@()

$S1InfoObjs = Get-ES1AllServerInfoObjects



foreach ($s in $S1InfoObjs)
{
	$rolestr = ""
	$mname = $s.servername
	Write-Verbose $mname
	Write-Verbose $s.software.count 
	if ($s.Software.count -gt 0)
	{
		foreach ($c in $s.Software)
		{
			Write-Verbose $c.agentname
			if ($c.agentname -ne '')
			{
				$role = $c.agentname
				$rolestr += "$role"
				$rolestr += ","
			}

		}
		if ($rolestr.length -gt 4)
		{
			$rolestr = $rolestr.Trim(",")
			#      $rolestr += "`""
		}
	}

	$installInfo = [ordered]@{'MachineName'=$mname;'Role'=$RoleStr}
	$installObj = New-Object -TypeName psobject -Property $installInfo

	$Script:s1InstallObjects += $installObj

}

$Script:s1InstallObjects

}


<#
.SYNOPSIS
   Sets the SourceOne logging trace verbosity level in the Windows registry for the specified component
   on the specified computer.  The component name is the same value as shown in the registry.
   Setting or changing a trace verbosity level will force logging to be enabled and set the maximum number 
   of split files.
.DESCRIPTION
   Sets the SourceOne logging trace verbosity level in the Windows registry for the specified component
   on the specified computer.  The component name is the same value as shown in the registry.
   Setting or changing a trace verbosity level will force logging to be enabled and set the maximum number 
   of split files.

.PARAMETER Computer
	Name of the computer to change the trace settings on
.PARAMETER component
	Name of the component.  Should be an exact match to the value in the "TraceLogs" registry hive.
.PARAMETER level
	Logging/trace level.  Valid range is 0 - 7
.PARAMETER split
	Maximum number of "split" logfiles to keep on disk
.PARAMETER disable
	Disable logging for the component


.EXAMPLE
   Set-ES1Trace -level 0 -component exarchivejbc.exe

#>
function Set-ES1Trace 
{
[CmdletBinding()]
PARAM([Parameter(Mandatory=$true)]
	[string] $component,
	[Parameter(Mandatory=$false)] 
	[ValidateRange(0,7)] [int] $level = 4,
	[Parameter(Mandatory=$false)]
	[int]$split = 10,
	[Parameter(Mandatory=$false)]
	[switch] $disable,
	[Parameter(Mandatory=$false,
		ValueFromPipeLine=$true, 
		ValueFromPipeLineByPropertyName=$true)]
	[string[]]$ComputerArray =$env:COMPUTERNAME)
	

BEGIN {
	$Results=@()
}

PROCESS {

	Write-Host ""

	$ON = '1'
	if ($disable) 
	{
		$ON = '0'
	}

	foreach ($Computer in $ComputerArray )
	{
		$b = get-ES1RegBase
		$b = $b.replace('HKLM:\','')
		$entry = $b + "\EMC\SourceOne\Tracelogs"

		if ($component -ne $null)
		{
			$EMCTraceSettings = $entry + "\$component\Settings"
			write-verbose $EMCTraceSettings
			#$EMCTraceEnable = $EMCTraceSettings + "\Listeners\File"

			try
			{
				$Reg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine', $Computer)
				if ($Reg)
				{
					$Key = $Reg.OpenSubKey("$EMCTraceSettings",$true)

				}
			}
			catch 
			{
				write-error "Error accessing registry on $($Computer)"
				$props = [ordered]@{'Computer'=$Computer;'Component'=$component ;'OldVerbosity'= 'NA'; 'TraceVerbosity'='NA';'Enabled'='NA'; 'Splits'='NA'}
				$Results += New-object -TypeName PSObject -Prop $props

				return
			}

			if ($key -ne $null)
			{

				if ($level.length -gt 0)
				{
					$x = $key.GetValue("TraceVerbosity")

					$key.SetValue("TraceVerbosity",$level,[Microsoft.Win32.RegistryValueKind]::DWORD) 
					#write-host "Modified tracesetting on $($Computer) for $component from $x to $level"

				}
				#ensure that MaxFileSplits are set and Tracing is enabled.
				$FileKey = $Reg.OpenSubKey("$EMCTraceSettings\\Listeners\\File",$true)
				if ($FileKey)
				{
					$FileKey.SetValue("Enabled",$ON,[Microsoft.Win32.RegistryValueKind]::DWORD) 
					$FileKey.SetValue("MaxFileSplits",$split,[Microsoft.Win32.RegistryValueKind]::DWORD) 

					#Write-Host "Logging Enabled = $ON, Max File Spilts set to $split"
				
					$props = [ordered]@{'Computer'=$Computer;'Component'=$component ;'OldVerbosity'= $x; 'TraceVerbosity'=$level;'Enabled'=$ON; 'Splits'=$split}
				}
				else
				{
					$props = [ordered]@{'Computer'=$Computer;'Component'=$component ;'OldVerbosity'= $x; 'TraceVerbosity'=$level;'Enabled'='NA'; 'Splits'='NA'}
				}

			}
			else
			{
				$props = [ordered]@{'Computer'=$Computer;'Component'=$component ;'OldVerbosity'= 'NA'; 'TraceVerbosity'='NA';'Enabled'='NA'; 'Splits'='NA'}
				write-host "Error reading Trace Setting for $component on  $($Computer)" -ForegroundColor Red
			}
			
		}
			
		$Results += New-object -TypeName PSObject -Prop $props
		
	}

}  # end PROCESS

END{
	$Results
}

}


<#
.SYNOPSIS
   Sets the SourceOne logging trace level in the Windows registry for the all installed components
   on the specified computer to the specified level.  Default level is 0 if none is specified.
.DESCRIPTION
   Sets the SourceOne logging trace level in the Windows registry for the all installed components
   on the specified computer to the specified level.  Default level is 0 if none is specified.

.EXAMPLE
   Set-ES1ResetTraceAll
#>
function Set-ES1ResetTraceAll 
{
	[CmdletBinding()]
	PARAM(
	[Parameter(Mandatory=$false)] 
	[string] $level = 0,
	[Parameter(Mandatory=$false)]
	$split = 10,
	[Parameter(Mandatory=$false)]
	[switch] $disable,
	[Parameter(Mandatory=$false)]
	[string] $Computer = $env:COMPUTERNAME )

	$ON = '1'
	if ($disable) 
	{
		$ON = '0'
	}

	$b = get-ES1RegBase
	$b = $b.replace('HKLM:\','')
	$EMCTrace = $b + "\EMC\SourceOne\Tracelogs"

	try
	{
		$Reg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine', $Computer)
		if ($Reg)
		{
			$Key = $Reg.OpenSubKey("$EMCTrace",$true)

		}
	}
	catch 
	{
		write-error "Error accessing registry on $($Computer)"
		return
	}
	if ($key)
	{

		$TraceLogKeys = @($key.GetSubKeyNames())
		foreach ($entry in $TraceLogKeys)
		{

			Set-ES1Trace -component $entry -level $level -computer $Computer

		}

	}
	else
	{
		write-host "No trace setting found $($Computer)"

	}

}



$s1InstallDir = ''
$s1LogDir = ''

<#
.SYNOPSIS
   Gets a list of the SourceOne logs files from the SourceOne Logs directory

.DESCRIPTION
   Gets a list of the SourceOne logs files from the SourceOne Logs directory.
   The return list contains System.IO.FileInfo objects.

.PARAMETER filespec
   If provided only, that file if returned.
.EXAMPLE
   Get-ES1TraceLogs
   
    Directory: C:\Program Files (x86)\EMC SourceOne\logs

Mode                LastWriteTime     Length Name
----                -------------     ------ ----
-a---         1/25/2017   2:55 PM          2 CExNotesInit.log
-a---        12/14/2017   2:33 PM   75552228 EmailXtenderSystemTrace.log
-a---          9/7/2017   2:17 PM    1071092 ES1AddressResolutionService.exe.log
-a---          8/3/2015   3:01 PM      36644 ExArchiveJBC.exe.log
-a---          8/3/2015   3:09 PM      83478 ExArchiveJBS.exe.log
-a---        12/14/2017   2:33 PM   59876752 ExJBJournal.exe.log
-a---        12/14/2017   1:51 PM    2076570 ExJournalJBS.exe.log
-a---         4/12/2017   5:36 PM     152446 ExMMCAdmin.dll.log
-a---         1/25/2017   2:55 PM          2 ExNotesApi.DLL.log


#>
function Get-ES1TraceLogs
{
[CmdletBinding()]

param([Parameter(Mandatory = $false)]
       [string] $fileSpec)

$eLoc = Get-ES1InstallFolders
$eLog = $eLoc + "logs\"
$Script:S1LogDIr = $eLog
$eLogSpec = $eLog + $fileSpec
gci $eLogSpec -ErrorAction SilentlyContinue



}


$WaitZipTime = 1

<#
.SYNOPSIS
   Compress a list of files into the named zip file.  Uses the Windows Shell.Application COM object
.DESCRIPTION
	Compress a list of files into the named zip file.  Uses the Windows Shell.Application COM object

.PARAMETER zipspec
	name of the zip file to create/update
   
.PARAMETER filespec
	list of files to zip 

.EXAMPLE
   dir $s1JobLogDir\*28*.log | Compress-FileListToZip l28.zip 
#>
function Compress-FileListToZip
 { 
	[CmdletBinding()]
	param(
    [string]$zipspec,
    [Parameter(ValueFromPipeLine=$true, 
	ValueFromPipeLineByPropertyName=$true)]
    [string[]]$filelist) 

BEGIN {

	$zipname = $zipspec

	if (-not $zipname.EndsWith('.zip')) {$zipname += '.zip'} 

	if (-not (test-path $zipname)) { 
		set-content $zipname ("PK" + [char]5 + [char]6 + ("$([char]0)" * 18)) 
	} 
	else
	{
		Write-Verbose "adding to current zip file"
	}
	
	#  The NameSpace method needs a FQ path to work
	$zipname = $zipname | get-item -ErrorAction Stop
	$shell = new-object -ComObject Shell.Application
	$ZipFile = $shell.NameSpace($zipname.FullName)
	#$ZipFile = (new-object -com shell.application).NameSpace($zipname) 
}

	#
	# Process is called for each item in the pipeline !
	#
PROCESS {
	if ($ZipFile -ne $null)
	{
		foreach ($c in $filelist)
		{
			write-output $c
            $shortname=Split-Path -Path $c -Leaf
			$ZipFile.CopyHere($c)
            #$size = $ZipFile.Items().Item($shortname).Size

            # CopyHere is Asynchronous, need to wait before adding another....            
            while($ZipFile.Items().Item($shortname) -Eq $null)
            {
                start-sleep -seconds $WaitZipTime
                write-verbose "." #-nonewline
            }

		}

	}
	else
	{
		Write-Output "unable to create NameSpace for $($zipname)"
	}
}

END {}

} 


<#
.SYNOPSIS
  Use the Windows Shell.Application COM object to unzip a file into a directory
.DESCRIPTION
   Use the Windows Shell.Application COM object to unzip a file into a directory

.PARAMETER zipspec
   Path of zip file to unzip

.PARAMETER destination
   Destination folder

.PARAMETER overwrite
   Overwrite the target file if it exists

.EXAMPLE
	TBD
#>
function Expand-ZipFile
{
[CmdletBinding()]
param([Parameter(Mandatory = $true)] [string] $zipspec, 
      [Parameter(Mandatory = $true)] [string] $destination,
      [Parameter(Mandatory = $false)] [switch] $overwrite
)


if (!(Test-Path $destination))
{
	mkdir $destination
}

$zipfile = (gci $zipspec).fullname

if (!(Test-Path $zipfile))
{
	Write-Host "$($zipfile) does not exit"
	return
}

$shell = new-object -com shell.application
$zip = $shell.NameSpace($zipfile)
foreach($item in $zip.items())
{

	$destFolder = $shell.Namespace($destination)
	if ($overwrite)
	{
		$destFolder.copyhere($item,16) #option to overwrite without asking?
	}
	else
	{
		$destFolder.copyhere($item)

	}

}
}

<#
.SYNOPSIS
   Compress a series of SourceOne logfiles into a single zip file.
.DESCRIPTION
   Compress a series of SourceOne logfiles into a single zip file.

.EXAMPLE
   <An example of using the script>
#>
function Compress-ES1TraceLogs
{
[CmdletBinding()]
param(
 [Parameter(Mandatory=$true)] 
[string] $filespec,
[Parameter(Mandatory=$true)]
[string] $zipfile )

$f = @(Get-ES1TraceLogs $filespec )
if ($f.count -gt 0)
{
	Compress-FileListToZip $zipfile $f
}
else
{
	Write-Host "No files found to compress"
}

}

<#
.SYNOPSIS
    Compress all logfiles in the SourceOne JobLogs into a single zip file.
.DESCRIPTION
    Compress all logfiles in the SourceOne JobLogs into a single zip file.

.EXAMPLE
   <An example of using the script>
#>
function Compress-ES1JobLogs
{
[CmdletBinding()]
param(
[Parameter(Mandatory=$true)]
[string] $zipfile )

$f = @(Get-ES1JobLogs )
if ($f.count -gt 0)
{
	Compress-FileListToZip $zipfile $f 
}
else
{
	write-output "No files found to compress"
}

}

<#
.SYNOPSIS
   Gets the SourceOne logging trace verbosity level in the Windows registry for the specified component
   on the specified computer.  The component name is the same value as shown in the registry.
   
.DESCRIPTION
   Gets the SourceOne logging trace verbosity level, logging enabled state, and number of log files to keep on disk
   fromm the Windows registry for the specified componenton the specified computer.  The component name is the same
   value as shown in the registry. If Component is not provided info for all component values in the registry are returned.
   
.PARAMETER Computer
	Name of the computer to change the trace settings on
.PARAMETER Component
	Name of the component.  Should be an exact match to the value in the "TraceLogs" registry hive.
	If not provided info for all component values in the registry are returned.

.EXAMPLE
   Get-ES1Trace -Component ES1ObjectViewer

Computer       : IPMWORKER3
Component      : ES1ObjectViewer
TraceVerbosity : 0
Enabled        : 1
Splits         : 10 

.EXAMPLE
   Get-ES1Workers | foreach {$_.servername} | Get-ES1Trace | ft -AutoSize 
   Computer                 Component                       TraceVerbosity Enabled Splits
--------                 ---------                       -------------- ------- ------
IPMARCHIVE2.QAGSXPDC.COM CExNotesInit                                 0       1     10
IPMARCHIVE2.QAGSXPDC.COM CReportManager                               0       1     10
IPMARCHIVE2.QAGSXPDC.COM ES1AddressResolutionService.exe              0       1     10
IPMARCHIVE2.QAGSXPDC.COM ES1DocConverter.exe                          0       1     10
IPMARCHIVE2.QAGSXPDC.COM ES1InPlaceMigService.exe                     4       1     10
IPMARCHIVE2.QAGSXPDC.COM ES1InPlaceMigValidation                      0       1     10
IPMARCHIVE2.QAGSXPDC.COM ExAsAdmin.exe                                0       1     10
IPMARCHIVE2.QAGSXPDC.COM ExAsArchive.exe                              0       1     10
IPMARCHIVE2.QAGSXPDC.COM ExAsIndex.exe                                0       1     10
IPMARCHIVE2.QAGSXPDC.COM exaslock                                     0       1     10
IPMARCHIVE2.QAGSXPDC.COM ExAsQuery.exe                                0       1     10
IPMARCHIVE2.QAGSXPDC.COM ExAsSrch.exe                                 0       1     10
IPMARCHIVE2.QAGSXPDC.COM ExJBJournal.exe                              0       1     10
IPMARCHIVE2.QAGSXPDC.COM ExJBQuery.exe                                0       1     10
IPMARCHIVE2.QAGSXPDC.COM ExJobDispatcher.exe                          0       1     10
IPMARCHIVE2.QAGSXPDC.COM ExJournalJBS.exe                             0       1     10
IPMARCHIVE2.QAGSXPDC.COM System                                       0       1     10
IPMWORKER3.QAGSXPDC.COM  CExNotesInit                                 0       1     10
IPMWORKER3.QAGSXPDC.COM  CReportManager                               0       1     10
IPMWORKER3.QAGSXPDC.COM  ES1AddressResolutionService.exe              0       1     10
IPMWORKER3.QAGSXPDC.COM  ES1InPlaceMigService.exe                     0       1     10
IPMWORKER3.QAGSXPDC.COM  ES1InPlaceMigValidation                      0       1     10
IPMWORKER3.QAGSXPDC.COM  ES1ObjectViewer                              0       1     10
IPMWORKER3.QAGSXPDC.COM  Ex2ES1MigrationCmd                           0       1     10
IPMWORKER3.QAGSXPDC.COM  ExArchiveJBC.exe                             0       1     10
IPMWORKER3.QAGSXPDC.COM  ExArchiveJBS.exe                             0       1     10
IPMWORKER3.QAGSXPDC.COM  ExJBJournal.exe                              0       1     10
IPMWORKER3.QAGSXPDC.COM  ExJobDispatcher.exe                          0       1     10
IPMWORKER3.QAGSXPDC.COM  ExJournalJBS.exe                             0       1     10
IPMWORKER3.QAGSXPDC.COM  ExMMCAdmin.dll                               0       1     10
IPMWORKER3.QAGSXPDC.COM  ExNotesApi.DLL                               0       1     10

#>
function Get-ES1Trace 
{
[CmdletBinding()]
PARAM([Parameter(Mandatory=$false)]
	[string] $Component=$null,
	[Parameter(Mandatory=$false,
		ValueFromPipeLine=$true, 
		ValueFromPipeLineByPropertyName=$true)]
	[string[]]$ComputerArray =$env:COMPUTERNAME)
	

BEGIN {
	$Results=@()
}

PROCESS {

	Write-Host ""

	foreach ($Computer in $ComputerArray )
	{
		$b = get-ES1RegBase
		$b = $b.replace('HKLM:\','')
		$EMCTrace = $b + "\EMC\SourceOne\Tracelogs"
		
		if ($Component -ne $null -and $Component.Length -gt 0)
		{
			$TraceLogKeys = @($Component)
			write-verbose "Command line component name: $($TraceLogKeys)"
		}
		else
		{
			try
			{
				$Reg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine', $Computer)
				if ($Reg)
				{
					$Key = $Reg.OpenSubKey("$EMCTrace",$true)
					$Reg.Close()
				}
			}
			catch 
			{
				write-error "Error accessing registry on $($Computer)"
				return
			}

			if ($Key)
			{
					$TraceLogKeys = @($Key.GetSubKeyNames())
					$Key.Close()
					write-verbose "All subkey names: $($TraceLogKeys)"

			}

		}	

		foreach ($TRentry in $TraceLogKeys)
		{
			$EMCTraceSettings = $EMCTrace + "\$TRentry\Settings"
			write-verbose $EMCTraceSettings
			#$EMCTraceEnable = $EMCTraceSettings + "\Listeners\File"

			try
			{
				$Reg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine', $Computer)
				if ($Reg)
				{
					$Key = $Reg.OpenSubKey("$EMCTraceSettings",$true)

				}
			}
			catch 
			{
				write-error "Error accessing registry on $($Computer)"
				$props = [ordered]@{'Computer'=$Computer;'Component'=$TRentry ;'TraceVerbosity'='NA';'Enabled'='NA'; 'Splits'='NA'}
				$Results += New-object -TypeName PSObject -Prop $props

				continue
			}

			if ($key -ne $null)
			{
				$level = $key.GetValue("TraceVerbosity")
				$key.Close()

				$FileKey = $Reg.OpenSubKey("$EMCTraceSettings\\Listeners\\File",$true)

				if ($FileKey)
				{
					$ON = $FileKey.GetValue("Enabled")
					$split = $FileKey.GetValue("MaxFileSplits")
				
					$props = [ordered]@{'Computer'=$Computer;'Component'=$TRentry ;'TraceVerbosity'=$level;'Enabled'=$ON; 'Splits'=$split}
					$FileKey.Close()

				}
				else
				{
					$props = [ordered]@{'Computer'=$Computer;'Component'=$TRentry ;'TraceVerbosity'=$level;'Enabled'='NA'; 'Splits'='NA'}
				}

			}
			else
			{
				$props = [ordered]@{'Computer'=$Computer;'Component'=$TRentry ;'TraceVerbosity'='NA';'Enabled'='NA'; 'Splits'='NA'}
				write-host "Error reading Trace Setting for $component on  $($Computer)" -ForegroundColor Red
			}
				
			$Results += New-object -TypeName PSObject -Prop $props
		}
		
	}

}  # end PROCESS

END{
	$Results
}

}


Export-ModuleMember -Variable s1InstallDir
Export-ModuleMember -Variable s1JobLogDir
Export-ModuleMember -Variable s1LogDir
Export-ModuleMember -Variable s1servers

Export-ModuleMember -Variable s1archivers
Export-ModuleMember -Variable s1actdb
Export-ModuleMember -Variable s1actServer
Export-moduleMember -Variable s1serverinfoobjects


New-Alias -Name S1Dir -Value Get-ES1InstallDir
New-Alias -Name ES1Dir -Value Get-ES1InstallDir
New-Alias -Name S1Binaries -Value Get-ES1Executables
New-Alias -Name Get-S1Binaries -Value Get-ES1Executables

New-Alias Get-S1RegBase Get-ES1RegBase
New-Alias Get-S1RegEntry Get-ES1RegEntry
New-Alias Get-S1RegLocation Get-ES1RegLocation
New-Alias Get-S1InstallDir Get-ES1InstallDir
New-Alias Get-S1JobLogDir Get-ES1JobLogDir
#New-Alias Set-S1JobLogDir Set-ES1JobLogDir
New-Alias Set-S1ActivityInfo Set-ES1ActivityInfo
New-Alias Get-S1AgentListObjs Get-ES1AgentListObjs 
New-Alias Get-S1AllServerInfoObjects Get-ES1AllServerInfoObjects
New-Alias Get-S1Archivers Get-ES1Archivers
New-Alias Get-S1NAServers Get-ES1NAServers 
New-Alias Get-S1ServerList Get-ES1ServerList 
New-Alias Show-S1Servers Get-ES1ServerList 
New-Alias Show-ES1Servers Get-ES1ServerList 
New-Alias Get-S1Servers Get-ES1Servers 
New-Alias Get-S1ServerSoftwareInfo Get-ES1ServerSoftwareInfo 

New-Alias Show-S1ServerInfo Show-ES1ServerInfo
New-Alias Get-ES1ActivityDB Get-ES1ActivityDatabase

Export-ModuleMember -Function * -Alias *

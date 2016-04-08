<#	
	.NOTES
	===========================================================================
	 Created by:   	jrosenthal
	 Organization: 	EMC Corp.
	 Filename:     	ES1_Configuration.psm1
	
	Copyright (c) 2015 EMC Corporation.  All rights reserved.
	===========================================================================
	THIS CODE AND INFORMATION IS PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND,
	WHETHER EXPRESSED OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE IMPLIED
	WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A PARTICULAR PURPOSE.
	IF THIS CODE AND INFORMATION IS MODIFIED, THE ENTIRE RISK OF USE OR RESULTS IN
	CONNECTION WITH THE USE OF THIS CODE AND INFORMATION REMAINS WITH THE USER. 

	.DESCRIPTION
		Functions for inspecting the SourceOne configuration

#>

#requires -Version 2

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


	Get-ES1ActivityObj | out-null
	$actDbServer = $Script:s1actSErver
	$actDb = $Script:S1Actdb

	#-------------------------------------------------------------------------------
	# Get List of SourceOne Servers
	#-------------------------------------------------------------------------------
	$cServers = @()
	$cServers += $scriptComputerName

	# Get SourceOne Worker Servers
	$dbName = $actDb
	$dbServer = $actDbServer

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
						$props = @{'PSComputerName'=$server;'FileName'=$remoteErr ;'FileVersion'="ERROR"}
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

				}
			}
		}
		catch 
		{
			Write-Warning "Error Reading registry on machine : $server"
			Write-Warning "Make sure the machine is up and reachable on the network"
			$props = @{'PSComputerName'=$server;'FileName'=$_.Exception.Message ;'FileVersion'="NA"}
			$AllBinaries += New-object -TypeName PSObject -Prop $props

			continue
		} 

	} 

	$AllBinaries | select-object PSComputerName, FileName, FileVersion | Format-Table -AutoSize #| Out-String -Width 10000
}
end{}

}


function Get-ES1InstallDir
{
<#
.SYNOPSIS
 Returns a string containing the S1 install directory from the machine specified (defaults to current machine)
.DESCRIPTION
Returns a string containing the S1 install directory from the machine specified
The Value is retrieved from the machine registry.
.PARAMETER server
server or host Name to get the S1 install directory from

.OUTPUTS
set Session variable $S1InstallDir
.EXAMPLE Show the folder
Get-ES1InstallDir
D:\Program Files\EMC SourceOne
.EXAMPLE update $S1InstallDir
Get-ES1InstallDir | out-null
D:\Program Files\EMC SourceOne

#>
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
$s1Workers = @()
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
   <A brief description of the script>
.DESCRIPTION
   <A detailed description of the script>
.PARAMETER <paramName>
   <Description of script parameter>
.EXAMPLE
   <An example of using the script>
#>
function Get-ES1RegBase
{
 [CmdletBinding()]
param()
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
function Get-ES1RegEntry
 {
	[CmdletBinding()]
	param()
	Get-ES1RegBase | out-null
	if ($Script:emcRegEntry -eq '')
	{
		$Script:emcRegEntry = $script:S1RegBase + "\EMC\SourceOne\"


	}
	$s1R = $Script:emcRegEntry.Replace("HKLM:","HKEY_LOCAL_MACHINE")
	$s1R = "Registry::" + $s1R 

	$Script:emcRegEntry
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
   <A brief description of the script>
.DESCRIPTION
   <A detailed description of the script>
.PARAMETER <paramName>
   <Description of script parameter>
.EXAMPLE
   <An example of using the script>
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
.OUTPUT
 Set Session variable $s1JobLogDir
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
				Write-output "Job share location is not valid"
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
function Set-ES1JobLogDir 
{
	[CmdletBinding()]
	param(
		[Parameter(Mandatory=$true)]
		[string] $loc)
	if (Test-Path $loc) 
	{
		$Script:s1JobLogDir = $loc
	}
	else
	{
		Write-Output "$loc is not a valid path"
	}

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
function Set-ES1ActivityInfo
{
 [CmdletBinding()]
param(
	[Parameter(Mandatory=$true)]
	[string] $SQLserver,
	[Parameter(Mandatory=$true)]
	[string]$ActivityDb)

$script:s1ActServer = $SQLserver
$script:s1actDb = $ActivityDb

$script:s1ActInfo = @{'ActivityServer'=$script:S1ActServer;'ActivityDb'=$script:s1ActDb}
$script:s1ActObject = New-Object -TypeName psobject -Property $s1ActInfo
$script:s1ActObject
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
#-------------------------------------------------------------------------------
# Get Activity Database
#-------------------------------------------------------------------------------
function Get-ES1ActivityObj
{
<#
.SYNOPSIS
 Get-ES1ActivityObj 
.DESCRIPTION
This function will retreive the SourceOne SQL server and activity DB Name into
the variables $s1ActServer and $s1actDb.>
.PARAMETER <Force>
<the Force parameter will cause values to be updated/refreshed>
.EXAMPLE
Get-ES1ActivityObj

SQL01
ES1Activity

.OUTPUT

.EXAMPLE
Get-ES1ActivityObj -force

SQL01
ES1Activity

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
		$s1RegVersion = $s1R + "versions"

		$script:s1ActServer = (Get-ItemProperty -Path $s1R).Server_JDF
		$script:s1actDb = (Get-ItemProperty -Path $s1R).DB_JDF

		if ($script:s1ActServer -eq $null)
		{
			$script:s1ActServer = Read-Host "Information cannot be retrieved from the registry, enter the name of the SourceOne SQL server"
			$script:s1ActDb = Read-Host "enter the name of the SourceOne Activity Database"
		}

		$script:s1ActInfo = @{'ActivityServer'=$script:S1ActServer;'ActivityDb'=$script:s1ActDb}
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
   Get-ES1Workers
.DESCRIPTION
   Retrieve the names of all SourceOne workers from SQL
.OUTPUT
Sets Session array $s1Workers
.EXAMPLE
   Get-ES1WorkersV2
   
   Master.domain.com
   Worker.domain.com
#>
#-------------------------------------------------------------------------------
# Function:  Get-ES1Workers
#-------------------------------------------------------------------------------
function Get-ES1Workers
{
 [CmdletBinding()]
param()
Get-ES1ActivityObj | out-null

#
# Define SQL Query
#
$sqlQuery = @'
SELECT DISTINCT NetworkName AS servername, workerid 
FROM MachineInfo mi (NOLOCK)      
JOIN Workers w (NOLOCK) ON w.MachineID = mi.MachineID
WHERE w.State <> 32767
'@

$dtResults = Invoke-ES1SQLQuery $Script:s1actSErver $Script:S1Actdb $sqlQuery
$Script:s1Workers = $dtResults
$dtResults

}
<#
.SYNOPSIS
   Get-ES1WorkerNameFromID
.DESCRIPTION
   Given a workerID display the name of the worker server
   Used by S1Jobs etc when retrieving Job information
.PARAMETER sID
   Provide the workerid 
.EXAMPLE
   Get-ES1WorkerNameFromID 2
   
   Worker01
#>
function Get-ES1WorkerNameFromID 
{
	param ($wId)

	Get-ES1Workers | out-null
	foreach ($w in $Script:s1Workers)
	{
		if ($w.workerid -eq $wID)
		{
			$name = $w.servername.Split(".")[0]
		}
	}

	$name
}


<#
.SYNOPSIS
  Get-ES1Archivers
.DESCRIPTION
  Retrieve information from SQL about SourceOne Archive servers
.OUTPUT
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
# Get Archive Databases
#-------------------------------------------------------------------------------
Get-ES1ActivityObj | out-null

$sqlQuery = @'
Select Name AS Connection,
       xConfig.value('(/ExASProviderConfig/DBServer)[1]','nvarchar(max)') AS DBServer,
       xConfig.value('(/ExASProviderConfig/DBName)[1]','nvarchar(max)') AS DBName
From ProviderConfig (nolock)
Where ProviderTypeID <> 5 AND State = 1    
'@

$dtConnections = Invoke-ES1SQLQuery $Script:s1actSErver $Script:S1Actdb $sqlQuery


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
   <A brief description of the script>
.DESCRIPTION
   <A detailed description of the script>
.PARAMETER <paramName>
   <Description of script parameter>
.EXAMPLE
   <An example of using the script>
#>
function Get-ES1ServerList
{
 [CmdletBinding()]
param()
$serverList = @()

Write-verbose $Script:s1Archivers.count

if ($Script:s1Archivers.count -eq 0)
{
	$Script:s1Archivers = Get-ES1Archivers
}

Write-verbose $Script:s1Archivers.count
foreach ($server in $Script:s1Archivers)
{
	Write-Verbose $server
	$props = @{computername=$server}
	$obj = New-Object -TypeName psobject -Property $props
	$serverList += $obj
}

Write-Verbose $Script:s1workers.count
if ($Script:s1Workers.count -eq 0)
{
	$Script:s1Workers = Get-ES1Workers
}


foreach ($s in $Script:s1Workers)
{

	$server = $s.servername.tostring()
	Write-Verbose $s
	$parts = $server.split('.')
	$props = @{computername=$parts[0]}
	$obj = New-Object -TypeName psobject -Property $props
	$serverList += $obj

}

write-verbose $serverlist.ToString()
$Script:s1serverList = $serverList | Select-Object computername -uniq 
$Script:s1serverList

} 

<#
.SYNOPSIS
   Get-ES1Servers
.DESCRIPTION
   Retrieve a list/array of all SourceOne servers (workers and archivers)
.OUTPUT
  sets session array $s1Servers
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
.OUTPUT
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
$entry = $b + "\Microsoft\WIndows\CurrentVersion\Uninstall"
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

						$swInfo = @{'DisplayName'=$dname;'Version'=$dvers;'AgentName'=$agentname}
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
   <A brief description of the script>
.DESCRIPTION
   <A detailed description of the script>
.PARAMETER <paramName>
   <Description of script parameter>
.EXAMPLE
   <An example of using the script>
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

		$mainprops = @{servername=$comp;
			Software = $swObjects;
			Services = $srvObjects}
		$mainobject = New-Object -Type psobject -Property $mainprops
		Write-Verbose $mainobject
		$Script:s1ServerInfoObjects += $mainobject
	}
	catch
	{

	}

}


$Script:s1ServerInfoObjects
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
   <A brief description of the script>
.DESCRIPTION
   <A detailed description of the script>
.PARAMETER <paramName>
   <Description of script parameter>
.EXAMPLE
   <An example of using the script>
#>
function Get-ES1AgentListObjs
{
[CmdletBinding()]
param
()
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

	$installInfo = @{'MachineName'=$mname;'Role'=$RoleStr}
	$installObj = New-Object -TypeName psobject -Property $installInfo
	$Script:s1InstallObjects += $installObj

}
$Script:s1InstallObjects

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
function Set-ES1Trace 
{
	[CmdletBinding()]
	param
	(		[string] $component, [string] $level = 4,$split = 10,[switch] $disable,$Computer = $env:COMPUTERNAME )
	$ON = '1'
	if ($disable) {$ON = '0'}


	$b = get-ES1RegBase
	$b = $b.replace('HKLM:\','')
	$entry = $b + "\EMC\SourceOne\Tracelogs"

	if ($component -ne $null)
	{
		$EMCTraceSettings = $entry + "\$component\Settings"
		write-verbose $EMCTraceSettings
		$EMCTraceEnable = $EMCTraceSettings + "\Listeners\File"


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
			write-error "Error accessing registry "
			return
		}

		if ($key -ne $null)
		{

			if ($level.length -gt 0)
			{
				$x = $key.GetValue("TraceVerbosity")
				if ($level -ge 0 -and $level -lt 8)
				{

					$key.SetValue("TraceVerbosity",$level,[Microsoft.Win32.RegistryValueKind]::DWORD) 
					write-host "Modified tracesetting for $component from $x to $level"
				}
				else
				{
					write-host level must be between 0 and 7

				}
			}
			#ensure that MaxFileSplits are set and Tracing is enabled.
			$FileKey = $Reg.OpenSubKey("$EMCTraceSettings\\Listeners\\File",$true)
			if ($FileKey)
			{
				$FileKey.SetValue("Enabled",$ON,[Microsoft.Win32.RegistryValueKind]::DWORD) 
				$FileKey.SetValue("MaxFileSplits",$split,[Microsoft.Win32.RegistryValueKind]::DWORD) 

				WRite-Host "Logging Enabled = $ON, Max File Spilts set to $split"
			}

		}
		else
		{

			write-host "Error reading Trace Setting for $component"
		}

	}





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
function Set-ES1ResetTraceAll 
{
	[CmdletBinding()]
	param
	(		[string] $level = 0,$split = 10,[switch] $disable,$Computer = $env:COMPUTERNAME )
	$ON = '1'
	if ($disable) {$ON = '0'}

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
		write-error "Error accessing registry "
		return
	}
	if ($key)
	{

		$TraceLogKeys = @($key.GetSubKeyNames())
		foreach ($entry in $TraceLogKeys)
		{

			Set-ES1Trace -component $entry -level $level 

		}

	}
	else
	{
		write-host "No trace setting found"

	}

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
function Remove-AgedFiles
{
[CmdletBinding()]
param($tfile,$days = 0)

write-verbose $tfile

$age = @{Name='Age';Expression={($_ | new-timespan).days}}

$x = @(gci $tfile | Select-Object -Property Name,FullName,$age)
write-verbose $x.count

for ($i = 0; $i -lt $x.count; $i++)
{
	$a = $x[$i].age
	write-verbose "age of file is $a days"

	if ($x[$i].age -ge $days)
	{
		$f = $x[$i].fullname
		write-output "Removing file $f"
		try
		{
			$f
			remove-item $f -force -errorvariable err -erroraction silentlycontinue
		}
		catch
		{
			write-verbose "exception Removing file $f"
		}

		if ($err.count -eq 0 )
		{

			Write-Output "deleted  $f"
		}

	}
}

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
function Remove-ES1TraceLogs
{
[CmdletBinding()]
param($fileSpec,$days = 0)

if ($fileSpec -ne $null)
{

	$eLoc = Get-ES1InstallFolders
	$eLog = $eLoc + "logs\"
	$eLogSpec = $eLog + $fileSpec
	gci $eLogSpec

	Remove-AgedFiles $eLogSpec $days

}
else
{
	write-host "specify a file spec"
}

}

$s1InstallDir = ''
$s1LogDir = ''

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
function Show-ES1TraceLogs
{
[CmdletBinding()]
param($fileSpec)

$eLoc = Get-ES1InstallFolders
$eLog = $eLoc + "logs\"
$Script:S1LogDIr = $eLog
$eLogSpec = $eLog + $fileSpec
gci $eLogSpec -ErrorAction SilentlyContinue



}


$WaitZipTime = 1

<#
.SYNOPSIS
   Compress-FileListToZip
.DESCRIPTION
compress a list of files into the named zip
.PARAMETER zipspec
   list of files to zip 
.PARAMETER filespec
   name of the zip file to create/update
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

	

	if ($zipspec -notmatch ':')
	{
		$loc = Get-Location
		$zipname = $loc.ToString() + "\$zipspec"
	}
	else
	{
		$zipname = $zipspec
	}

	if (-not $zipname.EndsWith('.zip')) {$zipname += '.zip'} 

	if (-not (test-path $zipname)) { 
		set-content $zipname ("PK" + [char]5 + [char]6 + ("$([char]0)" * 18)) 
	} 
	else
	{
		Write-Verbose "adding to current zip file"
	}

	$ZipFile = (new-object -com shell.application).NameSpace($zipname) 
	if ($ZipFile -ne $null)
	{


		foreach ($c in $filelist)
		{
			write-output $c

			$ZipFile.CopyHere($c)
			# CopyHere is Asynchronous, need to wait before adding another....
			Sleep -Seconds $WaitZipTime

		}

	}
	else
	{
		Write-Output "unable to create NameSpace for $zipfile"
	}

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
function Expand-ZipFile
{
[CmdletBinding()]
param($zipspec, $destination,[switch] $overwrite)


if (!(Test-Path $destination))
{
	mkdir $destination
}

$zipfile = (gci $zipspec).fullname

if (!(Test-Path $zipfile))
{
	Write-Output "$zipfile does not exit"
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
   <A brief description of the script>
.DESCRIPTION
   <A detailed description of the script>
.PARAMETER <paramName>
   <Description of script parameter>
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

$f = @(show-ES1TraceLogs $filespec )
if ($f.count -gt 0)
{
	Compress-FileListToZip $zipfile $f -verbose
}
else
{
	write-output "No files found to compress"
}

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
function Compress-ES1JobLogs
{
[CmdletBinding()]
param(
 [Parameter(Mandatory=$true)] 
[string] $filespec,
[Parameter(Mandatory=$true)]
[string] $zipfile )

$f = @(show-ES1JobLogs $filespec )
if ($f.count -gt 0)
{
	Compress-FileListToZip $zipfile $f -verbose
}
else
{
	write-output "No files found to compress"
}

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

function Get-RecentCommands
{
 #usefull for creating new scripts from commands in session
Get-History | Select-Object commandline
}

function Show-ES1Archivers {
	<#
.SYNOPSIS
	Display a list of SourceOne Archive machines and their enabled roles
	
.DESCRIPTION
	Display a list of SourceOne Archive machines and their enabled roles
	
.EXAMPLE
	Show-ES1Archivers

Number of Archives: 3

ArchiveName ServerName                RolesValue Enabled Roles
----------- ----------                ---------- -------------
Archive1    s1Master7-J1.qagsxpdc.com         15 {Archive, Index, Query, Retrieval}
IPMArchive  IPMWorker02.qagsxpdc.com          14 {Index, Query, Retrieval}
SecondIPM   IPMArchive2.qagsxpdc.com          14 {Index, Query, Retrieval}

#>
	[CmdletBinding()]
	param( )

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

		$ASRepos = $asmgr.EnumerateRepositories()

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


$global:RoleDisplayNames = @{}

#
# Hard coded worker role display names in case not on machine with modules to get strings from...
#  The key is the taskTypeID 
$displayNames = @{
	-1846448278 = "File Delete - Historical";
	-1788567307 = "File Archive - Historical";
	-1275657296 = "File Index in Place - Historical";
	-623249162 = "File Shortcut - Historical";
	-1373822617 = "File Removal";
	45 = "SharePoint Restore";
	44 = "File Restore";
	1818414846 = "File Restore - Historical";
	42 = "Restore Shortcuts - Microsoft Exchange Public Folders";
	40 = "Delete - Microsoft Exchange Public Folders";
	38 = "Shortcut - Microsoft Exchange Public Folders";
	36 = "Archive - Microsoft Exchange Public Folders";
	34 = "Delete - User Initiated Delete";
	32 = "Restore Shortcuts - Historical & User Directed Archive";
	31 = "Query Discovery Manager";
	28 = "Find - Microsoft Office Outlook .PST";
	26 = "Delete - User Directed Archive";
	24 = "Shortcut - User Directed Archive";
	22 = "Archive - User Directed Archive";
	21 = "Delete";
	19 = "Migrate - Microsoft Office Outlook .PST";
	18 = "Update Shortcuts - Historical & User Directed Archive";
	17 = "Export";
	16 = "Journal";
	15 = "Archive - Personal Mail Files";
	1888230777 = "File Shortcut Restore - Historical";
	8 = "Query";
	6 = "Export Discovery Manager";
	5 = "Delete - Historical";
	4 = "Shortcut - Historical";
	3 = "Archive - Historical"}

# used for dynamic rebuild of table above.  These strings from rooted from ExJDFEnums.Translate()
$NoKnownConfigurators = @{
	45 = "SharePoint Restore";
	44 = "File Restore";
	31 = "Query Discovery Manager";
	21 = "Delete";
	17 = "Export";
	8 = "Query";
	6 = "Export Discovery Manager";

}
function Set-WorkerRoleDisplayNames {
	<#
.SYNOPSIS
	Loads a global hash map with the tasktypeid and UI displayable worker role name associated with it.
	A static copy of the map is used if this is not run on a machine with the S1 console installed.
	This function is used internally by other functions/commands and is generally not executed from the 
	command line.
.DESCRIPTION
	Loads a global hash map with the tasktypeid and UI displayable worker role name associated with it.
	A static copy of the map is used if this is not run on a machine with the S1 console installed.
	This function is used internally by other functions/commands and is generally not executed from the 
	command line.
.PARAMETER outfile
	Option parameter to specify an output file that will capture the hash map of task type ID and the 
	display name that was discovered.
.EXAMPLE
	Set-WorkerRoleDisplayNames

.EXAMPLE
	Set-WorkerRoleDisplayNames -debug
.EXAMPLE
	Set-WorkerRoleDisplayNames -out file.csv

#>
	[CmdletBinding()]
	param ( [Parameter(Mandatory=$false)]
		[Alias('out')]
		[string]$outfile = "" )
	begin {

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

		if ($MyDebug)
		{
			Write-Debug "Emptying RoleDisplayNames map ..."
			$global:RoleDisplayNames.Clear()
		}

		#
		# Some logic lifted from GetServerAssignments in "ExServerConfigCtrl.cs"
		#
		$jdfapiMgr = new-object -comobject ExJDFAPI.CoExJDFAPIMgr.1

		$TaskTypeFilter = $jdfapiMgr.CreateNewObject([EMC.Interop.ExJDFAPI.exJDFObjectType]::exJDFObjectType_TaskTypeFilter)

		$tasktypes = $jdfapiMgr.GetTaskTypes($TaskTypeFilter)
		[System.Runtime.Interopservices.Marshal]::ReleaseComObject($TaskTypeFilter) > $null

		# gets the Mail systems supported... :-)
		#$generalSettings=$jdfapiMgr.GetSystemGeneralSettings()
		#$generalSettings

		# $tasktypes  | ft -AutoSize | Out-String -Width 100000 > foo
		$installPath = Get-ES1InstallDir

		#
		#  These modules will only be on machine with the worker services installed.
		#
		$pathroot = $installPath +'Console\bin\'
		$ExUIDLL = $pathroot + "ExUIUtils.dll"

		if (Test-Path -path $pathroot)
		{
			# We load this because the "Files" components have a dependency on it and the creation
			#   of their configruation object will fail if this isn't already loaded
			$ExUI = [reflection.assembly]::LoadFrom($ExUIDLL)

			#
			# if on a machine with Console, load all the strings from the installed task types..
			#
			foreach ($tasktype in $TaskTypes)
			{
				if ((($taskType.state -band [int][EMC.Interop.ExBase.exPluginState]::exPluginState_Active) -and ` #Only Active types
						(							(								$taskType.state -band [int][EMC.Interop.ExBase.exPluginState]::exPluginState_NotAdminDisplayable) -eq $false)) -or ` # hide internal types
					(						[int][EMC.Interop.ExBase.exCoreTaskTypes]::exCoreTaskTypes_Query -eq $taskType.id ) -or `
					(						[int][EMC.Interop.ExBase.exCoreTaskTypes]::exCoreTaskTypes_RestoreJBC -eq $taskType.id ) -or `
					(						[int][EMC.Interop.ExBase.exCoreTaskTypes]::exCoreTaskTypes_DeleteFromArchiveJBC -eq $taskType.id ) -or `
					(						[int][EMC.Interop.ExBase.exCoreTaskTypes]::exCoreTaskTypes_DCQuery -eq $taskType.id ) -or `
					(						[int][EMC.Interop.ExBase.exCoreTaskTypes]::exCoreTaskTypes_Restoration -eq $taskType.id ) -or `
					(						[int][EMC.Interop.ExBase.exCoreTaskTypes]::exCoreTaskTypes_FileRestoreJBC-eq $taskType.id ) -or `
					(						[int][EMC.Interop.ExBase.exCoreTaskTypes]::exCoreTaskTypes_SharePointRestoreJBC -eq $taskType.id ) 
				)

				{

					if ($tasktype.configuratorModuleWin32.Length -gt 0)
					{
						#Write-Host $tasktype.id $tasktype.name $tasktype.objectID $tasktype.configuratorModuleWin32 $tasktype.configuratorObjectIDWin32
						$path = $pathroot + $tasktype.configuratorModuleWin32

						try
						{
							$Name = ""
							$Description = ""

							#assembly name comes from the taskType object returned by GetTask
							$assemblyUI = [reflection.assembly]::LoadFrom($path)
							Write-Debug "$($tasktype.name), cfg Module: $($tasktype.configuratorModuleWin32) cfg ObjectID: $($tasktype.configuratorObjectIDWin32)"

							$UIMgr = $assemblyUI.CreateInstance($tasktype.configuratorObjectIDWin32)

							$UIMgr.GetTypeDisplayName($tasktype.id,[ref]$Name,[ref]$Description)
						}
						catch
						{
							Write-Warning "Failed to load configurator and create object $($tasktype.id) $($tasktype.name)"
							Write-Error $_
						}

						if ($Name.Length -eq 0)
						{
							Write-Host "No display name for: $($tasktype.id) $($tasktype.name) "
							$global:RoleDisplayNames.Add($tasktype.id,$tasktype.name)
						}
						else
						{
							#Write-Host "Got display name for: $($tasktype.id) $($tasktype.name) Display Name: $($Name) "
							#       Write-Host "Got display name for: $($tasktype.id), Display Name: $($Name) "
							$global:RoleDisplayNames.Add($tasktype.id,$Name)
						}

						#  Think I need to free the object but cant find the right way.
						#[System.Runtime.Interopservices.Marshal]::Release($UIMgr)  > $null


					}
					else
					{
						# no configurator so see if there is a known string to use...

						if ($NoKnownConfigurators.ContainsKey($tasktype.id))
						{
							$NameStr = $NoKnownConfigurators.Get_Item($tasktype.id)
							$global:RoleDisplayNames.Add($tasktype.id,$NameStr)
							Write-Debug "Known string for: $($tasktype.id) $($NameStr)"
						}
						else
						{
							Write-Debug "No configurator: $($tasktype.id) $($tasktype.name), using type name "
							$global:RoleDisplayNames.Add($tasktype.id,$tasktype.name)
						}

					}
				}

			} #end foreach

			# preserve the display names to CSV
			# the CSV can be messaged and used to update the static table...
			if ($outfile.Length -gt 0)
			{
				$global:RoleDisplayNames.GetEnumerator() | select Name, Value | Export-Csv -notype -path $outfile
			}

		}
		else
		{
			# Console\bin dir doesn't exist...
			$global:RoleDisplayNames = $displayNames

		}

	}

	end {}

}

function Get-ES1EnabledWorkerRoles {
	<#
.SYNOPSIS
	Given a list of taskcfg objects (IExWorkerTaskConfig) obtained from a worker (IExWorker) object, 
	return a list of the active types/roles and their UI displayable names

.DESCRIPTION
	Given a list of taskcfg objects (IExWorkerTaskConfig) obtained from a worker (IExWorker) object, 
	return a list of the active types/roles and their UI displayable names

.EXAMPLE

The following snippet displays the active role types and display names string on each worker

		$jdfapiMgr=new-object -comobject ExJDFAPI.CoExJDFAPIMgr.1

		$Workers=@($jdfapiMgr.GetWorkers())
		foreach ($worker in $Workers)
		{
			$allcfgs = @($worker.taskCfgs)
			$Activecfgs = @(Get-ES1EnabledWorkerRoles $allcfgs)
			$Activecfgs
		}
#>
	[CmdletBinding()]
	param ([Parameter(Mandatory=$true)]
		[Alias('cfgs')]
		$list = @())

	#
	# logic lifted from GetServerAssignments in "ExServerConfigCtrl.cs"
	#

	$retList = @()

	Write-Verbose "SeverRoles for display:  $($global:RoleDisplayNames.Count)"

	foreach ($cfg in $list)
	{

		if ($cfg.state -eq [int][EMC.Interop.ExJDFAPI.exJDFWorkerTaskCfgState]::exJDFWorkerTaskCfgState_Enabled)
		{
			# $global:RoleDisplayNames contains only UI displayable taskids, if its not there is doesn't get
			# returned
			if ($global:RoleDisplayNames.ContainsKey($cfg.taskTypeId))
			{
				$cfg.taskTypeName=$global:RoleDisplayNames.Get_Item($cfg.taskTypeId)
				$retList += $cfg

			}

		}

	}

	$retList

}

function Show-ES1WorkerRoles {
	<#
.SYNOPSIS
	Display information about each worker server and it's enabled roles
.DESCRIPTION
	Display information about each worker server and it's enabled roles
.EXAMPLE
	Show-ES1WorkerRoles

******  Worker : S1MASTER7-J1.QAGSXPDC.COM ******

Group State   Action StartTime            LastActive            JobQuota JobPollTime DaysAvailable
----- -----   ------ ---------            ----------            -------- ----------- -------------
      Working None   7/17/2014 7:27:06 PM 11/11/2015 9:57:56 PM        0          10            -1


Enabled Roles                                          JobLimit
-------------                                          --------
Archive - Historical                                          4
Archive - Personal Mail Files                                 2
Delete                                                        4
Delete - Historical                                           4
Delete - Microsoft Exchange Public Folders                    4
Delete - User Directed Archive                                4
Delete - User Initiated Delete                                4

.EXAMPLE
	Show-ES1WorkerRoles > WorkerRoles.txt

	Captures the worker role information to a text file named WorkerRoles.txt
#>
	[CmdletBinding()]
	param ()
	begin {
		try {
			[bool] $loaded = Add-ES1Types #-ErrorAction SilentlyContinue

			if (-not $loaded )
			{
				Write-Error 'Error loading SourceOne Objects and Types'
				break
			}

			# Load up the display names....
			if ($global:RoleDisplayNames.Count -le 0)
			{
				Set-WorkerRoleDisplayNames
			}
		}
		catch
		{
			Write-Error $_ 
			break
		}
	}

	process{

		$Workers = @()

		$jdfapiMgr = new-object -comobject ExJDFAPI.CoExJDFAPIMgr.1

		$workergroups = @($jdfapiMgr.GetWorkerGroups())
		$Workers = @($jdfapiMgr.GetWorkers())

		# Add some new columns
		$Workers | Add-Member NoteProperty -Name "WorkerGroup" -Value ""

		$Rolefmt = @{ Expression = { $_.taskTypeName }; label = "Enabled Roles" },
		@{ Expression = { $_.quota }; label = "JobLimit" } 

		#@{ Expression = { $_.name }; label = "Worker" },
		$Workerfmt = @{ Expression = { $_.WorkerGroup }; label = "Group"},
		@{ Expression = { ([EMC.Interop.ExJDFAPI.exJDFWorkerState]$_.state).ToString().Substring(17) }; label = "State"; width=12 },
		@{ Expression = { ([EMC.Interop.ExJDFAPI.exJDFWorkerAction]$_.action).ToString().Substring(18) }; label = "Action" },
		@{ Expression = { $_.startTime }; label = "StartTime" },
		@{ Expression = { $_.lastActive }; label = "LastActive" },
		@{ Expression = { $_.jobQuota }; label = "JobQuota" },
		@{ Expression = { $_.jobPollTime }; label = "JobPollTime" },
		@{ Expression = { $_.daysAvailable }; label = "DaysAvailable" }

		# Add the Worker Group if there is one... 
		foreach ($worker in $Workers)
		{
			if ($workergroups.Length -gt 0)
			{
				foreach ($group in $workergroups)
				{
					if ($group.id -eq $worker.workerGroupID)
					{
						$worker.WorkerGroup = $group.name
						break;
					}
				}
			}

			# Display the Worker information
			Write-Output "******  Worker : $($worker.name) ******"
			$worker | ft -AutoSize $Workerfmt | Out-String -Width 1000

			$cfgs = @()
			$tasks = @()

			$cfgs = @($worker.taskCfgs)
			$allCfgs = @($worker.taskCfgs)

			$cfgs = @(Get-ES1EnabledWorkerRoles $cfgs)
			$cfgIndex = 0
			#
			# Adjust the joblimit/quota to display like the GUI does.
			#   some logic lifter from "PopulateGrid" in ExWorkerTaskCfgPage.cs
			foreach ($cfg in $cfgs)
			{
				# First thing to do is determine whether this is a job-level task (JBC).  If
				#    it's not, we'll use it to get to associated jobs that are...

				$childFilter = $jdfapiMgr.CreateNewObject([EMC.Interop.ExJDFAPI.exJDFObjectType]::exJDFObjectType_TaskTypeFilter)
				$childFilter.parentTaskTypeID = $cfg.id
				$childTaskTypes = @($jdfapiMgr.GetTaskTypes($childFilter))
				[System.Runtime.Interopservices.Marshal]::ReleaseComObject($childFilter) > $null

				$useThis = $cfg

				#  Use the first child type if we got one...
				if ($childTaskTypes.Length -gt 0)
				{
					$useThis = $childTaskTypes[0]
				} 

				# Look for the current type in the workers full collection
				foreach ($parent in $allCfgs)
				{
					#
					# Note, there is some hairy logic in Populate grid, but I think this
					#   gets the job done...
					#
					if ($parent.taskTypeID -eq $useThis.id)
					{
						$cfgs[$cfgIndex].quota = $parent.quota
						Write-Debug "Config ID $($cfg.id) Quota: $($cfg.quota) New: $($parent.quota)"
					}
				}
				$cfgIndex++

			}

			# And display the Roles....
			$cfgs | sort taskTypeName | ft -AutoSize $Rolefmt
		}
	}

	end {}


}



Export-ModuleMember -Variable s1InstallDir
Export-ModuleMember -Variable s1JobLogDir
Export-ModuleMember -Variable s1LogDir
Export-ModuleMember -Variable s1servers
Export-ModuleMember -Variable s1workers
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
New-Alias Set-S1JobLogDir Set-ES1JobLogDir
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
New-Alias Get-S1WorkerNameFromID Get-ES1WorkerNameFromID
New-Alias Get-S1Workers Get-ES1Workers
New-Alias Show-S1ServerInfo Show-ES1ServerInfo
New-Alias Get-S1ActivityObj Get-ES1ActivityObj

Export-ModuleMember -Function * -Alias *
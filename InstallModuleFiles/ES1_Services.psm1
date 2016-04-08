<#	
	.NOTES
	===========================================================================
	 Created by:   	jrosenthal
	 Organization: 	EMC Corp.
	 Filename:     	ES1_Services.psm1
	
	Copyright (c) 2015 EMC Corporation.  All rights reserved.
	===========================================================================
	THIS CODE AND INFORMATION IS PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND,
	WHETHER EXPRESSED OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE IMPLIED
	WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A PARTICULAR PURPOSE.
	IF THIS CODE AND INFORMATION IS MODIFIED, THE ENTIRE RISK OF USE OR RESULTS IN
	CONNECTION WITH THE USE OF THIS CODE AND INFORMATION REMAINS WITH THE USER. 

	.DESCRIPTION
		Functions for managing SourceOne Services

#>

#requires -Version 2

$SvcShow = 1
$SvcStart = 2
$SvcStop = 3
$svcRestart = 4
$svcPause = 5
$svcResume = 6
$WaitTime = '00:00:05'
$WaitSeconds = 50


function Get-ES1Services
{
<#
.SYNOPSIS
 Get-ES1Services
.DESCRIPTION
Get a list of SourceOne Services on the specified Server(s)
.PARAMETER <ComputerName>
Specifies the computer against which you want to run the management operation. The Value can be a fully qualified domain Name, a NetBIOS Name, or an IP address. Use the local computer Name, use localhost, or use a dot (.) to specify the local computer
. The local computer is the default. When the remote computer is in a different domain from the user, you must use a fully qualified domain Name. This parameter can also be piped to the cmdlet.
.PARAMETER <Credential>
Specifies a user account that has permission to perform this action. The default is the current user. Type a user Name, such as "User01", "Domain01\User01", or user@Contoso.com. Or, enter a PSCredential object, such as an object that is returned by th
e Get-Credential cmdlet. When you Type a user Name, you will be prompted for a Password.
.EXAMPLE
Get-ES1Services 

Status Name DisplayName
------ ---- -----------
Running ES1AddressResol... EMC SourceOne Address Resolution
Running ES1InPlaceMigSe... EMC SourceOne Inplace Migration
Running ExJobDispatcher EMC SourceOne Job Dispatcher

#>
[CmdletBinding()]
param
(
	[Parameter(
		ValueFromPipeLine=$true, 
		ValueFromPipeLineByPropertyName=$true)]
	[string[]]$ComputerName = $env:computername,
	$Credential = $remCreds

)
$es1Services = @()

#
# Process each machine one at a time so we can handle the errors nicely...
#   
foreach($computer in $ComputerName)
{
	try
	{
		$es1Services += get-service -displayname '*emc sourceone*' -ComputerName $computer -ErrorAction SilentlyContinue -ErrorVariable gserror 
	}
	catch
	{
		Write-Host "Error accessing server: $($computer). Make sure the machine is up and reachable" -ForegroundColor Red
		Write-Host $gserror.Message -ForegroundColor Red

		# create a fake object to return so all machines are in the list
		$errobj = New-Object System.ServiceProcess.ServiceController
		$errobj.MachineName = $computer
		# $errobj.ServiceName="ERROR"
		$errobj.DisplayName="ERROR accessing server !"
		$es1Services +=$errobj
	}
}


$es1Services 

}

function Show-ES1Services
{
<#
.SYNOPSIS
 Show-ES1Services
.DESCRIPTION
Displays a list of SourceOne Services on the specified Server(s)
.PARAMETER <ComputerName>
Specifies the computer against which you want to run the management operation. The Value can be a fully qualified domain Name, a NetBIOS Name, or an IP address. Use the local computer Name, use localhost, or use a dot (.) to specify the local computer
. The local computer is the default. When the remote computer is in a different domain from the user, you must use a fully qualified domain Name. This parameter can also be piped to the cmdlet.
.PARAMETER <Credential>
Specifies a user account that has permission to perform this action. The default is the current user. Type a user Name, such as "User01", "Domain01\User01", or user@Contoso.com. Or, enter a PSCredential object, such as an object that is returned by th
e Get-Credential cmdlet. When you Type a user Name, you will be prompted for a Password.
.EXAMPLE
Show-ES1Services

displayname Name State systemname
----------- ---- ----- ----------
EMC SourceOne Address Resolution ES1AddressResolutionService Running IPMWORKER3
EMC SourceOne Inplace Migration ES1InPlaceMigService Running IPMWORKER3
EMC SourceOne Job Dispatcher ExJobDispatcher Running IPMWORKER3

#>
[CmdletBinding()]
param
(
	[Parameter(
		ValueFromPipeLine=$true, 
		ValueFromPipeLineByPropertyName=$true)]
	[string[]]$ComputerName = $env:computername,
	$Credential = $remCreds

)

try {
	$machineServices = Get-ES1Services $ComputerName $Credential
	$machineServices| sort machinename | select-object DisplayName,Name,MachineName,Status | Format-Table -AutoSize #| Out-String -Width 10000
}
catch 
{

}

}


function Set-ES1WaitTimeforServices 
{
	<#
.SYNOPSIS
   Set-ES1WaitTimeforServices 
.DESCRIPTION
   Update variable $WaitSeconds used to manage services
.PARAMETER seconds
   provide the number of seconds between 1 and 60
.EXAMPLE
   <An example of using the script>
#>
	[CmdletBinding()]
	param
	(

		[int] $seconds

	)
	if ($seconds -ge 0 -and $seconds -le 60)
	{
		Write-Verbose "current value $WaitSeconds"
		$Script:WaitSeconds = $seconds
		Write-Output "Seconds to wait for service functions updated to $Script:WaitSeconds"
	}
	else
	{
		Write-Host "Wait time must be between 0 and 60"

	}

}

<#
.SYNOPSIS
   Gets a list of System.ServiceProcess.ServiceController objects for all SourceOne services on
   all SourceOne machines
.DESCRIPTION
   Uses $s1Servers list to query all servers for status of s1 services
.EXAMPLE
	Get-AllES1Services
	
Status   Name               DisplayName
------   ----               -----------
Running  ES1AddressResol... EMC SourceOne Address Resolution
Running  ES1InPlaceMigSe... EMC SourceOne Inplace Migration
Running  ExAsAdmin          EMC SourceOne Administrator
Running  ExAsArchive        EMC SourceOne Archive
Running  ExAsIndex          EMC SourceOne Indexer
Running  ExAsQuery          EMC SourceOne Query
Running  ExJobDispatcher    EMC SourceOne Job Dispatcher
Stopped  ES1AddressResol... EMC SourceOne Address Resolution
Stopped  ExAddressCacheS... EMC SourceOne Address Cache
Stopped  ExAsAdmin          EMC SourceOne Administrator
Stopped  ExAsArchive        EMC SourceOne Archive

#>
function Get-AllES1Services
{
[CmdletBinding()]
Param()
 
if ($s1servers.count -eq 0)
{
	# This will set the "global" $s1servers, so throw the local output away
	get-ES1servers > $null
}

get-ES1Services $s1Servers

}

<#
.SYNOPSIS
   Starts all SourceOne services on all SourceOne machines
.DESCRIPTION
   Uses $s1Servers list to query all servers for status of s1 services
.EXAMPLE
	Start-AllES1Services
	
Status   Name               DisplayName
------   ----               -----------
Running  ES1AddressResol... EMC SourceOne Address Resolution
Running  ES1InPlaceMigSe... EMC SourceOne Inplace Migration
Running  ExAsAdmin          EMC SourceOne Administrator
Running  ExAsArchive        EMC SourceOne Archive
Running  ExAsIndex          EMC SourceOne Indexer
Running  ExAsQuery          EMC SourceOne Query
Running  ExJobDispatcher    EMC SourceOne Job Dispatcher
Stopped  ES1AddressResol... EMC SourceOne Address Resolution
Stopped  ExAddressCacheS... EMC SourceOne Address Cache
Stopped  ExAsAdmin          EMC SourceOne Administrator
Stopped  ExAsArchive        EMC SourceOne Archive

#>
function Start-AllES1Services
{
[CmdletBinding()]
Param()
 
if ($s1servers.count -eq 0)
{
	# This will set the "global" $s1servers, so throw the local output away
	get-ES1servers > $null
}

Start-ES1Services $s1Servers

}

<#
.SYNOPSIS
   Stops all SourceOne services on all SourceOne machines
.DESCRIPTION
   Uses $s1Servers list to query all servers for status of s1 services
.EXAMPLE
	Stop-AllES1Services
	
Status   Name               DisplayName
------   ----               -----------
Running  ES1AddressResol... EMC SourceOne Address Resolution
Running  ES1InPlaceMigSe... EMC SourceOne Inplace Migration
Running  ExAsAdmin          EMC SourceOne Administrator
Running  ExAsArchive        EMC SourceOne Archive
Running  ExAsIndex          EMC SourceOne Indexer
Running  ExAsQuery          EMC SourceOne Query
Running  ExJobDispatcher    EMC SourceOne Job Dispatcher
Stopped  ES1AddressResol... EMC SourceOne Address Resolution
Stopped  ExAddressCacheS... EMC SourceOne Address Cache
Stopped  ExAsAdmin          EMC SourceOne Administrator
Stopped  ExAsArchive        EMC SourceOne Archive

#>
function Stop-AllES1Services
{
[CmdletBinding()]
Param()
 
if ($s1servers.count -eq 0)
{
	# This will set the "global" $s1servers, so throw the local output away
	get-ES1servers > $null
}

Stop-ES1Services $s1Servers

}


function Show-AllES1Services
{
<#
.SYNOPSIS
 Displays the status of all SourceOne Services on all machines
.DESCRIPTION
Displays the status of all SourceOne Services on all machines
.EXAMPLE
Show-AllES1Services

DisplayName Name MachineName Status
----------- ---- ----------- ------
EMC SourceOne Indexer ExAsIndex IPMWORKER02 Running
EMC SourceOne Query ExAsQuery IPMWORKER02 Running
EMC SourceOne Job Dispatcher ExJobDispatcher IPMWORKER02 Running
EMC SourceOne archive ExAsArchive IPMWORKER02 Running
EMC SourceOne Address Resolution ES1AddressResolutionService IPMWORKER02 Running
EMC SourceOne Inplace Migration ES1InPlaceMigService IPMWORKER02 Running
EMC SourceOne Administrator ExAsAdmin IPMWORKER02 Running
EMC SourceOne Address Resolution ES1AddressResolutionService IPMWORKER3 Running
EMC SourceOne Inplace Migration ES1InPlaceMigService IPMWORKER3 Running
EMC SourceOne Job Dispatcher ExJobDispatcher IPMWORKER3 Running
EMC SourceOne Search service ExSearchService S1MASTER7-J1 Running
EMC SourceOne Job Scheduler ExJobScheduler S1MASTER7-J1 Running
EMC SourceOne Address Cache ExAddressCacheService S1MASTER7-J1 Running
EMC SourceOne Administrator ExAsAdmin S1MASTER7-J1 Running
EMC SourceOne Address Resolution ES1AddressResolutionService S1MASTER7-J1 Running
EMC SourceOne Job Dispatcher ExJobDispatcher S1MASTER7-J1 Running
EMC SourceOne Indexer ExAsIndex S1MASTER7-J1 Running
EMC SourceOne archive ExAsArchive S1MASTER7-J1 Running
EMC SourceOne Query ExAsQuery S1MASTER7-J1 Running
EMC SourceOne Offline Access Retrieval service ExDocMgmtSvcOA S1MASTER7-J1 Running
EMC SourceOne Document Management service ExDocMgmtSvc S1MASTER7-J1 Running


#>
[CmdletBinding()]
param()

$allServices = get-AllES1Services

$allServices| sort machinename | `
select-object DisplayName,Name,MachineName,Status | Format-Table -AutoSize #| Out-String -Width 10000

}


<#
.SYNOPSIS
   Manage-ES1Services
.DESCRIPTION
   Guts of all the SourceOne service functions
 .PARAMETER Computername
 Default to localhost, server name string or array of server names
 .PARAMETER Action
  1 to show services
  2 to start services
  3 to stop services
.EXAMPLE
	Manage-ES1Services
#>
function Manage-ES1Services
{
 [CmdletBinding()]
param
(
	[Parameter(
		ValueFromPipeLine=$true, 
		ValueFromPipeLineByPropertyName=$true)]
	[string[]]$ComputerName = 'localhost',
	$Action = $svcShow,
	$Credential = $remCreds,
	$Wait = $true

)

try
{
	$es1Services = get-service -displayname '*emc sourceone*' -ComputerName $computername
}
catch
{
	Write-Host "Must have access to remote services."
}
<#
if ($Credential.UserName -ne $null)
{
	$es1Services = gwmi win32_service -computername $ComputerName -filter "DisplayName like 'EMC SourceOne%'" -Credential $Credential
}
else
{
	$es1Services = gwmi win32_service -computername $ComputerName -filter "DisplayName like 'EMC SourceOne%'" | Where-Object {$_.State -eq 'xxx'}
}

#>
$WaitStr = ''

foreach ($service in $es1Services)
{
	Write-Verbose $service.name 
	if ($Action -eq $svcShow)
	{
		$es1Services
		return
	}
	try {

		switch ($Action)
		{

			$SvcStop {$WaitStr = 'Stopped';$service.Stop();break}
			$SvcStart {$WaitStr = 'Running';$service.Start(); break}
			$SvcPause { $WaitStr = 'Paused';$service.Pause();break}
			#$SvcResume {$hr = $service.ResumeService(); $WaitStr = 'Running'}
		}
	}
	catch
	{
		#service control function above will fail if allready in the state desired....
	}
	$service.Refresh()
	$hr = $service.status
	write-verbose $WaitStr
	write-verbose "$($service.name) on $($service.machinename) is $($hr)"
	if ($hr -ne $WaitStr)
	{
		try
		{
			$svc = Get-Service -ComputerName $service.machinename -name $service.name

			$svc.WaitForStatus($WaitStr,$WaitSeconds)
			$hr = $svc.status
		}
		catch
		{
			Write-Host ""
		}
	}
	if ($hr -ne $WaitStr)
	{
		write-host "after waiting $waittime seconds, $($service.name) on $($service.machinename) failed to $waitstr"
	}


}

}

<#
.SYNOPSIS
   Start-ES1Services
.DESCRIPTION
   Guts of all the SourceOne service functions
.PARAMETER ComputerName
   The name of target server or array of servers
.EXAMPLE
	Start-ES1Services Master
.EXAMPLE
	Start-ES1Services Master WebServer	
#>
function Start-ES1Services
{
[CmdletBinding()]
 param
(
	[Parameter(
		ValueFromPipeLine=$true, 
		ValueFromPipeLineByPropertyName=$true)]
	[string[]]$ComputerName = 'localhost',
	$Credential = $remCreds,
	$Wait = $true
)
$s = manage-ES1Services -ComputerName $ComputerName -action $SvcStart -Credential $Credential -wait $Wait

Show-ES1Services $ComputerName

}

<#
.SYNOPSIS
   Restart-ES1Services
.DESCRIPTION
   Guts of all the SourceOne service functions
.PARAMETER ComputerName
   The name of target server or array of servers
.EXAMPLE
	Restart-ES1Services Master
.EXAMPLE
	Restart-ES1Services Master WebServer	
#>

function Restart-ES1Services
{
[CmdletBinding()]
 param
(
	[Parameter(
		ValueFromPipeLine=$true, 
		ValueFromPipeLineByPropertyName=$true)]
	[string[]]$ComputerName = 'localhost',
	$Credential = $remCreds,
	$Wait = $true

)
$s = manage-es1Services -ComputerName $ComputerName -action $SvcStop -Credential $Credential -wait $true
$s = manage-es1Services -ComputerName $ComputerName -action $SvcStart -Credential $Credential -wait $Wait

Show-ES1Services $ComputerName

}

# The only s1 service that appears to pause is DCWorkerService

function Pause-ES1Services
{
<#
.SYNOPSIS
 Pause-ES1Services
.DESCRIPTION

.PARAMETER ComputerName

.EXAMPLE

.EXAMPLE

#>
[CmdletBinding()]
param
(
	[Parameter(
		ValueFromPipeLine=$true, 
		ValueFromPipeLineByPropertyName=$true)]
	[string[]]$ComputerName = 'localhost',
	$Credential = $remCreds,
	$Wait = $true

)
$s = manage-es1Services -ComputerName $ComputerName -action $SvcPause -Credential $Credential -wait $Wait

Show-es1Services $ComputerName

}

function Resume-ES1Services
{
<#
.SYNOPSIS
 Resume-ES1Services
.DESCRIPTION

.PARAMETER ComputerName

.EXAMPLE

.EXAMPLE

#>
[CmdletBinding()]
param
(
	[Parameter(
		ValueFromPipeLine=$true, 
		ValueFromPipeLineByPropertyName=$true)]
	[string[]]$ComputerName = 'localhost',
	$Credential = $remCreds,
	$Wait = $true

)

$s = manage-es1Services -ComputerName $ComputerName -action $SvcResume -Credential $Credential -wait $Wait
Show-es1Services $ComputerName

}


<#
.SYNOPSIS
   Stop-ES1Services
.DESCRIPTION
   Guts of all the SourceOne service functions
.PARAMETER ComputerName
   The name of target server or array of servers
.EXAMPLE
	Stop-ES1Services Master
.EXAMPLE
	Stop-ES1Services Master WebServer	
#>
function Stop-ES1Services
{

[CmdletBinding()]
param
(
 [Parameter(
	ValueFromPipeLine=$true, 
	ValueFromPipeLineByPropertyName=$true)]
[string[]]$ComputerName = 'localhost',
$Credential = $remCreds,
$Wait = $true


)
$s = manage-es1Services -ComputerName $ComputerName -action $SvcStop -Credential $Credential -wait $wait

Show-es1Services $ComputerName

}


New-Alias Get-AllS1Services Get-AllES1Services
New-Alias Get-S1Services Get-ES1Services
New-Alias Start-S1Services Start-ES1Services
New-Alias Start-AllS1Services Start-AllES1Services
New-Alias Stop-S1Services Stop-ES1Services
New-Alias Stop-AllS1Services Stop-AllES1Services
New-Alias ReStart-S1Services ReStart-ES1Services

Export-ModuleMember -Function * -Alias * 
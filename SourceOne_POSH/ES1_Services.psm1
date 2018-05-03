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
		Functions for managing SourceOne Services

#>

#requires -Version 2

$SvcShow = 1
$SvcStart = 2
$SvcStop = 3
$svcRestart = 4
$svcPause = 5
$svcResume = 6
$WaitTime = '00:00:30'
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
$cntIds=$ComputerName.Count
$i=0

foreach($computer in $ComputerName)
{
	
	[int]$dispCnt = ($i+1)
    Write-Progress -id 1 -Activity "Getting SourceOne Services " -Status "Number of SourceOne Machines: $cntIds" -percentcomplete (($i/$cntIds)*100) -Currentoperation "Processing Machine: $computer ($dispCnt)"
          
    $i++
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
	$machineServices| sort machinename | select-object MachineName,DisplayName,Name,Status | Format-Table -AutoSize #| Out-String -Width 10000
}
catch 
{
    Write-Error $_
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
	Get-ES1servers > $null
}

Get-ES1Services $s1Servers

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
   Stops all SourceOne services on all known SourceOne machines
.DESCRIPTION
	Stops all SourceOne services on all known SourceOne machines
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
 Displays the status of all SourceOne Services on all known machines
.DESCRIPTION
Displays the status of all SourceOne Services on all known machines
.EXAMPLE
Show-AllES1Services




#>
[CmdletBinding()]
param()

$allServices = get-AllES1Services

$allServices| sort machinename | `
select-object MachineName,DisplayName,Name,Status | Format-Table -AutoSize #| Out-String -Width 10000

}


<#
.SYNOPSIS
   Update-ES1Services
.DESCRIPTION
   Guts of (almost) all the SourceOne service functions
 .PARAMETER Computername
 Default to localhost, server name string or array of server names
 .PARAMETER Action
  1 to show services
  2 to start services
  3 to stop services
.EXAMPLE
	Update-ES1Services
#>
function Update-ES1Services
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


#
# Process each machine one at a time so we can handle the errors nicely...
#   
$cntIds=$ComputerName.Count
$i=0

foreach ($computer in $ComputerName)
{
    [int]$dispCnt = ($i+1)
    Write-Progress -id 1 -Activity "Managing Services State Change " -Status "Number of SourceOne Machines: $cntIds" -percentcomplete (($i/$cntIds)*100) -Currentoperation "Processing Machine: $computer ($dispCnt)"
          
    $i++
    try
    {
	    $es1Services = get-service -displayname '*emc sourceone*' -ComputerName $computer -ErrorAction SilentlyContinue -ErrorVariable gserror
        $WaitStr = ''
		$svcCount=$es1Services.Count
		$j=0

        foreach ($service in $es1Services)
        {
	        Write-Verbose "$($service.name ) in state $($service.Status)"
			[int]$dispSvcCnt = ($j+1)
            $j++
        
            Write-Progress -id 2 -parentId 1 -Activity "Changing Services on $($computer)" -Status "Number of Services: $svcCount " -percentcomplete (($j/$svcCount)*100) -Currentoperation "Service : $($service.Name) ($dispSvcCnt)"

	        if ($Action -eq $svcShow)
	        {
               Write-Error "Unsupported feature !"
		        return
	        }
	        try {

                    # do a refresh because stopping a service with dependencies will stop those dependencies too
                    #   before we get to them
                    $service.Refresh()
                    Write-Verbose "Refreshed returned state $($service.Status)"

		            switch ($Action)
		            {

			            $SvcStop 
                        {
                            $WaitStr = 'Stopped'
                            if (($service.Status -ne "Stopped") -and ($service.Status -ne "StopPending"))
                            {
                                $service.Stop()
                            }
                            else{
                                Write-Verbose "  Already in stopped or stoppending"
                            }
                            break
                        }

			            $SvcStart 
                        {
                            $WaitStr = 'Running'
                            $service.Start()
                             break
                         }

			            $SvcPause 
                        { 
                            $WaitStr = 'Paused'
                            $service.Pause()
                            break
                         }
			            #$SvcResume {$hr = $service.ResumeService(); $WaitStr = 'Running'}
		            }
	        }
	        catch
	        {
		        #service control function above will fail if already in the state desired....
                Write-Error $_
	        }
	        
            $service.Refresh()
	        $hr = $service.status
	        write-verbose "WaitStr: $($WaitStr) WaitTime: $($waittime)"
	        write-verbose "$($service.name) on $($service.machinename) is $($hr)"
	        if ($hr -ne $WaitStr)
	        {
		        try
		        {
			        $svc = Get-Service -ComputerName $service.machinename -name $service.name

			        $svc.WaitForStatus($WaitStr,$waittime)
			        $hr = $svc.status
		        }
		        catch
		        {
			        Write-Host ""
		        }
	        }

	        if ($hr -ne $WaitStr)
	        {
		        write-host "after waiting $waittime seconds, $($service.name) on $($service.machinename) failed change to $waitstr"
	        }
        }
		  Write-Progress -id 2 -parentId 1 -Activity "Changing Services on $($computer)" -Completed -Status "Done"
    }
    catch
    {
		    Write-Host "Error accessing server: $($computer). Make sure the machine is up and reachable" -ForegroundColor Red
		    Write-Host $gserror.Message -ForegroundColor Red

    }

  }

}

<#
.SYNOPSIS
   Starts the SourceOne services on the machine or machines specified
.DESCRIPTION
   Starts the SourceOne services on the machine or machines specified
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
$s = Update-ES1Services -ComputerName $ComputerName -action $SvcStart -Credential $Credential -wait $Wait

Show-ES1Services $ComputerName

}

<#
.SYNOPSIS
   Performs a "Stop" and then "Start" on all SourceOne services on the specified machine(s)
.DESCRIPTION
   Performs a "Stop" and then "Start" on all SourceOne services on the specified machine(s)
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
$s = Update-es1Services -ComputerName $ComputerName -action $SvcStop -Credential $Credential -wait $true
$s = Update-es1Services -ComputerName $ComputerName -action $SvcStart -Credential $Credential -wait $Wait

Show-ES1Services $ComputerName

}

# The only s1 service that appears to pause is DCWorkerService

function Pause-ES1Services
{
<#
.SYNOPSIS
 Pause-ES1Services
.DESCRIPTION
Pauses SourceOne service.  Not all SourceOne services support this state.
The only s1 service that appears to pause is DCWorkerService

.PARAMETER <ComputerName>
Specifies the computer against which you want to run the management operation. The Value can be a fully qualified domain Name, a NetBIOS Name, or an IP address. Use the local computer Name, use localhost, or use a dot (.) to specify the local computer
. The local computer is the default. When the remote computer is in a different domain from the user, you must use a fully qualified domain Name. This parameter can also be piped to the cmdlet.

.PARAMETER <Credential>
Specifies a user account that has permission to perform this action. The default is the current user. Type a user Name, such as "User01", "Domain01\User01", or user@Contoso.com. Or, enter a PSCredential object, such as an object that is returned by th
e Get-Credential cmdlet. When you Type a user Name, you will be prompted for a Password.

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
$s = Update-es1Services -ComputerName $ComputerName -action $SvcPause -Credential $Credential -wait $Wait

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

$s = Update-ES1Services -ComputerName $ComputerName -action $SvcResume -Credential $Credential -wait $Wait
Show-es1Services $ComputerName

}


<#
.SYNOPSIS
   Stops SourceOne services on a specific machine(s)
.DESCRIPTION
   Stops SourceOne services on a specific machine(s)
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


    # If we are passed credentials just use them
    # If not see if we have Admin privs and if we get new privs use those
    if (-not $Credential)
    {
        $isAdmin = Test-IsAdmin

        if ( -not $isAdmin )
        {
            return
        }

    }


    $s = Update-ES1Services -ComputerName $ComputerName -action $SvcStop -Credential $Credential -wait $wait

Show-es1Services $ComputerName

}


function Get-S1ServicesByAccount
<#
.SYNOPSIS
	Get the services which use the specified account (s1 service account) as the user
.DESCRIPTION
	Get the services which use the specified account (s1 service account) as the user

.PARAMETER <ComputerName>
Specifies the computer against which you want to run the management operation. The Value can be a fully qualified domain Name, a NetBIOS Name, or an IP address. Use the local computer Name, use localhost, or use a dot (.) to specify the local computer
. The local computer is the default. When the remote computer is in a different domain from the user, you must use a fully qualified domain Name. This parameter can also be piped to the cmdlet.
.PARAMETER <s1acct>
SourceOne account
.PARAMETER <Credential>
Specifies a user account that has permission to perform this action. The default is the current user. Type a user Name, such as "User01", "Domain01\User01", or user@Contoso.com. Or, enter a PSCredential object, such as an object that is returned by th
e Get-Credential cmdlet. When you Type a user Name, you will be prompted for a Password.


.EXAMPLE
#>

{
[CmdletBinding()]
param
(
	[Parameter(
		ValueFromPipeLine=$true, 
		ValueFromPipeLineByPropertyName=$true)]
	[string[]]$ComputerName = $env:computername,
    $s1acct = $env:USERNAME,
	$Credential = $remCreds

)
    $gservicelist=@()
    $filterTemplate = "startname like '%xxxx%'"  
    $filter = $filterTemplate.Replace("xxxx",$s1acct)

    try {
        if ($ComputerName -eq $localhost)
        {
          write-debug "$ComputerName is localhost"
          $gservicelist = gwmi -class win32_service -filter $filter -ErrorAction Stop
        }
        else
        {
           write-debug "$ComputerName is remote"
           $gservicelist = gwmi -class win32_service -filter $filter -ComputerName $ComputerName -ErrorAction Stop
        }
    }
    catch {
        throw $_

    }

    $gservicelist
}
<#
.SYNOPSIS
	Shows a list of the services which use the specified account (s1 service account) as the user on the given Computer
.DESCRIPTION
	Shows a list of the services which use the specified account (s1 service account) as the user on the given Computer

.PARAMETER <ComputerName>
Specifies the computer against which you want to run the management operation. The Value can be a fully qualified domain Name, a NetBIOS Name, or an IP address. Use the local computer Name, use localhost, or use a dot (.) to specify the local computer
. The local computer is the default. When the remote computer is in a different domain from the user, you must use a fully qualified domain Name. This parameter can also be piped to the cmdlet.
.PARAMETER <Credential>
Specifies a user account that has permission to perform this action. The default is the current user. Type a user Name, such as "User01", "Domain01\User01", or user@Contoso.com. Or, enter a PSCredential object, such as an object that is returned by th
e Get-Credential cmdlet. When you Type a user Name, you will be prompted for a Password.


.EXAMPLE
#>

function Show-S1ServicesByAccount
{
    [CmdletBinding()]
    param
    (
	    [Parameter(
		    ValueFromPipeLine=$true, 
		    ValueFromPipeLineByPropertyName=$true)]
	    [string]$ComputerName = $env:computername,
        $s1acct = $env:USERNAME,
	    $Credential = $remCreds
    )
        try {
            $results = Get-S1ServicesByAccount -ComputerName $ComputerName -s1acct $s1acct -Credential $remCreds 
           
        }
        catch {
            Write-Warning "Error getting services from machine: $($ComputerName).  Make sure the machine is running and reachable."
                        
            # create a fake object to return so all machines are in the list
            $props = @{'SystemName'=$ComputerName;'Name'='';'State'='Cannot access server';'Status'=$_.Exception.Message}
			$results = New-object -TypeName PSObject -Prop $props
          
       }
       
       $results  | select-object SystemName,Name,State,Status | Format-Table -AutoSize | Out-String -Width 10000

}

function Show-AllS1ServicesByAccount
<#
.SYNOPSIS
	Shows a list of the services which use the specified account (s1 service account) as the user on all known S1 machines
.DESCRIPTION
	Shows a list of the services which use the specified account (s1 service account) as the user on all known S1 machines

.PARAMETER 


.EXAMPLE
#>

{
    [CmdletBinding()]
    param
    (
	    [Parameter(
		    ValueFromPipeLine=$true, 
		    ValueFromPipeLineByPropertyName=$true)]
        $s1acct = $env:USERNAME,
	    $Credential = $remCreds
    )
    if ($s1servers.count -eq 0)
    {
	    # This will set the "global" $s1servers, so throw the local output away
	    get-ES1servers > $null
    }
    foreach ($server in $s1servers)
    {
        try {
            
            $results = Get-S1ServicesByAccount -ComputerName $server -s1acct $s1acct -Credential $remCreds 

        }
         catch {
            Write-Warning "Error getting services from machine: $($server).  Make sure the machine is running and reachable."
                        
            # create a fake object to return so all machines are in the list
            $props = @{'SystemName'=$server;'Name'='';'State'='Cannot access server';'Status'=$_.Exception.Message}
			$results = New-object -TypeName PSObject -Prop $props
          
       }
       
       $results  | select-object SystemName,Name,State,Status | Format-Table -AutoSize | Out-String -Width 10000

    }
}

function Update-S1ServicesAccountInfo
<#
.SYNOPSIS
	Updates the password for all S1 services on the specified machine(s).  
.DESCRIPTION
	Updates the password for all S1 services on the specified machine(s).  

.PARAMETER <ComputerName>
Specifies the computer against which you want to run the management operation. The Value can be a fully qualified domain Name, a NetBIOS Name, or an IP address. Use the local computer Name, use localhost, or use a dot (.) to specify the local computer
. The local computer is the default. When the remote computer is in a different domain from the user, you must use a fully qualified domain Name. This parameter can also be piped to the cmdlet.
.PARAMETER <s1acct> 
	SourceOne service account name
.PARAMETER <Password> 
	System.Security.SecureString containing the password to use.  If not supplied you will be prompted and input will be masked.
.PARAMETER <timeout> 
	The number of seconds to wait for services to stop or start.  The default is 10 seconds
.PARAMETER <Credential> 
(UNUSED)
Specifies a user account that has permission to perform this action. The default is the current user. Type a user Name, such as "User01", "Domain01\User01", or user@Contoso.com. Or, enter a PSCredential object, such as an object that is returned by th
e Get-Credential cmdlet. When you Type a user Name, you will be prompted for a Password.

.EXAMPLE
#>

{
[CmdletBinding()]
param
(
	[Parameter(
		ValueFromPipeLine=$true, 
		ValueFromPipeLineByPropertyName=$true)]
	[string[]]$ComputerName = $env:computername,
    [string]$s1acct = $env:USERNAME,
    [Parameter(Mandatory=$true, HelpMessage='Enter the Service Account Password')]
    [ValidateNotNullOrEmpty()]
    [System.Security.SecureString] $Password,
    [int]$timeout = 10,
	$Credential = $remCreds
)

    $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password)                                                                                                       
    $s1pw = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr) 

    if (-not (Test-ADCredential -username $s1acct -password $s1pw))
    {
        Write-Error "Password provided is not the current or correct password !"
        return

    }
     
     $results=@()

     $waitRet=$false 
       
    #
    # Process each machine one at a time so we can handle the errors nicely...
    #   
    $cntIds=$ComputerName.Count
    $i=0

    foreach ($computer in $ComputerName)
    {
        [int]$dispCnt = ($i+1)
        Write-Progress -id 1 -Activity "Processing Service Password Update" -Status "Number of SourceOne Machines: $cntIds" -percentcomplete (($i/$cntIds)*100) -Currentoperation "Processing Machine: $computer ($dispCnt)"
           
        $i++
        $services=@()

        try
        {
        $services = Get-S1ServicesByAccount -ComputerName $computer -s1acct $s1acct -Credential $remCreds
        }
       catch {
            Write-Error "Error getting services from machine: $($computer).  Make sure the machine is running and reachable."
            $props = @{'SystemName'=$computer;'ServiceName'='NA';'StopStatus'=$_.Exception.Message;'ChangeStatus'='';'StartStatus'=''}
    		$MachineResults = New-object -TypeName PSObject -Prop $props
            $results +=$MachineResults
            continue
       }

       $svcCount=$services.Count
       $j=0

        foreach ($svc in $services)
        {
        
            [int]$dispSvcCnt = ($j+1)
            $j++

            # Get dependent services and stop those first...
            $depends=Get-WMIObject -ComputerName $computer -Query "Associators of {Win32_Service.Name='$($svc.name)'} Where AssocClass=Win32_DependentService Role=Antecedent"
        
            Write-Progress -id 2 -parentId 1 -Activity "Updating Service Passwords on $($computer)" -Status "Number of Services: $svcCount " -percentcomplete (($j/$svcCount)*100) -Currentoperation "Service : $($svc.Name) ($dispSvcCnt)"
           
            Write-Verbose "Stopping service $($svc.name) on server $($svc.systemname) " 
			#
			# This whole stop start process does NOT take into account the current state of the service
			#    If the services is already stopped, it will blindly be started below.  Maybe thats not a good
			#    thing (??)
            if ($depends.Count -gt 0)
            {
                foreach ($depSvc in $depends)
                {
                    if (($depSvc.State -ne 'Stopped' ) -and ($depSvc.State -ne 'StopPending' ))
                    {
                        Write-Verbose "Stopping Dependent Service $($depSvc.name) on server $($depSvc.systemname) " 
                        $depret = $depSvc.StopService()        
                        $waitRet=WaitForService $depSvc.name 'stopped' $timeout $computer 
                    }
                }
            }
        
        
            $ret = $svc.StopService()        
            $waitRet=WaitForService $svc.name 'stopped' $timeout $computer 

            $props = @{'SystemName'=$computer;'ServiceName'=$svc.Name;'StopStatus'=$waitRet;'ChangeStatus'='';'StartStatus'=''}
    		$MachineResults = New-object -TypeName PSObject -Prop $props
        
        
            Write-Verbose "modifying service $($svc.name) on server $($svc.systemname) "                                                                                                                                                                      
            $changeStatus = $svc.Change($null,$null,$null,$null,$null,$null,$null,$s1pw,$null,$null,$null) 
                                                                                                
            if ($changeStatus.ReturnValue -eq "0")
            {
                write-host "Server: $($svc.systemname) Password changed for service $($svc.name)"
                $MachineResults.ChangeStatus='Success'
            }
            else
            {
                write-error "Server: $($svc.systemname) Password change FAILED for service $($svc.name), Error Code=$($changeStatus.ReturnValue)"
                $MachineResults.ChangeStatus=$changeStatus.ReturnValue
            }
        

            Write-Verbose "starting service $($svc.name) on $($svc.systemname) "                                                                                                                                                                      
            $ret = $svc.StartService()
        
          
            # only wait if startservice was "accepted"
            if ($ret.ReturnValue -eq 0)
            {
                $waitRet=WaitForService $svc.name 'running' $timeout $computer
                $MachineResults.StartStatus=$waitRet

            }
            elseif ($ret.ReturnValue -eq 15)
            {
                Write-Error "Authentication failure starting service: $($svc.name) !`nWrong password supplied !"
                $MachineResults.StartStatus='Authentication failure starting service!'
            }
            else
            {
                $MachineResults.StartStatus=$ret.ReturnValue
                Write-Error "Unexpected error starting service $($svc.name) ! StartService returned error $($ret.ReturnValue) !"
                 
            }
            
            
            $results +=$MachineResults

        }
         
         Write-Progress -id 2 -parentId 1 -Activity "Updating Service Passwords on $($computer)" -Completed -Status "Done"
         
    }
    
    
    Write-Progress -id 1 -Activity "Updating Passwords " -Completed -Status "Done"
    
    $results | select-object SystemName,ServiceName,StopStatus,ChangeStatus,StartStatus

}

function Update-AllS1ServicesAccountInfo
<#
.SYNOPSIS
	Updates the password for all S1 services on all known SourceOne machines.
.DESCRIPTION
	Updates the password for all S1 services on all known SourceOne machines.  Not all machines running SourceOne services are known to
	the SourceOne systems.

.PARAMETER <s1acct> 
	SourceOne service account name

.PARAMETER <timeout> 
	The number of seconds to wait for services to stop or start.  The default is 10 seconds
.PARAMETER <Credential> 
(UNUSED)
Specifies a user account that has permission to perform this action. The default is the current user. 
Type a user Name, such as "User01", "Domain01\User01", or user@Contoso.com. Or, enter a PSCredential object, 
such as an object that is returned by the Get-Credential cmdlet. When you Type a user Name, you will be prompted for a Password.

.EXAMPLE
#>

{
[CmdletBinding()]
param
(
	[Parameter(
		ValueFromPipeLine=$true, 
		ValueFromPipeLineByPropertyName=$true)]
    [string]$s1acct = $env:USERNAME,
    [int]$timeout = 10,
	$Credential = $remCreds
)

     $isAdmin = Test-IsAdmin
    if ( -not $isAdmin)
    {
        return
    }

    Write-Host ""

    $newpassword = read-host -Prompt "Enter the password for $($s1acct)" -AsSecureString 
  
    Write-Host ""

    if ($s1servers.count -eq 0)
    {
	    # This will set the "global" $s1servers, so throw the local output away
	    get-ES1servers > $null
    }

 
    $updResults= Update-S1ServicesAccountInfo -s1acct $s1acct -Password $newpassword -ComputerName $s1servers
   
    $updResults | sort SystemName | Format-Table -AutoSize |Out-String -Width 10000

    #Show-AllS1ServicesByAccount -s1acct $s1acct
}

function WaitForService ([string] $svc,[string] $command,[int] $secs,[string]$Server = $env:COMPUTERNAME)
<#
.SYNOPSIS
	Internal use 
.DESCRIPTION
	Internal use 
#>

{
	$ret = $false
	$x = get-service $svc -computername $Server -ErrorAction SilentlyContinue
	$Done = $false
	$secs--
	if ($secs -le 0 ) 
    {
        $secs = 0
    }

	while (!$Done)
	{
		if ($x.status -ne $command)
		{
			Sleep -Seconds 1
			if ($secs-- -eq 0) 
            {
                break
            }
            
            $x.Refresh()
			#$x = get-service $svc -computername $Server -ErrorAction SilentlyContinue
			write-debug "Waiting for $svc to be $command"
		}
		else
		{
			$state = $x.status
			Write-Verbose "$svc on $Server is $state"
			$Done = $true
			$ret = $true
			break
		}
	}
	
    if (!$Done) 
    {
        write-host "****Timer has expired waiting for $($svc) on $($Server) to be $($command)"
    }
    
    $ret
}     

function Test-S1ServiceExists ([string] $svc,$Server = $env:COMPUTERNAME)
<#
.SYNOPSIS
	Test if a specific service present on the specified computer
.DESCRIPTION
	Test if a specific service present on the specified computer

.PARAMETER 

.EXAMPLE
	TBD
#>
{
	$x = get-service $svc -computername $server -ErrorAction SilentlyContinue
	if ($x -ne $null)
	{
		return $true
	}
	else
	{
		return $false
	}
}

New-Alias Get-AllS1Services Get-AllES1Services
New-Alias Get-S1Services Get-ES1Services
New-Alias Start-S1Services Start-ES1Services
New-Alias Start-AllS1Services Start-AllES1Services
New-Alias Stop-S1Services Stop-ES1Services
New-Alias Stop-AllS1Services Stop-AllES1Services
New-Alias ReStart-S1Services ReStart-ES1Services
New-Alias Get-ES1ServicesByAccount Get-S1ServicesByAccount
New-Alias Show-ES1ServicesByAccount Show-S1ServicesByAccount
New-Alias Show-AllES1ServicesByAccount Show-AllS1ServicesByAccount
New-Alias Update-ES1ServicesAccountInfo Update-S1ServicesAccountInfo
New-Alias Update-AllES1ServicesAccountInfo Update-AllS1ServicesAccountInfo
New-Alias Test-ES1ServiceExists Test-S1ServiceExists



Export-ModuleMember -Function *-* -Alias * 
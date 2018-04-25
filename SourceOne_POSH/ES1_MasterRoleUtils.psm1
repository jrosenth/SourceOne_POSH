<#	
	.NOTES
	===========================================================================

	Copyright (c) 2015-2018 Dell Technologies, Dell EMC.  All rights reserved.
	===========================================================================
	THIS CODE AND INFORMATION IS PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND,
	WHETHER EXPRESSED OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE IMPLIED
	WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A PARTICULAR PURPOSE.
	IF THIS CODE AND INFORMATION IS MODIFIED, THE ENTIRE RISK OF USE OR RESULTS IN
	CONNECTION WITH THE USE OF THIS CODE AND INFORMATION REMAINS WITH THE USER. 

	.DESCRIPTION
		Functions for inspecting or getting "Master" machine related stuff

#>

#requires -Version 4



function Get-ES1MasterInstalled
{
<#
.SYNOPSIS
	Returns a list of servers with the Master component installed on it and the version number installed.
.DESCRIPTION
	Returns a list of servers with the Master component installed on it and the version number installed.
	Almost always there should only be one and only one of these found.

.PARAMETER [string[]]$ComputerName
	A list of server to check

.OUTPUTS

.EXAMPLE 

#>
[CmdletBinding()]
PARAM
(
	[Parameter(
		ValueFromPipeLine=$true, 
		ValueFromPipeLineByPropertyName=$true)]
	[string[]]$ComputerName = $env:computername,
	$Credential = $remCreds

)
BEGIN{}
PROCESS {

	$results=@()

#
# Process each machine one at a time so we can handle the errors nicely...
#   
$cntIds=$ComputerName.Count
$i=0

foreach($server in $ComputerName)
{


	try 
    {
		$reg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine', $server)
	

	    # Try the 64 bit location first as 64 bit OS's are most common these days.
	    $keypath = 'SOFTWARE\Wow6432Node\EMC\SourceOne\Versions'
	    $regkey = $reg.OpenSubkey($keypath)
	
        if ($regkey -eq $null)
	    {
		    $keypath = 'SOFTWARE\EMC\SourceOne\Versions'
		    $regkey = $reg.OpenSubkey($keypath)
	    }

	    if ($regkey -ne $null)
	    {
		    #
		    # Get the Master+ attribute, cause this info isnt in a database anywhere...
		    #
		    $valuename ='Master+' 

		    $readvalue = $regkey.GetValue($valuename) 
		    if ($readvalue -ne $null)
		    {
			    $props = [ordered] @{'ComputerName'=$server;'Version'=''}
			    $ismaster = New-object -TypeName PSObject -Prop $props
			    $ismaster.Version=$readvalue

			    $results += $ismaster

			    Write-Debug "$server`t$regkey`t$valuename`t$readvalue" 
		    }
        }
		
        $reg.Close()

    }
	
    catch 
    {
        Write-Error "Error Reading registry on server : $($server)"
        Write-Error $_
		
	}


}

	# Return the value from the registry...
	$results
	
}
END {}
}


function Test-IsOnS1Master
{
<#
.SYNOPSIS
Determines if running on the S1 Master machine by inspecting the Windows registry

.DESCRIPTION
Determines if running on the S1 Master machine by inspecting the Windows registry


.EXAMPLE
$onMaster = Test-IsOnS1Master
#>
[CmdletBinding()]
param()

begin {
	[bool] $IsMasterMachine = $false
}

process {

	$S1RegVersions = Get-ES1RegLocation
	if ($S1RegVersions.length -gt 0)
	{
		# Append the "versions" branch
		$S1RegVersions=$S1RegVersions+'Versions'
	}

	$MasterInstalled = Get-ItemProperty -Path $S1RegVersions -Name "Master+" -ErrorAction SilentlyContinue

	if ( $MasterInstalled )
	{
		$IsMasterMachine = $true
	}

	$IsMasterMachine
}

end {}


}




Export-ModuleMember -Function * -Alias *

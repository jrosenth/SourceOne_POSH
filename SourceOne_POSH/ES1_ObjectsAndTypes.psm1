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
	===========================================================================
	.DESCRIPTION
		A collection of function to load SourceOne COM/.NET datatypes and ENUMs
        
#>

###

Function Add-ES1Types {
<#
.SYNOPSIS
	Add the SourceOne COM, .NET objects and Datatypes to the current Powershell context
.DESCRIPTION
	Add the SourceOne COM, .NET objects and Datatypes to the current Powershell Context
	SourceOne objects are all 32 bit COM/.NET objects, therefore must only be used in 
	32 bit PowerShell hosts.  Starting with SourceOne 7.0 all COM/.NET objects also require
	.NET 4.0 or greater.  PowerShell 2.0 loads .NET 2 by defualt therefore these objects and
	types can only be used with PowerShell 3.0 or greater.
	
.EXAMPLE
	Add-ES1Types

#>
[CmdletBinding()]
Param( )

BEGIN{
    [bool] $success = $false
}

PROCESS
{
	
	$POSHVersion=Get-POSHVersionAndArchitecture
	#Write-Host "Powershell Version : $POSHVersion"
	if ($POSHVersion.Architecture -eq '64-bit')
	{
		Write-Error 'This must run in a 32 bit PowerShell !'
        Throw 'This must run in a 32 bit PowerShell !'
	   return $success
	}

	# I changed the manifest to require Powershell 4 or greater now, so this may never show 
	if ($POSHVersion.Version -eq '2.0')
	{
		Write-Error 'Requires PowerShell 4.0 or greater !'
        Throw 'Requires PowerShell 4.0 or greater !'
	   return $success
	}

	try {
		# Powershell 3 and greater
		#  This works with SourceOne 7.1.1
		#     May have to adjust the Version strings for other versions of S1
		add-type -assemblyname "EMC.Interop.ExBase, Culture=neutral,Version=6.6.3.8,PublicKeyToken=D3CC2CEEAFB73BC1" -ErrorAction SilentlyContinue
		add-type -assemblyname "EMC.Interop.ExSTLContainers, Culture=neutral,Version=6.6.3.1,PublicKeyToken=D3CC2CEEAFB73BC1"  -ErrorAction SilentlyContinue
		add-type -assemblyname "EMC.Interop.ExASBaseAPI, Culture=neutral,Version=6.6.3.1,PublicKeyToken=D3CC2CEEAFB73BC1" -ErrorAction SilentlyContinue
		add-type -assemblyname "EMC.Interop.ExJDFAPI, Culture=neutral,Version=6.6.3.2,PublicKeyToken=D3CC2CEEAFB73BC1"  -ErrorAction SilentlyContinue
		add-type -AssemblyName "EMC.Interop.ExASAdminAPI, Culture=neutral,Version=6.6.3.1,PublicKeyToken=D3CC2CEEAFB73BC1" -ErrorAction SilentlyContinue
        $success = $true
	}
	catch {
		
		Write-Host  'Failed loading SourceOne Objects and Types !  ' -foregroundcolor red
		Write-Host  'This command can only be run on a SourceOne machine where SourceOne COM objects have been registered' -foregroundcolor red
        Throw $_
	}

    $success
}


END {}

}


Export-ModuleMember -Function Add-ES1Types

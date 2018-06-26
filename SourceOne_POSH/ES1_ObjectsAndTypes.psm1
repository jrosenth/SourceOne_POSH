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
	===========================================================================
.DESCRIPTION
		A collection of functions to load SourceOne COM/.NET datatypes and ENUMs        
#>


Function Add-ES1Types {
<#
.SYNOPSIS
	Add the SourceOne COM, .NET objects and Datatypes to the current Powershell context
.DESCRIPTION
	Add the SourceOne COM, .NET objects and Datatypes to the current Powershell Context
	SourceOne objects are all 32 bit COM/.NET objects, therefore must only be used in 
	32 bit PowerShell hosts.  Starting with SourceOne 7.0 all COM/.NET objects also 
	require .NET 4.0 or greater.  PowerShell 2.0 loads .NET 2 by defualt therefore these objects and
	types can only be used with PowerShell 3.0 or greater.
	
.EXAMPLE
	Add-ES1Types

	Description
	-----------------------
	Loads available SourceOne COM, .NET objects and Datatypes to the current context
#>

[OutputType('System.Boolean')]
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
		add-type -assemblyname "EMC.Interop.ExDataSet, Culture=neutral,Version=6.6.3.1,PublicKeyToken=D3CC2CEEAFB73BC1"  -ErrorAction SilentlyContinue
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

Function Show-ES1COMObjects {
<#
.SYNOPSIS
	Displays a list of the SourceOne COM/.NET objects, classes that are registered on the system
.DESCRIPTION
	Displays a list of the SourceOne COM/.NET objects, classes that are registered on the system.
	The registered objects may differ depending on the SourceOne machine and installed roles.
	The objects are enumerated from the HKLM:\Software\Classes registry key and some regex filtering is applied
	to display only objects in known EMC and SourceOne namespaces.

.EXAMPLE
	Show-ES1COMObjects

#>
[CmdletBinding()]
Param( )

BEGIN{
}

PROCESS
{
	Get-ChildItem HKLM:\Software\Classes -ErrorAction SilentlyContinue | Where-Object {
	   (($_.PSChildName -like '*.CoEx*') -or ($_.PSChildName -like 'EMC.*')) -and (Test-Path -Path "$($_.PSPath)\CLSID") 
	} | ft -AutoSize | Out-String -Width 10000 

}

END {}
}

Function Show-EMCEnums {
<#
.SYNOPSIS
	Display a list of enum types and values only in the "EMC" namespace in the current context
	
.DESCRIPTION
	Display a list of enum types and values only in the "EMC" namespace in the current context

.EXAMPLE
	Show-EMCEnums
	
Type                                       Name                                                            Value
----                                       ----                                                            -----
EMC.Interop.ExBase.exCoreTaskTypes         exCoreTaskTypes_Undefined                                           0
EMC.Interop.ExBase.exCoreTaskTypes         exCoreTaskTypes_Diagnostic                                          1
EMC.Interop.ExBase.exCoreTaskTypes         exCoreTaskTypes_Journal                                             2

#>
[CmdletBinding()]
Param( )

BEGIN{
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

PROCESS
{

	get-type -IsEnum -Namespace EMC* | Get-EnumValues | ft -AutoSize | Out-String -Width 10000


}

END {}
}

Function Show-EMCAvailableTypes {
<#
.SYNOPSIS
	Display a list of the objects in the "EMC" namespace in the current context
	Does not include "enum" types
.DESCRIPTION
	Display a list of the objects in the "EMC" namespace in the current context
	Does not include "enum" types

.EXAMPLE
	Show-EMCAvailableTypes
	
IsPublic IsSerial Name                               BaseType
-------- -------- ----                               --------
True     False    IExBase
True     False    IExFolder
True     False    IExVector
True     False    CoExVector
True     False    CoExVectorClass                    System.__ComObject
True     False    IExMap
True     False    CoExMap
True     False    CoExMapClass                       System.__ComObject

#>
[CmdletBinding()]
Param( )

BEGIN{
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

PROCESS
{

	get-type -Namespace EMC* | where {$_.BaseType -ne [System.Enum]} |ft -AutoSize | Out-String -Width 10000


}

END {}
}


function Get-Type {
    <#
    .SYNOPSIS
        Get exported types in the current session

    .DESCRIPTION
        Get exported types in the current session

    .PARAMETER Module
        Filter on Module.  Accepts wildcard

    .PARAMETER Assembly
        Filter on Assembly.  Accepts wildcard

    .PARAMETER FullName
        Filter on FullName.  Accepts wildcard
    
    .PARAMETER Namespace
        Filter on Namespace.  Accepts wildcard
    
    .PARAMETER BaseType
        Filter on BaseType.  Accepts wildcard

    .PARAMETER IsEnum
        Filter on IsEnum.

    .EXAMPLE
        #List the full name of all Enums in the current session
        Get-Type -IsEnum $true | Select -ExpandProperty FullName | Sort -Unique

    .EXAMPLE
        #Connect to a web service and list all the exported types
            
        #Connect to the web service, give it a namespace we can search on
            $weather = New-WebServiceProxy -uri "http://www.webservicex.net/globalweather.asmx?wsdl" -Namespace GlobalWeather

        #Search for the namespace
            Get-Type -NameSpace GlobalWeather
        
            IsPublic IsSerial Name                                     BaseType                                                                                                                                                                         
            -------- -------- ----                                     --------                                                                                                                                                                         
            True     False    MyClass1ex_net_globalweather_asmx_wsdl   System.Object                                                                                                                                                                    
            True     False    GlobalWeather                            System.Web.Services.Protocols.SoapHttpClientProtocol                                                                                                                             
            True     True     GetWeatherCompletedEventHandler          System.MulticastDelegate                                                                                                                                                         
            True     False    GetWeatherCompletedEventArgs             System.ComponentModel.AsyncCompletedEventArgs                                                                                                                                    
            True     True     GetCitiesByCountryCompletedEventHandler  System.MulticastDelegate                                                                                                                                                         
            True     False    GetCitiesByCountryCompletedEventArgs     System.ComponentModel.AsyncCompletedEventArgs   

    .FUNCTIONALITY
        Computers
	.NOTES
		Adapted from:
		https://gallery.technet.microsoft.com/scriptcenter/Get-Type-Get-exported-fee19cf7
    #>
    [cmdletbinding()]
    param(
        [string]$Module = '*',
        [string]$Assembly = '*',
        [string]$FullName = '*',
        [string]$Namespace = '*',
        [string]$BaseType = '*',
        [switch]$IsEnum
    )
    
    #Build up the Where statement
        $WhereArray = @('$_.IsPublic')
        if($Module -ne "*"){$WhereArray += '$_.Module -like $Module'}
        if($Assembly -ne "*"){$WhereArray += '$_.Assembly -like $Assembly'}
        if($FullName -ne "*"){$WhereArray += '$_.FullName -like $FullName'}
        if($Namespace -ne "*"){$WhereArray += '$_.Namespace -like $Namespace'}
        if($BaseType -ne "*"){$WhereArray += '$_.BaseType -like $BaseType'}
        #This clause is only evoked if IsEnum is passed in
        if($PSBoundParameters.ContainsKey("IsEnum")) { $WhereArray += '$_.IsENum -like $IsENum' }
    
    #Give verbose output, convert where string to scriptblock
        $WhereString = $WhereArray -Join " -and "
        $WhereBlock = [scriptblock]::Create( $WhereString )
        Write-Verbose "Where ScriptBlock: { $WhereString }"

    #Invoke the search!
        [AppDomain]::CurrentDomain.GetAssemblies() | ForEach-Object {
            Write-Verbose "Getting types from $($_.FullName)"
            Try
            {
                $_.GetExportedTypes()
            }
            Catch
            {
                Write-Verbose "$($_.FullName) error getting Exported Types: $_"
                $null
            }

        } | Where-Object -FilterScript $WhereBlock
}

function Get-EnumValues {  
     <#
    .SYNOPSIS
        Return list of names and values for an enumeration object
     
    .DESCRIPTION
        Return list of names and values for an enumeration object
     
    .PARAMETER Type
        Pass in an actual type, or a string for the type name.
    .EXAMPLE
        Get-EnumValues system.dayofweek
    .EXAMPLE
        [System.DayOfWeek] | Get-EnumValues
     .FUNCTIONALITY
        General Command
	.NOTES
	Adapted from
	https://gist.github.com/RamblingCookieMonster/3e01f840e4160136523d#file-get-enumvalues-ps1

    #>
    [cmdletbinding()]
    param(
        [parameter( Mandatory = $True,
                    ValueFromPipeline = $True,
                    ValueFromPipelineByPropertyName = $True)]
        [Alias("FullName")]
        $Type
    )

    Process
    {
        [enum]::getvalues($type) |
            Select @{name="Type";  expression={$Type.ToString()}},
                   @{name="Name";  expression={$_.ToString()}},
                   @{name="Value"; expression={$_.value__}}
    }
}


Export-ModuleMember -Function Show-EMCAvailableTypes, Show-EMCEnums,Add-ES1Types,Show-ES1COMObjects

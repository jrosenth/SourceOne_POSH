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
		Functions and objects for S1 Mapped (business) Folders

#>

<#
.SYNOPSIS
	Creates a new mapped folder.  No permissions are applied
.DESCRIPTION
	Creates a new mapped folder.  No permissions are applied

.PARAMETER MappedFolder
	New mapped folder name
.PARAMETER Description
	Description for the new mapped folder
.PARAMETER ArchiveName
	Archive connection name of archive containing the the ArchiveFolderPath
.PARAMETER ArchiveFolderPath
	The path of the archive folder to associated with the mapped folder
.PARAMETER MappedType
	The type of the mapped folder, "Organization","Community","LegalHold", "Personal" are valid
	values.  Only "Organization" is supported at this time.

.EXAMPLE
	
#>
function New-ES1MappedFolder
{
[CmdletBinding()]
PARAM( [Parameter(Mandatory=$true)]
		[string] $MappedFolder,
		[Parameter(Mandatory=$false)]
		[string] $Description,
		[Parameter(Mandatory=$true)]
		[Alias('archive')]
		[string] $ArchiveName,		
		[Parameter(Mandatory=$true)]
		[string] $ArchiveFolderPath,
		[Parameter(Mandatory=$true)]
        [ValidateSet ("Organization","Community","LegalHold", "Personal")]
		[string] $MappedType

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
		$providerGW=new-object -comobject ExProviderGW.CoExProviderGW
		
		$s1Archive = Get-ES1ArchiveConnection -ArchiveName $ArchiveName

		$fmgr=$providergw.GetFolderMgr()
		$fmgr.SetTraceInfo($Global:S1LogFile)
		[EMC.Interop.ExBase.exBusinessFolderType] $folderType = [EMC.Interop.ExBase.exBusinessFolderType]::exBusinessFolderType_Unknown

		switch ($MappedType)
		{
			Organization
			{
				$folderType = [EMC.Interop.ExBase.exBusinessFolderType]::exBusinessFolderType_Organization
			}

			default 
			{
				throw "Unsupported folder type $($MappedType)"
			}

		}

		$mappedFldr=$fmgr.CreateFolder( $folderType) 
    
		$mappedFldr.FolderId = -1
		$mappedFldr.Name = $MappedFolder
		$mappedFldr.RepositoryName= $ArchiveName
		$mappedFldr.ProviderConfigID = $s1Archive.ID
		$mappedFldr.ArchiveFolderPath = $ArchiveFolderPath
		$mappedFldr.Description  = $Description

		$results= $mappedFldr.Validate()

		# Validation errors are in the results
		foreach ($valResult in $results)
		{
				# Check the "IsWarning" attibute, false means fatal error
				if ($valResult.IsWarning -eq $false)
				{
					throw $valResult.errorDescription
				}
    
		}
    
		$mappedFldr.Save()

	}
	catch {
		Write-Error $_
	}

}

END{}

}

<#
.SYNOPSIS
	Gets mapped folder or folders
.DESCRIPTION
	Gets mapped folder or folders

.PARAMETER MappedFolder
	Optional, if provided the name of mapped folder to get.

.EXAMPLE
	
#>
function Get-ES1MappedFolder
{
[CmdletBinding()]
PARAM( [Parameter(Mandatory=$false)]
		[string] $MappedFolder

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
		$providerGW=new-object -comobject ExProviderGW.CoExProviderGW
		
		$fmgr=$providergw.GetFolderMgr()
		$fmgr.SetTraceInfo($Global:S1LogFile)

		if ($MappedFolder)
		{
			$mappedFolders = $fmgr.FindFolderByName($MappedFolder)
		}
		else
		{
			$mappedFolders = $fmgr.EnumerateFolders([EMC.Interop.ExProviderGW.eFolderInfoLevel]::FolderEverything, 
                                            [EMC.Interop.ExBase.exBusinessFolderType]::exBusinessFolderType_All)
		}

		$mappedFolders
	}
	catch {
		Write-Error $_
	}

}

END{}

}



Export-ModuleMember -Function * -Alias *



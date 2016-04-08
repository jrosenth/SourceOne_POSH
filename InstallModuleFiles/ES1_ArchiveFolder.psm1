<#	
	.NOTES
	===========================================================================
	 Created by:   	jrosenthal
	 Organization: 	EMC Corp.
	 Filename:     	# ES1_ArchiveFolder.psm1
	
	Copyright (c) 2016 EMC Corporation.  All rights reserved.
	===========================================================================
	THIS CODE AND INFORMATION IS PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND,
	WHETHER EXPRESSED OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE IMPLIED
	WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A PARTICULAR PURPOSE.
	IF THIS CODE AND INFORMATION IS MODIFIED, THE ENTIRE RISK OF USE OR RESULTS IN
	CONNECTION WITH THE USE OF THIS CODE AND INFORMATION REMAINS WITH THE USER. 

	.DESCRIPTION
		Functions and objects for creating S1 Archive (backend) Folders

#>


function New-ES1ArchiveFolderOptions
{
<#
.SYNOPSIS
	Returns a helper object containing many default Archive folder options
.DESCRIPTION

.OUTPUTS

.EXAMPLE

#>
[CmdletBinding()]
PARAM( [Parameter(Mandatory=$true)]
		[Alias('archive')]
		[string] $ArchiveName,		
		[Parameter(Mandatory=$false)]
		[Alias('name')]
		[string] $FolderName,
		[Parameter(Mandatory=$false)]
		[Alias('container')]
		[string] $ContainerLocation,
		[Parameter(Mandatory=$false)]
		[Alias('index')]
		[string] $IndexLocation

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

		# get script location
		$scriptDirectory = Split-Path $myinvocation.mycommand.path
		$folderDefaults = join-path $scriptDirectory 'folderdefaults.xml'

	try {
	     # Make sure the input file exists...
        if (!(Test-Path -path $folderDefaults) )
        {
            throw "Folder default settings file not found: $folderDefaults"
        }

        [System.Xml.XmlDocument] $settingsxml = new-object System.Xml.XmlDocument

        $settingsxml.load($folderDefaults)      
  
		$GeneralSettings = $settingsxml.SelectSingleNode('/ES1FolderDefaults/ArchiveFolder/General')

		$asmgr = new-object -ComObject ExAsAdminAPI.CoExASAdminAPI

		$asmgr.Initialize()

		$repo = $asmgr.GetRepository($ArchiveName)

		$backendFolder = $repo.CreateNewObject([EMC.Interop.ExAsAdminAPI.exASObjectType]::exASObjectType_ArchiveFolder)

		$backendFolder.FullPath = $FolderName
		$backendFolder.ContainerLocation = $ContainerLocation
		$backendFolder.IndexLocation = $IndexLocation
		$backendFolder.ContentCache = [System.Convert]::ToBoolean($GeneralSettings.ContentCache)
		$backendFolder.MaxIndexSize = [System.Convert]::ToInt32($GeneralSettings.MaxIndexSize)
		$backendFolder.FullTextEnabled = [System.Convert]::ToBoolean($GeneralSettings.FullTextEnabled)
		$backendFolder.MaxVolumeSize = [System.Convert]::ToInt32($GeneralSettings.MaxVolumeSize)
		$backendFolder.AttachmentIndexing = [System.Convert]::ToBoolean($GeneralSettings.AttachmentIndexing)
		
		#$backendFolder.ConceptBasedFolderType = ConceptType
		#$backendFolder.StorageType = [EMC.Interop.ExASBaseAPI.exASFolderStorageType]::exASStorageType_NASContainer
		
		# release the repo object
		[System.Runtime.Interopservices.Marshal]::ReleaseComObject($repo) > $null

		$backendFolder
	}
	catch{
		Write-Error $_ 
		throw $_
	}
}

END {}


}

function Create-ES1NASArchiveFolder
{
<#
.SYNOPSIS
	Creates a new "NAS Container" type of archive folder
.DESCRIPTION

.OUTPUTS

.EXAMPLE

#>
[CmdletBinding()]
PARAM( [Parameter(Mandatory=$true)]
		[Alias('archive')]
		[string] $ArchiveName,		
		[Parameter(Mandatory=$false)]
		[Alias('name')]
		[string] $FolderName,
		[Parameter(Mandatory=$false)]
		[Alias('container')]
		[string] $ContainerLocation,
		[Parameter(Mandatory=$false)]
		[Alias('index')]
		[string] $IndexLocation

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
		$newfolder = New-ES1ArchiveFolderOptions -ArchiveName $ArchiveName -FolderName $FolderName -ContainerLocation $ContainerLocation `
							-IndexLocation $IndexLocation 

		$newfolder.StorageType = [EMC.Interop.ExASBaseAPI.exASFolderStorageType]::exASStorageType_NASContainer

		$newfolder.Save()

		#$asmgr = new-object -ComObject ExAsAdminAPI.CoExASAdminAPI

		#$asmgr.Initialize()

		#$repo = $asmgr.GetRepository($ArchiveName)

		
		}
 
 catch {
		Write-Error $_ 
		}

}
END {}

}




Export-ModuleMember -Function * -Alias *

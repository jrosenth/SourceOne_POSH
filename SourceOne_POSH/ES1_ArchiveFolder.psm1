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
		Functions and objects for creating S1 Archive (backend) Folders

#>


function New-ES1ArchiveFolderOptions
{
<#
.SYNOPSIS
	Returns a helper object containing many default Archive folder options
.DESCRIPTION
	Returns a helper object containing many default Archive folder options.  
	The helper wraps the [EMC.Interop.ExAsAdminAPI.exASObjectType]::exASObjectType_ArchiveFolder object.
	The default options	can be modified/changed by changing the values in the folderdefaults.xml located in the modules'
	directory
.OUTPUTS

.EXAMPLE
	$newfolder = New-ES1ArchiveFolderOptions -ArchiveName 'MyArchive' -FolderName '2Year' -ContainerLocation '\\S1MASTER7-J1\PBA' -IndexLocation '\\S1MASTER7-J1\IndexShare' 
#>
[CmdletBinding()]
PARAM( [Parameter(Mandatory=$true)]
		[Alias('archive')]
		[string] $ArchiveName,		
		[Parameter(Mandatory=$true)]
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

		# get script location, load defaults from it...
		$scriptDirectory  = Split-Path -parent $PSCommandPath
		$folderDefaults = join-path $scriptDirectory 'folderdefaults.xml'

	try {
	     # Make sure the input file exists...
        if (!(Test-Path -path $folderDefaults) )
        {
            throw "Folder default settings file not found: $folderDefaults"
        }

		# TODO - Optimize loading this only once, instead of every time called - Jay R.
		# Load the common/general folder defaults.
        [System.Xml.XmlDocument] $settingsxml = new-object System.Xml.XmlDocument
        $settingsxml.load($folderDefaults)        
		$GeneralSettings = $settingsxml.SelectSingleNode('/ES1FolderDefaults/ArchiveFolder/General')

		$asmgr = new-object -ComObject ExAsAdminAPI.CoExASAdminAPI

		$asmgr.Initialize()

		$repo = $asmgr.GetRepository($ArchiveName)

		$backendFolder = $repo.CreateNewObject([EMC.Interop.ExAsAdminAPI.exASObjectType]::exASObjectType_ArchiveFolder)
        $backendFolder.SetTraceInfo('SourceOne_POSH')

		$backendFolder.FullPath = $FolderName
		$backendFolder.ContainerLocation = $ContainerLocation
		$backendFolder.IndexLocation = $IndexLocation
		$backendFolder.ContentCache = [System.Convert]::ToBoolean($GeneralSettings.ContentCache)
		$backendFolder.MaxIndexSize = [System.Convert]::ToInt32($GeneralSettings.MaxIndexSize)
		$backendFolder.FullTextEnabled = [System.Convert]::ToBoolean($GeneralSettings.FullTextEnabled)
		$backendFolder.MaxVolumeSize = [System.Convert]::ToInt32($GeneralSettings.MaxVolumeSize)
		$backendFolder.AttachmentIndexing = [System.Convert]::ToInt32($GeneralSettings.AttachmentIndexing)  ## NOTE : 0 = enabled
		
		# Store content inside containers, set this to a size in KB for large content outside containers.
		$backendFolder.AttachmentSizeThreshold=-2      
		
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


function New-ES1NASArchiveFolder
{
<#
.SYNOPSIS
	Creates a new "NAS Container" type of archive folder.
	Note: Parameter validation may not be identical to the SourceOne Administration GUI. 
.DESCRIPTION
	Creates a new "NAS Container" type of archive folder
	Note: Parameter validation may not be identical to the SourceOne Administration GUI. 
.OUTPUTS

.EXAMPLE
	New-ES1NASArchiveFolder -Archivename Archive1 -FolderName 'NewFolder' -ContainerLocation '\\S1MASTER7-J1\xxx' -IndexLocation '\\S1MASTER7-J1\IndexShare'
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
		$newfolder = New-ES1ArchiveFolderOptions -ArchiveName $ArchiveName -FolderName $FolderName -ContainerLocation $ContainerLocation -IndexLocation $IndexLocation 

		$newfolder.StorageType = [EMC.Interop.ExASBaseAPI.exASFolderStorageType]::exASStorageType_NASContainer

        try{
            
            $validation = $newfolder.Validate()
            
            foreach ($result in $validation)
            {
                if ($result.IsWarning )
                {
                    Write-Warning "$($result.errorDescription)"
                }
                else
                {
                    throw "$($result.errorDescription)"
                }
            }

            $newfolder.Save()
        }
        catch {
            throw $_
        }
        finally{
            [System.Runtime.Interopservices.Marshal]::ReleaseComObject($newfolder) > $null
        }
	
		
	}
 
 catch {
		Write-Error $_ 
		}

}
END {}

}


function New-ES1CenteraArchiveFolder
{
<#
.SYNOPSIS
	Creates a new "Centera Container" type of archive folder.
	Note: Parameter validation may not be identical to the SourceOne Administration GUI. 
.DESCRIPTION
	Creates a new "Centera Container" type of archive folder
	Note: Parameter validation may not be identical to the SourceOne Administration GUI. 

.EXAMPLE
	New-ES1CenteraArchiveFolder -Archivename Archive1 -FolderName 'Cent1' -pool '168.159.214.11' -IndexLocation '\\S1MASTER7-J1\IndexShare'
.EXAMPLE
	New-ES1CenteraArchiveFolder -Archivename Archive1 -FolderName 'Cent2' -pool '168.159.214.20;168.159.214.21;168.159.214.22' -CenteraPEAFile 'C:\temp\c2profile3.pea' -IndexLocation '\\S1MASTER7-J1\IndexShare' 
#>
[CmdletBinding()]
PARAM( [Parameter(Mandatory=$true)]
		[Alias('archive')]
		[string] $ArchiveName,		
		[Parameter(Mandatory=$false)]
		[Alias('name')]
		[string] $FolderName,
		[Parameter(Mandatory=$true)]
		[Alias('pool')]
		[string] $CenteraPool,
		[Parameter(Mandatory=$false)]
		[Alias('pea')]
		[string] $CenteraPEAFile,
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

	$ContainerLocation=''
    $peaString=''

 try {		

		if ($CenteraPEAFile.Length -gt 0)
		{
			 # Make sure the input file exists...
			if (!(Test-Path -path $CenteraPEAFile) )
			{
				throw "PEA file not found!: $CenteraPEAFile"
			}

			# Load the PEA file if one was given
			$peaString= Get-Content $CenteraPEAFile

		}
		# Get a new folder options object with many defaults already set
		$newfolder = New-ES1ArchiveFolderOptions -ArchiveName $ArchiveName -FolderName $FolderName -ContainerLocation $ContainerLocation `
							-IndexLocation $IndexLocation 

		# Set the storage container type
		$newfolder.StorageType = [EMC.Interop.ExASBaseAPI.exASFolderStorageType]::exASStorageType_CenteraContainer 
		$newfolder.CenteraPoolAddress=$CenteraPool

		if ($peaString.Length -gt 0)
		{
			$newfolder.CenteraPEAConfigString =$peaString
		}
		

        try{
            # Check the Centera connection info
            #     This will throw if it fails.
            $newfolder.TestCenteraConnection($CenteraPool, $peaString)

            # Validate the rest of the settings
            $validation=$newfolder.Validate()
            foreach ($result in $validation)
            {
                if ($result.IsWarning )
                {
                    Write-Warning "$($result.errorDescription)"
                }
                else
                {
                    throw "$($result.errorDescription)"
                }
            }

            # Everything is OK, Save it...
            $newfolder.Save()
        }
        catch {
            throw $_
        }
        finally{
            # Release this object cause we're done with it.
            [System.Runtime.Interopservices.Marshal]::ReleaseComObject($newfolder) > $null
        }
	}
 
 catch {
		Write-Error $_ 
		}

}
END {}

}


function Show-ES1ArchiveFolders
{
<#
.SYNOPSIS
	Displays all the properties of an Archive folder.
.DESCRIPTION
	Displays all the properties of an Archive folder.
.OUTPUTS

.EXAMPLE
	Show-ES1ArchiveFolders

#>
[CmdletBinding()]
PARAM( 	)


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

    try
    {
 
        $asmgr = new-object -ComObject ExAsAdminAPI.CoExASAdminAPI

        $asmgr.Initialize()

        $repos=$asmgr.EnumerateRepositories()

        foreach ($repo in $repos)
        {
            Write-Host "Archive Name: $($repo.Name)"
			Write-Host ""
            $folderplan=$repo.GetFolderPlan()
            $folders = $folderplan.EnumerateArchiveFolders()

            foreach ($folder in $folders)
            {
                Write-Host "Archive Folder: $($folder.FullPath)"
				Write-Host "Folder Properties"

                $folder | Format-List -Property *
    
            }
    
            [System.Runtime.Interopservices.Marshal]::ReleaseComObject($folderplan) > $null
            [System.Runtime.Interopservices.Marshal]::ReleaseComObject($repo) > $null

        }
    }
    catch 
    {
        throw $_
    }
    finally
    {
    }
}
END{}
}

function Get-ES1ArchiveFolder
{
<#
.SYNOPSIS
	Gets an instance of an existing Archive folder
.DESCRIPTION
	Gets an instance of an existing Archive folder

.EXAMPLE
	Get-ES1ArchiveFolder -ArchiveName Archive1 -FolderName 5Year
#>
[CmdletBinding()]
PARAM( [Parameter(Mandatory=$true)]
		[Alias('archive')]
		[string] $ArchiveName,		
		[Parameter(Mandatory=$false)]
		[Alias('name')]
		[string] $FolderName
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

		Write-Verbose "Archive Name: $($ArchiveName), Archive Folder: $($FolderName)"

	    $asmgr = new-object -ComObject ExAsAdminAPI.CoExASAdminAPI
		$asmgr.SetTraceInfo('SourceOne_POSH')
        $asmgr.Initialize()

		$repo=$asmgr.GetRepository($ArchiveName)
	    $repo.SetTraceInfo('SourceOne_POSH')
    
        $folderplan=$repo.GetFolderPlan()
		
        $folders = $folderplan.EnumerateArchiveFolders()

            foreach ($folder in $folders)
            {
			 if (($folder.Name -eq $FolderName) )
				{
					$retFolder = $folder
					break;
				}
            }
    
            [System.Runtime.Interopservices.Marshal]::ReleaseComObject($folderplan) > $null
            [System.Runtime.Interopservices.Marshal]::ReleaseComObject($repo) > $null

	}
 catch {
		Write-Error $_ 
		}

		$retFolder
}
END {}

}

function Get-ES1AllArchiveFolders
{
<#
.SYNOPSIS
	Gets a list all archive folders and their properties
.DESCRIPTION
	Gets a list all archive folders and their properties
.OUTPUTS

.EXAMPLE
	$folders=Get-ES1AllArchiveFolders

#>
[CmdletBinding()]
PARAM( 	)


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

    $allfolders=@()

    try
    {
 
        $asmgr = new-object -ComObject ExAsAdminAPI.CoExASAdminAPI

        $asmgr.Initialize()

        $repos=$asmgr.EnumerateRepositories()

        foreach ($repo in $repos)
        {
        
            $folderplan=$repo.GetFolderPlan()
            $folders = $folderplan.EnumerateArchiveFolders()

            $allfolders += $folders
    
            [System.Runtime.Interopservices.Marshal]::ReleaseComObject($folderplan) > $null
            [System.Runtime.Interopservices.Marshal]::ReleaseComObject($repo) > $null

        }
    }
    catch 
    {
        throw $_
    }
    finally
    {
    }

    $allfolders
}
END{}
}
<#
.SYNOPSIS
	Get a Archive folder summary information, similar to what is displayed in the MMC console
.DESCRIPTION
  Get a Archive folder summary information, similar to what is displayed in the MMC console
.OUTPUTS

.EXAMPLE

#>
Function Get-ArchiveFolderSummaryInfo
{
	[CmdletBinding()]
	PARAM ()
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

    $allfolders=@()

    try
    {
        $asmgr = new-object -ComObject ExAsAdminAPI.CoExASAdminAPI
        $asmgr.Initialize()
    
		$repos=$asmgr.EnumerateRepositories()

        foreach ($repo in $repos)
        {
        
            $folderplan=$repo.GetFolderPlan()
            $folders = $folderplan.EnumerateArchiveFolders()
			
			# change the properies to be like the MMC display
			$folderSummary = $folders | Select Name, @{name="Volumes"; Expression = {$_.TotalVolumes}},`
                                        @{name="Volume Items"; Expression = {$_.TotalMsgInVolumes}},`
                                        @{name="Volume Size(MB)"; Expression = {$_.TotalSizeInVolumes}}, `
                                        @{name="Indexes"; Expression = {$_.TotalIndexes}},`
                                        @{name="Index Items"; Expression = {$_.TotalMsgInIndexes}},`
                                        @{name="Index Size(MB)"; Expression = {$_.TotalSizeInIndexes}},`                                       
                                        @{name="Errors"; Expression = {$_.FPErrorCount}}

            # put the archive name on each item, so consumers have context											
			$folderSummary | Add-Member NoteProperty -Name "Archive" -Value $repo.Name
            $allfolders += $folderSummary
    
            [System.Runtime.Interopservices.Marshal]::ReleaseComObject($folderplan) > $null
            [System.Runtime.Interopservices.Marshal]::ReleaseComObject($repo) > $null

        }
    }
    catch 
    {
        throw $_
    }
    finally
    {
    }

    $allfolders
}
END{}
}

<#
.SYNOPSIS
	Get the monthly totals of an Archive folder, similar to what is displayed in the MMC console when the
	folder is expanded.

.DESCRIPTION
	Get the monthly totals of an Archive folder, similar to what is displayed in the MMC console when the
	folder is expanded.
  
.OUTPUTS

.EXAMPLE

#>
Function Get-ArchiveFolderMonthlyInfo
{
	[CmdletBinding()]
	PARAM (
	 [Parameter(Mandatory=$false)]
		[Alias('archive')]
		[string] $ArchiveName,		
		[Parameter(Mandatory=$false)]
		[Alias('name')]
		[string] $FolderName)
BEGIN {
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
	$asmgr = new-object -ComObject ExAsAdminAPI.CoExASAdminAPI

	$asmgr.Initialize()

	#  If an archive was specified get only that one
	if ($ArchiveName)
	{
		$repos=@($asmgr.GetRepository($ArchiveName))
	}
	else
	{
		# Get a list of ALL the repositories/archives
		$repos=$asmgr.EnumerateRepositories()
	}
	    
	
	# Loop through the repositories/archives, getting the folders and months 
	$MonthsSummary=@()

	foreach ($repo in $repos)
	{
   
		$repo.SetTraceInfo('SourceOne_POSH')

		$folderplan=$repo.GetFolderPlan()
		$folders = $folderplan.EnumerateArchiveFolders()

		foreach ($folder in $folders)
		{
			# If foldername is specified get only the info for that folder
			if ($FolderName  -and ($folder.Name -ne $FolderName) )
			{
				continue;
				
			}

			$containerfolders=@()
			$containerfolders=$folder.EnumerateContainerFolders()

			# change the properies to be like the MMC display
			$MonthsSummary += $containerfolders | Select @{name="Archive"; Expression = {$repo.Name}}, `
								@{name="Folder"; Expression = {$folder.Name}}, `
                                Name, `
                                @{name="Volumes"; Expression = {$_.TotalVolumes}},`
                                @{name="Volume Items"; Expression = {$_.TotalMsgInVolumes}},`
                                @{name="Volume Size(MB)"; Expression = {$_.TotalSizeInVolumes}}, `
                                @{name="Indexes"; Expression = {$_.TotalIndexes}},`
                                @{name="Index Items"; Expression = {$_.TotalMsgInIndexes}},`
                                @{name="Index Size(MB)"; Expression = {$_.TotalSizeInIndexes}},`                                       
                                @{name="Errors"; Expression = {$_.FPErrorCount}}
  
		}
		
	   [System.Runtime.Interopservices.Marshal]::ReleaseComObject($folderplan) > $null
	   [System.Runtime.Interopservices.Marshal]::ReleaseComObject($repo) > $null
	  }
  
	  
	  $MonthsSummary  
}
END {}
}


New-Alias GetS1ArchiveFolder Get-ES1ArchiveFolder
New-Alias Get-ArchiveFolderSummary Get-ArchiveFolderSummaryInfo

Export-ModuleMember -Function * -Alias *

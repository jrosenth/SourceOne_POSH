######################################################################################
#
#	 
#	Copyright © 2018 Dell Inc. or its subsidiaries. All Rights Reserved.
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#	       http://www.apache.org/licenses/LICENSE-2.0
#  
# THIS CODE AND INFORMATION IS PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND,
# WHETHER EXPRESSED OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A PARTICULAR PURPOSE.
# IF THIS CODE AND INFORMATION IS MODIFIED, THE ENTIRE RISK OF USE OR RESULTS IN
# CONNECTION WITH THE USE OF THIS CODE AND INFORMATION REMAINS WITH THE USER. 
#
######################################################################################
#
# Module manifest for module 'SourceOne_POSH'
#
#

@{

# Script module or binary module file associated with this manifest
ModuleToProcess = ''

# Version number of this module.
ModuleVersion ='4.0.3.11'

# ID used to uniquely identify this module
GUID = 'ef4dde55-52fe-4856-8e2e-c3affafbe4fe'

# Author of this module
Author = 'Jay Rosenthal'

# Company or vendor of this module
CompanyName = 'Dell Inc.'

# Copyright statement for this module
Copyright = '(c) 2015-2018 Dell Inc. or its subsidiaries. All Rights Reserved'

# Description of the functionality provided by this module
Description = 'EMC SourceOne management and configuration in PowerShell.'

# Minimum version of the Windows PowerShell engine required by this module
PowerShellVersion = '4.0'

# Name of the Windows PowerShell host required by this module
PowerShellHostName = ''

# Minimum version of the Windows PowerShell host required by this module
PowerShellHostVersion = ''

# Minimum version of the .NET Framework required by this module
DotNetFrameworkVersion = '4.0'

# Minimum version of the common language runtime (CLR) required by this module
CLRVersion = ''

# Processor architecture (None, X86, Amd64, IA64) required by this module
ProcessorArchitecture = 'X86'

# Modules that must be imported into the global environment prior to importing this module
RequiredModules = @()

# Assemblies that must be loaded prior to importing this module
RequiredAssemblies = @()

# Script files (.ps1) that are run in the caller's environment prior to importing this module
ScriptsToProcess = @()

# Type files (.ps1xml) to be loaded when importing this module
TypesToProcess = @()

# Format files (.ps1xml) to be loaded when importing this module
FormatsToProcess = @()

# Modules to import as nested modules of the module specified in ModuleToProcess
NestedModules = @('ES1_SQLFuncs.psm1','ES1_DBUtils.psm1', `
    'ES1POSH_HelperUtils.psm1', 'ES1_Policy.psm1', 'ES1_GCWorkaround.psm1', 'ES1_Configuration.psm1', `
	'ES1_Services.psm1', 'ES1_Jobs.psm1','ES1_ObjectsAndTypes.psm1','ES1_ArchiveFolder.psm1', `
	'ES1_SuspendResume.psm1','ES1_MasterRoleUtils.psm1', `
	'ExternalUtils.psm1', 'ES1_WorkerRolesUtils.psm1', 'ES1_HealthChecks.psm1', 'ES1_VolumeHealth.psm1', `
	'ES1_IndexHealth.psm1','ES1_HTML.psm1', 'ES1_ArchiveConfiguration.psm1', 'ES1_VolumeUtils.psm1' ,`
	'ES1_IndexUtils.psm1','ES1_MappedFolder.psm1')

# Functions to export from this module
FunctionsToExport = '*'

# Cmdlets to export from this module
CmdletsToExport = '*'

# Variables to export from this module
VariablesToExport = '*'

# Aliases to export from this module
AliasesToExport = '*'

# List of all modules packaged with this module
ModuleList = @()

# List of all files packaged with this module
FileList = @('ES1_SQLFuncs.psm1', 'SourceOne_POSH.psd1', `
	'ES1_DBUtils.psm1','ES1POSH_HelperUtils.psm1',`
	'ES1_Policy.psm1','ES1_GCWorkaround.psm1','ES1_Configuration.psm1', 'ES1_Services.psm1','ES1_Jobs.psm1', `
	'ES1_ObjectsAndTypes.psm1','ES1_ArchiveFolder.psm1','folderdefaults.xml','ES1_SuspendResume.psm1', `
	'ES1_MasterRoleUtils.psm1','ExternalUtils.psm1','ES1_WorkerRolesUtils.psm1','ES1_HealthChecks.psm1', `
	'ES1_VolumeHealth.psm1', 'ES1_IndexHealth.psm1','ES1_HTML.psm1','ES1_DefaultCSS.txt', `
	'ES1_ArchiveConfiguration.psm1','ES1_VolumeUtils.psm1','ES1_IndexUtils.psm1','ES1_MappedFolder.psm1')

# Private data to pass to the module specified in ModuleToProcess
PrivateData = @{
    PSData = @{

        # Tags applied to this module. These help with module discovery in online galleries.
		# (tags cannot have spaces !) 
        Tags = @('.net','EMC','Dell','SourceOne','EmailManagment')

        # A URL to the license for this module.
        LicenseUri = 'http://www.apache.org/licenses/LICENSE-2.0'
		# A URL to the main website for this project.
		ProjectUri = 'https://github.com/jrosenth/SourceOne_POSH'
		}
	}
}


<#	
	.NOTES
	===========================================================================
	 Created by:   	jrosenthal
	 Organization: 	EMC Corp.
	 Filename:     	ES1_WorkerRoleUtils.psm1
	
	Copyright (c) 2015-2016 EMC Corporation.  All rights reserved.
	Copyright (c) 2015-2017 Dell Technologies.  All rights reserved.
	===========================================================================
	THIS CODE AND INFORMATION IS PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND,
	WHETHER EXPRESSED OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE IMPLIED
	WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A PARTICULAR PURPOSE.
	IF THIS CODE AND INFORMATION IS MODIFIED, THE ENTIRE RISK OF USE OR RESULTS IN
	CONNECTION WITH THE USE OF THIS CODE AND INFORMATION REMAINS WITH THE USER. 

	.DESCRIPTION
		Functions for inspecting or getting "Worker" machine related stuff

#>

#requires -Version 4

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
						(	(	$taskType.state -band [int][EMC.Interop.ExBase.exPluginState]::exPluginState_NotAdminDisplayable) -eq $false)) -or ` # hide internal types
					(		[int][EMC.Interop.ExBase.exCoreTaskTypes]::exCoreTaskTypes_Query -eq $taskType.id ) -or `
					(		[int][EMC.Interop.ExBase.exCoreTaskTypes]::exCoreTaskTypes_RestoreJBC -eq $taskType.id ) -or `
					(		[int][EMC.Interop.ExBase.exCoreTaskTypes]::exCoreTaskTypes_DeleteFromArchiveJBC -eq $taskType.id ) -or `
					(		[int][EMC.Interop.ExBase.exCoreTaskTypes]::exCoreTaskTypes_DCQuery -eq $taskType.id ) -or `
					(		[int][EMC.Interop.ExBase.exCoreTaskTypes]::exCoreTaskTypes_Restoration -eq $taskType.id ) -or `
					(		[int][EMC.Interop.ExBase.exCoreTaskTypes]::exCoreTaskTypes_FileRestoreJBC-eq $taskType.id ) -or `
					(		[int][EMC.Interop.ExBase.exCoreTaskTypes]::exCoreTaskTypes_SharePointRestoreJBC -eq $taskType.id ) 
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


function Get-ES1WorkerInfo {
<#
.SYNOPSIS
	Gets and array of SourceOne worker objects and their roles.
.DESCRIPTION
	Gets and array of SourceOne worker objects and their roles.

.EXAMPLE

#>
	[CmdletBinding()]
	param ()

	BEGIN{
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
	PROCESS{
	$retList = @()

	Write-Verbose "SeverRoles for display:  $($global:RoleDisplayNames.Count)"

	$Workers = @()

		$jdfapiMgr = new-object -comobject ExJDFAPI.CoExJDFAPIMgr.1

		$workergroups = @($jdfapiMgr.GetWorkerGroups())
		$Workers = @($jdfapiMgr.GetWorkers())

		# Add some new columns
		$Workers | Add-Member NoteProperty -Name "WorkerGroup" -Value ""
		$Workers | Add-Member NoteProperty -Name "EnabledRoles" -Value ""

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


			$cfgs = @()
			$tasks = @()

			$cfgs = @($worker.taskCfgs)
			$allCfgs = @($worker.taskCfgs)

			$cfgs = @(Get-ES1EnabledWorkerRoles $cfgs)
			$cfgIndex = 0
				$cfgs = @(Get-ES1EnabledWorkerRoles $cfgs)
			$cfgIndex = 0
            $roles = $cfgs | Select tasktypename
            #$roles | foreach { $_.taskTypeName = $_.taskTypeName -join ', ' }

			$worker.EnabledRoles = $roles
        
            $worker | foreach {$_.EnabledRoles = $_.EnabledRoles.taskTypeName -join ', '}

		}

		[System.Runtime.Interopservices.Marshal]::ReleaseComObject($jdfapiMgr) > $null

		# return only relavent stuff and pretty some numeric enums
		#  TODO - maybe I shouldnt be changing the enums here ??  
		$Workers | Select Name, WorkerGroup, startTime, lastActive,jobQuota, jobPollTime,
                   @{name="State"; Expression = { ([EMC.Interop.ExJDFAPI.exJDFWorkerState]$_.state).ToString().Substring(17) }},
                   @{name = "Action"; Expression = { ([EMC.Interop.ExJDFAPI.exJDFWorkerAction]$_.action).ToString().Substring(18) }},
                   EnabledRoles

	}
	
	
	END{}

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
		
		[System.Runtime.Interopservices.Marshal]::ReleaseComObject($jdfapiMgr) > $null
	}

	end {}


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
   Get-ES1Workers
.DESCRIPTION
   Retrieve the names of all SourceOne workers from SQL
.OUTPUT
Sets Session array $s1Workers
.EXAMPLE
   Get-ES1Workers
   
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

# $s1actSErver $S1Actdb are exported from another module and set by the Get-ES1ActivityObj call above

$dtResults = Invoke-ES1SQLQuery $s1actSErver $S1Actdb $sqlQuery
$Script:s1Workers = $dtResults
$dtResults

}

New-Alias Get-S1WorkerNameFromID Get-ES1WorkerNameFromID
New-Alias Get-S1Workers Get-ES1Workers

Export-ModuleMember -Function * -Alias *
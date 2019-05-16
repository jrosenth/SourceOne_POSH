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
		Functions and objects for managing volumes (containers) in a folder

#>

<#
.SYNOPSIS
	Issue a Close command to open volume(s) in the archive and folder specified
.DESCRIPTION
	Issue a Close command to open volume(s) in the archive and folder specified.
	The process of closing and "burning" the volume is handled by archive servers on a scheduled basis.  The completion of the close
	operation could take some time.
	A warning is issued if there are are active policies and activities as those may cause unexpected results.

.PARAMETER ArchiveName
	The name of the archive connection 

.PARAMETER ArchiveFolder
	Optional , if provided only volumes in this folder will be closed.

.OUTPUTS
	List of volumes which were closed

.EXAMPLE
	$closed = Close-ES1Volume -ArchiveName Archive1 -ArchiveFolder 5Year
#>
Function Close-ES1Volume {
[CmdletBinding(SupportsShouldProcess=$true,
			   ConfirmImpact=’High’)]
PARAM( [Parameter(Mandatory=$true)]
		[Alias('archive')]
		[string] $ArchiveName,		
		[Parameter(Mandatory=$false)]
		[Alias('name')]
		[string] $ArchiveFolder
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
	$asmgr = new-object -ComObject ExAsAdminAPI.CoExASAdminAPI
	$asmgr.SetTraceInfo($Global:S1LogFile)
	$asmgr.Initialize()

    $closedVolumes=@()
	[System.Runtime.InteropServices.UnknownWrapper]$nullWrapper = New-Object "System.Runtime.InteropServices.UnknownWrapper" -ArgumentList @($null);

	# Check for active Policy and  activities that could conflict with a close
    $activities = Get-ES1Activities 
    [bool] $activePolicy=$false

    foreach ($activity in $activities)
    {
        
        if ($activity.state -eq [EMC.Interop.ExBase.exActivityState]::exActivityState_Active)
        {
            Write-Warning "Policy: $($activity.Policy), Activity: $($activity.Name) is Active."
            $activePolicy=$true
        }
    }

    if ($activePolicy -and (-not ($pscmdlet.ShouldContinue( "Closing volumes with active Policies may have undesired effects.  Continue ?", "Activity Still Active !"))))
    {

        break;            
    }

	try {
		# Get the volume flag enumeration strings/names
		$volStates=[enum]::GetNames([EMC.Interop.ExAsBaseAPI.exASVolumeFlags])

		$repo=$asmgr.GetRepository($ArchiveName)
	    $repo.SetTraceInfo($Global:S1LogFile)
    
        $folderplan=$repo.GetFolderPlan()
        $folders = @($folderplan.EnumerateArchiveFolders())

		# If an archive folder was specified only process that one...
		if ($ArchiveFolder )
		{
            foreach ($folder in $folders)
            {
			 if (($folder.Name -eq $ArchiveFolder) )
				{
					$folders = @($folder)
					break;
				}
            }
		}

		
		foreach ($folder in $folders)
		{
			$containerfolders=$folder.EnumerateContainerFolders()
			foreach ($cf in $containerfolders)
			{
				$cf.SetTraceInfo($Global:S1LogFile)

				$volumes=$cf.EnumerateVolumes($nullWrapper)

				# loop through all the volumes and if it is open then close it.
				foreach($volume in $volumes)
				{
					$roles = @()
               		for ($i = 0 ; $i -lt ($volStates.Length); $i++)
					{
						[int] $bits = [EMC.Interop.ExAsBaseAPI.exASVolumeFlags]$volStates[$i]

						if ($volume.Flags -band $bits)
						{
							$roles += ([EMC.Interop.ExAsBaseAPI.exASVolumeFlags]$volStates[$i]).ToString().Substring(14)
						}

					}

					Write-Verbose "Volume: $($volume.UNCPath) FolderID: $($volume.FolderID) Flags: $($volume.Flags) $($roles) "

					# if the volume is not "RecordPending" and its not "Closed", close it
					if (($volume.Flags -band [EMC.Interop.ExAsBaseAPI.exASVolumeFlags]::exASVolumeFlagRecordPending) -and `
						((-not ($volume.Flags -band [EMC.Interop.ExAsBaseAPI.exASVolumeFlags]::exASVolumeFlagClosed))) )
					{
							Write-Verbose "Issueing Close Volume: $($volume.UNCPath) Flags: $($volume.Flags) $($roles) "
                            
                            if ($pscmdlet.ShouldProcess($volume.VolumeName)) 
							{
                                $folderplan.CloseVolume($volume.FolderID, $volume.VolumeName)
                                $closedVolumes += $volume
                            }
                
					}
					elseif (($volume.Flags -band [EMC.Interop.ExAsBaseAPI.exASVolumeFlags]::exASVolumeFlagRecordPending) -or `
							($volume.Flags -band [EMC.Interop.ExAsBaseAPI.exASVolumeFlags]::exASVolumeFlagActiveRecording) )
					{   
                
						# Display a volume is "RecordPending" or "ActiveRecording"
						Write-Verbose "Close in progress Volume: $($volume.UNCPath) FolderID: $($volume.FolderID) Flags: $($volume.Flags), $($roles)"

					}
				}          

			}
    
		}
			
		}
		catch 
		{
			Write-Error $_
		}
		finally
		{
			[System.Runtime.Interopservices.Marshal]::ReleaseComObject($folderplan) > $null
			[System.Runtime.Interopservices.Marshal]::ReleaseComObject($repo) > $null
		}
      
      $closedVolumes
}
END {}
}

<#
.SYNOPSIS
	Get a list of volumes in the given state(s) from the archive and folder specified
.DESCRIPTION
	Get a list of volumes in the given state(s) from the archive and folder specified
	The input States are some convenience states to simplify the various combinations and interpretation of the 
	[EMC.Interop.ExAsBaseAPI.exASVolumeFlags] values.  The VolumeFlags are bitmask represented by those state flags,
	some of which are transient states.

.PARAMETER ArchiveName
	The name of the archive connection 

.PARAMETER ArchiveFolder
	Optional , if provided only volumes in the folder and requested states will be returned

.PARAMETER States
	List of states.  The States correlate to some common combinations of the [EMC.Interop.ExAsBaseAPI.exASVolumeFlags]
	enum of the volume flag bits.
	OPEN     will return volumes with RecordPending bit set or Closed bit not set
	CLOSED   will return volumes with the Closed bit set
	PENDING  will return volumes with the RecordPending bit set
	FAILED   will return volumes with the FailedRecord bit set
	DELETED  will return volumes with any of the RemovalPending, DeletedFromSQL or DeletedFromStorage bits set.
.OUTPUTS
	List of volumes 

.EXAMPLE
	$openVolume = Get-ES1VolumeByState -ArchiveName Archive1 -ArchiveFolder 5Year -States OPEN
	
	Get a list of open volumes from the 5Year folder

.EXAMPLE
	Get-ES1VolumeByState -ArchiveName Archive1 -States FAILED,DELETED

	Get a list of failed and deleted volumes from an entire archive
	
#>
Function Get-ES1VolumeByState {
[CmdletBinding()]
PARAM( [Parameter(Mandatory=$true)]
		[Alias('archive')]
		[string] $ArchiveName,		
		[Parameter(Mandatory=$false)]
		[Alias('name')]
		[string] $ArchiveFolder,
		[Parameter(Mandatory=$true)]
		[ValidateSet ("OPEN","CLOSED","PENDING", "FAILED", "DELETED")]
		[string[]] $States
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
	$asmgr = new-object -ComObject ExAsAdminAPI.CoExASAdminAPI
	$asmgr.SetTraceInfo($Global:S1LogFile)
	$asmgr.Initialize()

    $RetVolumes=@()
	[System.Runtime.InteropServices.UnknownWrapper]$nullWrapper = New-Object "System.Runtime.InteropServices.UnknownWrapper" -ArgumentList @($null);

	# build a mask of the flags we're looking for
	[int] $volFlags= [EMC.Interop.ExAsBaseAPI.exASVolumeFlags]::exASVolumeFlagDefault
	
	try {
		# Get the volume flag enumeration strings/names
		$volStates=[enum]::GetNames([EMC.Interop.ExAsBaseAPI.exASVolumeFlags])

		$repo=$asmgr.GetRepository($ArchiveName)
        if ($repo -eq $null)
        {
            throw "Error: No archive named $($ArchiveName) found"
        }

	    $repo.SetTraceInfo($Global:S1LogFile)
    
        $folderplan=$repo.GetFolderPlan()
        $folders = @($folderplan.EnumerateArchiveFolders())

		# If an archive folder was specified only process that one...
		if ($ArchiveFolder )
		{
            foreach ($folder in $folders)
            {
			 if (($folder.Name -eq $ArchiveFolder) )
				{
					$folders = @($folder)
					break;
				}
            }
		}

		
		foreach ($folder in $folders)
		{
			$containerfolders=$folder.EnumerateContainerFolders()
			foreach ($cf in $containerfolders)
			{
				$volumes=$cf.EnumerateVolumes($nullWrapper)

				# loop through all the volumes 
				foreach($volume in $volumes)
				{
					$roles = @()
               		for ($i = 0 ; $i -lt ($volStates.Length); $i++)
					{
						[int] $bits = [EMC.Interop.ExAsBaseAPI.exASVolumeFlags]$volStates[$i]

						if ($volume.Flags -band $bits)
						{
							$roles += ([EMC.Interop.ExAsBaseAPI.exASVolumeFlags]$volStates[$i]).ToString().Substring(14)
						}

					}

					# add a user readable string representation of the flags
					$volume | Add-Member NoteProperty -Name "VolumeState" -Value $roles

					Write-Verbose "Volume: $($volume.UNCPath) FolderID: $($volume.FolderID) Flags: $($volume.Flags) $($roles) "
					foreach ($state in $States)
					{
						if ( ($state -eq 'OPEN') -and `
						(($volume.Flags -band [EMC.Interop.ExAsBaseAPI.exASVolumeFlags]::exASVolumeFlagRecordPending) -and `
						((-not ($volume.Flags -band [EMC.Interop.ExAsBaseAPI.exASVolumeFlags]::exASVolumeFlagClosed))) ))
						{
							$RetVolumes += $volume
							break;
						}

						if (($state -eq 'CLOSED') -and ($volume.Flags -band [EMC.Interop.ExAsBaseAPI.exASVolumeFlags]::exASVolumeFlagClosed))
						{
							$RetVolumes += $volume
							break;
						}

						if ( ($state -eq 'FAILED') -and `
						(($volume.Flags -band [EMC.Interop.ExAsBaseAPI.exASVolumeFlags]::exASVolumeFlagFailedRecord) ))
						{
							$RetVolumes += $volume
							break;
						}
						if ( ($state -eq 'DELETED') -and `
						(($volume.Flags -band [EMC.Interop.ExAsBaseAPI.exASVolumeFlags]::exASVolumeFlagRemovalPending) -or `
						 ($volume.Flags -band [EMC.Interop.ExAsBaseAPI.exASVolumeFlags]::exASVolumeFlagDeletedFromStorage) -or `
						 ($volume.Flags -band [EMC.Interop.ExAsBaseAPI.exASVolumeFlags]::exASVolumeFlagDeletedFromSQL) ))
						{
							$RetVolumes += $volume
							break;
						}
						if ( ($state -eq 'PENDING') -and `
						(($volume.Flags -band [EMC.Interop.ExAsBaseAPI.exASVolumeFlags]::exASVolumeFlagRecordPending) ))
						{
							$RetVolumes += $volume
							break;
						}

					}

	
				}          

			}
    
		}
			
		}
		catch 
		{
			Write-Error $_
		}
		finally
		{
            if ($folderplan)
            {
			    [System.Runtime.Interopservices.Marshal]::ReleaseComObject($folderplan) > $null
            }
            if ($repo)
            {
			    [System.Runtime.Interopservices.Marshal]::ReleaseComObject($repo) > $null
            }
		}
      
      $RetVolumes
}
END {}
}

Export-ModuleMember -Function * -Alias *

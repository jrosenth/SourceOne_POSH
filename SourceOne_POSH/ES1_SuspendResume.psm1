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
		Functions for Suspending and Resuming SourceOne services (etc) for backups and other
		things.  Essentially a port of the vbs scripts that are distributed with SourceOne

#>

#requires -Version 4

#
#  Archive Server state enums for reference:
#			 
# EMC.Interop.ExASBaseAPI.exAServerStates           exAServerAvailable               1
# EMC.Interop.ExASBaseAPI.exAServerStates           exAServerSuspendingForBackup     2
# EMC.Interop.ExASBaseAPI.exAServerStates           exAServerSuspendedForBackup      3
# EMC.Interop.ExASBaseAPI.exAServerStates           exAServerFailedSuspendRequest    4
# EMC.Interop.ExASBaseAPI.exAServerStates           exAServerResumingFromBackup      5
# EMC.Interop.ExASBaseAPI.exAServerStates           exAServerFailedResumeRequest     6


function Suspend-ES1NativeArchives
{
<#
.SYNOPSIS
	Suspends all native archives for backup.
.DESCRIPTION
	Suspends all native archives for backup and waits for suspended state to occur.
	This is a port of the "ES1_NativeArchiveSuspend.vbs" script.   Logging goes to "ES1_NativeArchiveSuspend.log" 
	in the standard SourceOne logs directory.

.EXAMPLE
	Suspend-ES1NativeArchives

#>
[CmdletBinding()]
PARAM( )
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

	# Create a TraceObject and logfile

	$LOGFILE="ES1_NativeArchiveSuspend"
	$logger = new-object -ComObject ExTrace.CoExTrace

	# Identify file to write status messages to
	$logger.Init($LOGFILE, 0)

}

PROCESS{
	
	#
	# TODO - Make this parameters ! - Jay R.
	#

	# the amount of time before the suspend times out, in seconds.
	# Change this value to shorten or lengthen the wait, as
	# appropriate to your needs.
	$timeout=3600 

	# the amount of time in seconds between polls
	$pollinterval=10 

	# the amount of time in minutes before a server's heartbeat is
    # considered unresponsive
	$unresponsive=30 

	try
    {
 
        $asmgr = new-object -ComObject ExAsAdminAPI.CoExASAdminAPI
		$asmgr.SetTraceInfo($LOGFILE)
        $asmgr.Initialize()

        $repos=$asmgr.EnumerateRepositories()

		#
		# Tell all the repositories (archives) to suspend for backup
		#    This can take a little time so we wait up to 
        foreach ($repo in $repos)
        {
			$repo.SuspendForBackup()          
			$repoState = $repo.GetBackupState()


			if ($repoState -eq [int] [EMC.Interop.ExASBaseAPI.exAServerStates]::exAServerSuspendedForBackup) 
			{
				Write-Debug "Archive:  $($repo.Name) Already suspended for backup"
				$logger.TraceInfoStr("Archive:  $($repo.Name) Already suspended for backup",$PSCmdlet.MyInvocation.ScriptLineNumber, `
						"SourceOne_POSH", $PSCmdlet.MyInvocation.MyCommand)
			}
			else
			{
				$logger.TraceInfoStr("Waiting for Archive:  $($repo.Name) to suspend ...",$PSCmdlet.MyInvocation.ScriptLineNumber,"SourceOne_POSH", `
							$PSCmdlet.MyInvocation.MyCommand)

				Write-Debug "Waiting for Archive:  $($repo.Name) to suspend ..."
			}

        }
	
	try {
			# This will throw if the wait period expires....
			Wait-ArchiveState -state exAServerSuspendedForBackup  -pollinterval $pollinterval -timeout $timeout -unresponsive $unresponsive -logname $LOGFILE
		}
		catch {
			throw $_
		}
		
	  
    }
    catch 
    {
        throw $_
    }
    finally
    {
		[System.Runtime.Interopservices.Marshal]::ReleaseComObject($asmgr)  > $null 
		[System.Runtime.Interopservices.Marshal]::ReleaseComObject($logger)  > $null 
    }
}

END{
}

}

function Resume-ES1NativeArchives
{
<#
.SYNOPSIS
	Resumes all native archives from suspend for backup.
.DESCRIPTION
	Resumes all native archives from suspend for backup and waits for available state to occur.
	This is a port of the "ES1_NativeArchiveResume.vbs" script.  Logging goes to "ES1_NativeArchiveResume.log" 
	in the standard SourceOne logs directory.

.EXAMPLE
	Resume-ES1NativeArchives

#>
[CmdletBinding()]
PARAM( )
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

	# Create a TraceObject and logfile
	$LOGFILE="ES1_NativeArchiveResume"
	
	# Create a TraceObject and logfile
	$logger = new-object -ComObject ExTrace.CoExTrace

	# Identify file to write status messages to
	$logger.Init($LOGFILE, 0)


}

PROCESS{
	
	#
	# TODO - Make this parameters ! - Jay R.
	# the amount of time before the suspend times out, in seconds.
	# Change this value to shorten or lengthen the wait, as
	# appropriate to your needs.
	$timeout=3600

	# the amount of timein seconds between polls
	$pollinterval=10

	# the amount of time in minutes before a server's heartbeat is
    # considered unresponsive
	$unresponsive=30 

	try
    {
 
        $asmgr = new-object -ComObject ExAsAdminAPI.CoExASAdminAPI
		$asmgr.SetTraceInfo($LOGFILE)
        $asmgr.Initialize()

        $repos=$asmgr.EnumerateRepositories()

        foreach ($repo in $repos)
        {
			
			$repoState = $repo.GetBackupState()
	
			if ($repoState -eq [int] [EMC.Interop.ExASBaseAPI.exAServerStates]::exAServerAvailable) 
			{
				Write-Debug "Archive:  $($repo.Name) Already available"
				$logger.TraceInfoStr("Archive:  $($repo.Name) Already available",$PSCmdlet.MyInvocation.ScriptLineNumber,"SourceOne_POSH", `
						$PSCmdlet.MyInvocation.MyCommand)
			}
			else
			{
				$repo.ResumeFromBackup()
				$logger.TraceInfoStr("Waiting for Archive:  $($repo.Name) to resume",$PSCmdlet.MyInvocation.ScriptLineNumber,"SourceOne_POSH", `
						$PSCmdlet.MyInvocation.MyCommand)
				Write-Debug "Waiting for Archive:  $($repo.Name) to resume ..."
			}

        }

		try {
			# This will throw if the wait period expires....
			Wait-ArchiveState -state exAServerAvailable  -pollinterval $pollinterval -timeout $timeout -unresponsive $unresponsive -logname $LOGFILE
		}
		catch {
			throw $_
		}
    }
    catch 
    {
        throw $_
    }
    finally
    {
		[System.Runtime.Interopservices.Marshal]::ReleaseComObject($asmgr)  > $null 
		[System.Runtime.Interopservices.Marshal]::ReleaseComObject($logger)  > $null 
    }
}

END{
}

}
 function Wait-ArchiveState
 {
 [CmdletBinding()]
PARAM(  [Parameter( Mandatory=$True)]
        [Alias('state')]
        [EMC.Interop.ExASBaseAPI.exAServerStates] $waitState=[EMC.Interop.ExASBaseAPI.exAServerStates]::exAServerAvailable ,
		[Parameter( Mandatory=$True,HelpMessage='The amount of time in seconds between state checks')]
		 [int] $pollinterval=10,
		[Parameter( Mandatory=$True, HelpMessage='The total time to wait in seconds before the timing out.')]
		 [int] $timeout=3600,
		[Parameter( Mandatory=$True, HelpMessage='The amount of time in minutes before a server is considered unresponsive.')]
		 [int] $unresponsive=30,
		[Parameter( Mandatory=$True, HelpMessage='Name of log file')]
		 $logname=''
		)
BEGIN {

	
	# Create a TraceObject and logfile
	$logger = new-object -ComObject ExTrace.CoExTrace

	# Identify file to write status messages to
	$logger.Init($logname, 0)


}
PROCESS {
 		$startTime = Get-Date

		while($true)
		{
		   $allInState = $true
		   
		   Start-Sleep -Milliseconds ($pollinterval * 1000)

		    foreach ($repo in $repos)
			{
				$repoState = $repo.GetBackupState()
				if ($repoState -ne [int] $waitState) 
				{
					$allInState = $false
					Write-Debug "Still waiting for Archive:  $($repo.Name)"
					$logger.TraceInfoStr("Still waiting for Archive:  $($repo.Name)",$PSCmdlet.MyInvocation.ScriptLineNumber,"SourceOne_POSH", `
								$PSCmdlet.MyInvocation.MyCommand)
				}

			}
		
		   $endTime = Get-Date
		   $loopLength = ($endTime - $startTime).TotalMilliseconds
		   $timeRemaining = ($timeout * 1000) - $loopLength

		   if(($timeRemaining -le 0) -or ($allInState))
		   {
			  Write-Debug "Done waiting, time remaining $($timeremaining) , All 'in requested state' $($allInState) "
			  break
		   }
		}
		
		if($allInState)
		{
			$logger.TraceInfoStr("All Archives successfully in state $($waitState.ToString())",$PSCmdlet.MyInvocation.ScriptLineNumber,"SourceOne_POSH", `
								$PSCmdlet.MyInvocation.MyCommand)
		
		}

		if($timeRemaining -le 0)
		{
			throw "$($PSCmdlet.MyInvocation.MyCommand), timeout expired waiting"
		}
	}


END{

	[System.Runtime.Interopservices.Marshal]::ReleaseComObject($logger)  > $null 
}


 }

#
#   Public Exports
#
Export-ModuleMember -Function * -Alias *

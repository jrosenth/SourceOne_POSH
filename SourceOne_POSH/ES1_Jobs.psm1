<#	
	.NOTES
	===========================================================================
	 Created by:   	jrosenthal
	 Organization: 	EMC Corp.
	 Filename:     	ES1_Jobs.psm1
	
	Copyright (c) 2015 EMC Corporation.  All rights reserved.
	===========================================================================
	THIS CODE AND INFORMATION IS PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND,
	WHETHER EXPRESSED OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE IMPLIED
	WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A PARTICULAR PURPOSE.
	IF THIS CODE AND INFORMATION IS MODIFIED, THE ENTIRE RISK OF USE OR RESULTS IN
	CONNECTION WITH THE USE OF THIS CODE AND INFORMATION REMAINS WITH THE USER. 

	.DESCRIPTION
		Functions for viewing and monitoring the SourceOne Jobs

#>

#requires -Version 2



# JDF DB uses/return theses actual values
#  C# code uses the [EMC.Interop.ExJDFAPI.exJDFJobState] enum
$eJobUnknown = 0x00000000 # - Unknown State(DB default)
$eJobAvailable = 0x00000001 # - The job is free for the taking
$eJobTaken = 0x00000002 # - A worker has chosen the job and is 
#	 preparing to start the job
$eJobActive = 0x00000004 # - A worker is currently processing the job
$eJobSuspended = 0x00000008 # - The job was temporarily stopped and will
#   resume soon
$eJobCompleted = 0x00000010 # - The job finished. This State does not
#   imply success or failure
$eJobIncomplete = 0x00000020 # - The job was unable to finish in the time
#   it was allocated to run
$eJobSelfTerminated = 0x00000040 # - The job was directed to terminate
#   itself by Job Dispatcher and did
$eJobDispTerminated = 0x00000080 # - The job was directed to terminate
#   itself by the Job Dispatcher but
#   was unable to so the Job Dispatcher
#   killed it.
$eJobUserTerminated = 0x00000100 # - The user terminated the job
#   through the Admin
$eJobExpired = 0x00000200 # - The job was never dispatched, the reason
#	 when dispatcher became aware of this job, the
#   job had already passed its EndTime. 
$eJobFailed = 0x00000400 # - The job was never ran or failed to run
$eJobWaitForResource = 0x00000800 # - The job is waiting for resources 
$eJobState_LAST_ENTRY #!< for loop processing*/

function Show-ES1Jobs
{
<#
.SYNOPSIS
 Derived from Mike Tramont JobInfo script(s)
Produce a table of job history an status for the requested number of days.

.DESCRIPTION

.NOTES
Derived from Mike Tramont JobInfo script(s)

.PARAMETERS Jobtype
show job information for the specified "HA","FA","journal","querydc","query","FIP","SP","Shortcut","Export","restoredc"

.OUTPUTS

.EXAMPLE

#>
[CmdletBinding()]
param(
	$newest, $taskTypeid = 0,
	[ValidateSet("HA","FA","journal","querydc","query","FIP","SP","Shortcut","Export","restoredc","")]
	[string]$jobtype,
	[int]$days = -1,[switch] $usedate = $false,
	[switch]$failed,[switch]$failedItems)

	Get-ES1JobInfo $newest $tasktypeid $jobtype $days -usedate:$usedate -failed:$failed -faileditems:$faileditems | `
	       select-object Jobid,WorkerName,PolicyName,ActivityName,TaskType,Statestr,ItemsProcessed,ItemsFailed,ItemsDupd,starttime,Endtime | Format-Table -AutoSize | Out-String -Width 10000

}


<#
.SYNOPSIS
 Derived from Mike Tramont JobInfo script(s)
Produce a table of job history an status for the requested number of days.

.DESCRIPTION

.NOTES
Derived from Mike Tramont JobInfo script(s)

.PARAMETERS days
	The number of days of information to capture, default is 1 day of information
.PARAMETERS newest
	The number of most recent job information to retreive
.PARAMETERS Failed
	show only items with a failed State
.PARAMETERS FailedItems
	show only items with a FailedItemCount > 0
.OUTPUTS

.EXAMPLE

#>
function Get-ES1JobInfo
{
[CmdletBinding()]
param(
	$newest, $taskTypeid = 0,
	[ValidateSet("HA","FA","journal","querydc","query","FIP","SP","Shortcut","Export","restoredc","")]
	[string]$jobtype,
	[int]$days = 0,[switch] $usedate = $false,
	[switch]$failed,[switch]$failedItems)

begin{}
process {

	write-verbose "tasktypeid = $tasktypeid Newest = $newest, Days = $days, jobtype = $jobtype switches $failed $faileditems"

	if ($newest -eq $null)
	{

		if ($failed -or $failedItems -or ($jobtype -ne $null) -or ($taskTypeid -ne 0))
		{
			$newest = 10
		}
	}

	switch ($jobtype)
	{
		"journal" { $tasktypeid = 2} 
		"querydc" { $tasktypeid = 16} 
		"delete" { $tasktypeid = 21} 
		"query" { $tasktypeid = 8} 
		"FA" { $tasktypeid = -931516946} 
		"FIP" { $tasktypeid = -475486385}
		"SP" { $tasktypeid = 2002108941} 
		"shortcut" { $tasktypeid = 14} 
		"export" { $tasktypeid = 6} 
		"restoredc" { $tasktypeid = 6} 
		"HA" { $tasktypeid = 12} 
	}



	#-------------------------------------------------------------------------------
	# Get Activity Database
	#-------------------------------------------------------------------------------
	$activityData = Get-ES1ActivityObj
	$actDbServer = $activityData.ActivityServer
	$actDb = $activityData.ActivityDb
	#
	# Calculate Start Date
	#
	#	$months = 6
	#	$days = $months * 31 * -1
	#$days = -1
	if ($usedate -or ($days -ne 0))
	{
		if ($days -gt 0)
		{
			$days = $days * -1
		}
		$usedate = $true
		$date_prior = (Get-Date).AddDays($days)
		#$date_start = Get-Date -Year $date_prior.Year -Month $date_prior.Month -Day 1 -Hour 0 -Minute 0 -Second 0
		$date_start_string = $date_prior.ToString("yyyy-MM-dd")
		write-verbose $date_start_string
	}

	$dtOutput =@()

	if ($usedate)
	{

		#
		# Query Job Data
		#
		$sqlQuery = @'
SELECT CAST(DATEDIFF(hour, j.StartTime, GetUTCDate()) AS Int) AS Age_Hours, j.JobID, j.State AS State_Orig, p.Name AS Policy_Name, a.Name AS Activity_Name, tt.Name AS Task_Type, j.StartTime, j.EndTime,
j.ProcessedItemCount, j.DuplicateItemCount, j.FailedItemCount,j.workerid
FROM Jobs j (NOLOCK)
JOIN Tasks t (NOLOCK) ON t.TaskID = j.TaskID
JOIN TaskTypes tt (NOLOCK) ON tt.TaskTypeID = t.TaskTypeID
LEFT JOIN Activity a (NOLOCK) ON a.ActivityID = t.ActivityID
LEFT JOIN Policy p (NOLOCK) ON p.PolicyID = a.PolicyID
WHERE j.StartTime >= 'DATE_START_STRING'
ORDER by j.JobID desc
'@
		$sqlQuery = $sqlQuery.Replace('DATE_START_STRING', $date_start_string)
	}
	else
	{

		$sqlQuery = @'
SELECT Top NEWEST CAST(DATEDIFF(hour, j.StartTime, GetUTCDate()) AS Int) AS Age_Hours, j.JobID,
j.State AS State_Orig, p.Name AS Policy_Name, a.Name AS Activity_Name, tt.Name AS Task_Type, j.StartTime, j.EndTime,
j.tasktypeid,j.ProcessedItemCount, j.DuplicateItemCount, j.FailedItemCount,j.workerid
FROM Jobs j (NOLOCK)
JOIN Tasks t (NOLOCK) ON t.TaskID = j.TaskID
JOIN TaskTypes tt (NOLOCK) ON tt.TaskTypeID = t.TaskTypeID
LEFT JOIN Activity a (NOLOCK) ON a.ActivityID = t.ActivityID
LEFT JOIN Policy p (NOLOCK) ON p.PolicyID = a.PolicyID
WHERE
ORDER by j.JobID desc
'@

		$sqlquery = $sqlQuery.Replace('NEWEST',$newest)

		if ($failed -and $failedItems)
		{
			$sqlquery = $sqlQuery.Replace('WHERE',"where (j.state = $eJobFailed ) OR (FailedItemCount > 0)" )
		}
		else
		{

			if ($failed)
			{
				$sqlquery = $sqlQuery.Replace('WHERE',"where j.state = $eJobFailed " )
			}
			else
			{

				if ($failedItems)
				{
					$sqlquery = $sqlQuery.Replace('WHERE',"where FailedItemCount > 0 " )
				}
				else
				{
					if (($tasktypeid -ne 0) -and ($tasktypeid -ne $null))
					{
						$sqlquery = $sqlQuery.Replace('WHERE',"where j.tasktypeid = $tasktypeid")
					}
					else
					{
						$sqlquery = $sqlQuery.Replace('WHERE','')
					}
				}
			}
		}

	}
	Write-Verbose $sqlQuery

	$dtOutput = @(Invoke-ES1SQLQuery $actDbServer $actDb $sqlQuery )

	Write-Verbose "Data Rows Returned:  $($dtOutput.Rows.Count)"

	#
	# Output results
	#
	#$dtOutput | Export-CSV -NoTypeInformation -Delimiter "`t" -Path "$outdir\Data\DATA-JobInfo.tsv" -Force
	#$dtOutput | format-table -AutoSize

	$jobsArray = @()
	foreach ($row in $dtOutput)
	{
		$wName = Get-ES1WorkerNameFromID $row.workerid

		$jState = Convert-S1JobStateToString $row.state_orig
		$jobprops = [ordered] @{jobid=$row.jobid;
			WorkerName = $wName;
			PolicyName = $row.Policy_Name;
			ActivityName = $row.Activity_Name;
			TaskType = $row.Task_Type;
			StateStr = [string]$jstate;
			ItemsProcessed = $row.ProcessedItemCount;
			ItemsFailed = $row.faileditemcount;
			ItemsDupd = $row.duplicateitemcount;
			StartTime = $row.StartTime.ToLocalTime();
			EndTime = $row.endtime.ToLocalTime();
			TaskTypeID =$row.tasktypeid;			
			JobType =$jobtype;
			State = $row.state_orig;
			AgeHours = $row.age_hours;
			 }
		$jobObject = New-Object -Type psobject -Property $jobprops
		$JobsArray += $jobObject

		#Jobid,WorkerName,PolicyName,ActivityName,TaskType,Statestr,ItemsProcessed,ItemsFailed,ItemsDupd,starttime,Endtime 
	}

	$JobsArray 

}
end {}

}


function Convert-S1JobStateToString
{
 param ([int]$state)
$decoded = ''

# [EMC.Interop.ExJDFAPI.exJDFJobState]

switch ($state)
{
	$eJobUnknown { $decoded = "JobUnknown"} 
	$eJobAvailable { $decoded = "JobAvailable"} 
	$eJobTaken { $decoded = "JobTaken"} 
	$eJobActive { $decoded = "JobActive"} 
	$eJobSuspended { $decoded = "JobSuspended"} 
	$eJobCompleted { $decoded = "JobCompleted"} 
	$eJobIncomplete { $decoded = "JobIncomplete"} 
	$eJobSelfTerminated { $decoded = "JobSelfTerminated"} 
	$eJobDispTerminated { $decoded = "JobDispTerminated"} 
	$eJobUserTerminated { $decoded = "JobUserTerminated"} 
	$eJobFailed { $decoded = "JobFailed"} 
	$eJobExpired { $decoded = "JobExpired"} 
	$eJobWaitForResource { $decoded = "JobWaitForResource"} 
}
if ($decoded.Contains('?'))
{
	$decoded = "Unknown-$state"
}
$decoded
}


<#
.SYNOPSIS
	Produce a table of job history for Jobs which have failed
.DESCRIPTION
	Show-ES1FailedJobs
.PARAMETERS newest
The number of items to display

.EXAMPLE
Show-ES1FailedJobs 

jobid StartTime             ItemsFailed ItemsDupd State WorkerID StateStr   JobType ItemsProcessed EndTime              
----- ---------             ----------- --------- ----- -------- --------   ------- -------------- -------              
 3030 11/9/2015 10:48:04 PM           0         0  1024        2 eJobFailed                      0 1/1/1970 12:00:00 AM 
 2928 11/6/2015 2:56:29 PM            0         0  1024        1 eJobFailed                      0 1/1/1970 12:00:00 AM 


 #>
function Show-ES1FailedJobs
{
[CmdletBinding()]
 param($newest = 10)

Get-ES1JobInfo -failed -newest $newest | `
	select-object Jobid,WorkerName,PolicyName,ActivityName,TaskType,Statestr,ItemsProcessed,ItemsFailed,ItemsDupd,starttime,Endtime |`
	Format-Table -AutoSize | Out-String -Width 10000
}

<#
.SYNOPSIS
	Produce a table of job history for Jobs which have failed items
.DESCRIPTION
	Show-ES1JobsWithFailedItems
.PARAMETERS newest
	The number of items to display

.EXAMPLE

 #>
function Show-ES1JobsWithFailedItems
{
[CmdletBinding()]
 param($newest = 10)

Get-ES1JobInfo -failedItems -newest $newest | `
	select-object Jobid,WorkerName,PolicyName,ActivityName,TaskType,Statestr,ItemsProcessed,ItemsFailed,ItemsDupd,starttime,Endtime | `
	Format-Table -AutoSize | Out-String -Width 10000
}

<#
.SYNOPSIS
 Find-InS1JobLogs 
.DESCRIPTION
	Retrieve the location and specified information from the SourceOne Job Logs
.PARAMETER JobId
	Optional Specific JobId (decimal) or "*" for all jobs  default to *
.PARAMETER SearchStr
	Optional String to search for
.PARAMETER Startdate
	Check only logs newer than the specified Startdate
      
.EXAMPLE
	Find-InS1JobLogs  -searchStr "Total Failed"

00000028DETMSG.LOG.fullname
    Job(40) -> Total Failed messages: 0 
00000119DETMSG.LOG.fullname
0000011ADETMSG.LOG.fullname
0000012CDETMSG.LOG.fullname
    Job(300) -> Total Failed messages: 0 
.EXAMPLE 
Look for logs created since 11-15-2015

Find-InS1JobLogs -searchStr "Failed" -startdate 11-15-2015
.EXAMPLE 

#>


function Find-inES1JobLogs
{
	[CmdletBinding()]
	param ($JobId, $searchStr,[datetime] $startdate, $days = 1,
		$lineContext = 3, $summary = 7)
	$enddate = $null
	$end = 0
	if (($days -gt 0) -and ($startdate -ne $null))
	{
		$timespan = new-timespan $startdate (Get-date)
		if ($timespan.Days -ge 0)
		{
			if ($days -gt $timespan.Days)
			{
				$end = $timespan.Days
			}
			else
			{
				$end = $days
			}
		}
		else
		{
			write-output "$startdate is in the future"
			return
		}
		$enddate = $startdate.AddDays($end)
	}

	write-verbose "$startdate to $enddate"

	Get-ES1JobLogDir | out-null

	$hexJobid = "{0:X0}" -f $JobId

	$filterStr = "*$hexJobid*.log"

	write-verbose $filterStr

	Write-Verbose "checking $startdate with $searchStr"
	if ($enddate -ne $null)
	{
		$theLogs = gci -path $s1JobLogDir -Filter $filterstr | 
		Where-Object { ($_.LastWriteTime -gt $startdate) -and ($_.LastWriteTime -lt $enddate)}
	}
	else
	{
		if ($startdate -ne $null)
		{
			$theLogs = gci -path $s1JobLogDir -Filter $filterstr | Where-Object {$_.LastWriteTime -gt $startdate}
		}
		else
		{
			$theLogs = gci -path $s1JobLogDir -Filter $filterstr 
		}
	}


	Write-Verbose "Found $($log.count) files"
	foreach ($log in $theLogs)
	{
		Write-Verbose "checking $startdate with $searchStr"
		$result = ''
		if ($searchStr -ne $null)
		{
			$result = gc $log.fullName -Encoding UNICODE | select-string $searchStr -Context $lineContext,1
		}
		else
		{
			$result = gc $log.fullName -Tail $summary -Encoding Unicode
		}
		write-output $log.fullname
		write-output ""
		write-output $result
		write-output ""

	}

}

<#
.SYNOPSIS
	TBD	
.DESCRIPTION
	TBD - 
 #>

function Show-ES1JobLogs
{
[CmdletBinding()]
	param ()
    Get-ES1JobLogDir | out-null
    ls $s1JobLogDir\*.log


}

New-Alias S1JobsWFailedMsgs Show-ES1JobsWithFailedItems
New-Alias Show-S1JobsWithFailedMessages Show-ES1JobsWithFailedItems
New-Alias Show-S1Jobs Show-ES1Jobs
New-Alias Get-S1Jobs Get-ES1JobInfo
New-Alias Show-S1JobInfo Show-ES1Jobs
New-Alias Show-S1FailedJobs Show-ES1FailedJobs
New-Alias S1Jobs Show-ES1JobInfo
New-Alias S1FailedJobs Show-ES1FailedJobs
New-Alias Show-S1JobLogs Show-ES1JobLogs
New-Alias Find-inS1JobLogs Find-inES1JobLogs


Export-ModuleMember -Function * -Alias *
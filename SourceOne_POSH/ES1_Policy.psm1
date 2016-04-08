<#	
	.NOTES
	===========================================================================
	 Created by:   	jrosenthal
	 Organization: 	EMC Corp.
	 Filename:     	ES1_Policy.psm1
 	 Copyright (c) 2015 EMC Corporation.  All rights reserved.

    THIS CODE AND INFORMATION IS PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND,
    WHETHER EXPRESSED OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE IMPLIED
 	WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A PARTICULAR PURPOSE.
 	IF THIS CODE AND INFORMATION IS MODIFIED, THE ENTIRE RISK OF USE OR RESULTS IN
 	CONNECTION WITH THE USE OF THIS CODE AND INFORMATION REMAINS WITH THE USER. 
	===========================================================================
	.DESCRIPTION
		A collection of function and cmdlets used for managing SourceOne Policies
        and Activities
#>

###

function Pause-ES1Policies {
<#
.SYNOPSIS
	Pause all active SourceOne Policies
.DESCRIPTION
	Pause all active SourceOne Policies
	
.EXAMPLE
	Pause-ES1Policies

#>
[CmdletBinding()]
Param( )

BEGIN {
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
    $jdfapiMgr=new-object -comobject ExJDFAPI.CoExJDFAPIMgr.1
    
     $policies=@()
     $policies=@($jdfapiMgr.GetPolicies())
     
    #$policies | Format-Table -AutoSize | Out-String -Width 10000

    # $PolicyStates=[enum]::GetNames([EMC.Interop.ExBase.exPolicyState])

    #
    # Disable each policy one at a time
     
     foreach ($policy in $policies)
     {
    
        if ($policy.state -eq [int] [EMC.Interop.ExBase.exPolicyState]::exPolicyState_Active )
        {
          Write-Host 'Pausing Active Policy: ' $policy.name

          #
          # Set the state to suspended
          $policy.state = [int][EMC.Interop.ExBase.exPolicyState]::exPolicyState_Suspended

          #Save the policy
          $policy.Save()

      }
	  else
	  {
	  Write-Warning 'Policy is not in a state that can be suspended !'
	  }

     }
 }
 catch 
 {
    Write-Error  $_
 }
}
END {}
}

function Resume-ES1Policies {
<#
.SYNOPSIS
	Resumes all paused and stopped SourceOne Policies
.DESCRIPTION
	Resumes all paused and stopped SourceOne Policies

.OUTPUTS
	
.EXAMPLE
TBD

#>
[CmdletBinding()]
Param( )

BEGIN {
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
    $jdfapiMgr=new-object -comobject ExJDFAPI.CoExJDFAPIMgr.1
    
     $policies=@()
     $policies=@($jdfapiMgr.GetPolicies())
     
    #$policies | Format-Table -AutoSize | Out-String -Width 10000

    # $PolicyStates=[enum]::GetNames([EMC.Interop.ExBase.exPolicyState])

    #
    # Enable each policy one at a time
     
     foreach ($policy in $policies)
     {
    
        if (($policy.state -eq [int] [EMC.Interop.ExBase.exPolicyState]::exPolicyState_Suspended) -or `
		    ($policy.state -eq [int] [EMC.Interop.ExBase.exPolicyState]::exPolicyState_User_Terminated))
		{
          Write-Host 'Enabling Suspended or Stopped Policy: ' $policy.name

          #
          # Set the state to Active
          $policy.state = [int][EMC.Interop.ExBase.exPolicyState]::exPolicyState_Active

          #Save the policy
          $policy.Save()

		 }
		 else
		 {
			 Write-Warning 'Policy is not in a state that can be resumed !'
		 }


     }
 }
 catch 
 {
    Write-Error  $_
 }
}
END {}
}

Function Show-ES1Policies {
<#
.SYNOPSIS
	Displays all SourceOne policies
	
.DESCRIPTION
	Displays all SourceOne policies
	Must be running in a 32 bit PowerShell AND on a machine with SourceOne COM objects installed and registered
.OUTPUTS
	
.EXAMPLE
	Show-ES1Policies
	
Policy Id Name Description State  Created                Last Modified        Modified By
--------- ---- ----------- -----  -------                -------------        -----------
        1 foo              Active 12/30/1899 12:00:00 AM 11/4/2015 6:41:49 PM


#>
[CmdletBinding()]
Param( )

BEGIN {
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
			$jdfapiMgr=new-object -comobject ExJDFAPI.CoExJDFAPIMgr.1
    
			$policies=@()
			$policies=@($jdfapiMgr.GetPolicies())

		  # Make the output look nice
			$fmt = @{ Expression = { $_.id }; label = "Policy Id" },
			@{ Expression = { $_.name }; label = "Name" },
			@{ Expression = { $_.description }; label = "Description" },
			@{ Expression = { ([EMC.Interop.ExBase.exPolicyState]$_.state).ToString().Substring(14) }; label = "State" },
			@{ Expression = { $_.createTime }; label = "Created" },
			@{ Expression = { $_.lastModified }; label = "Last Modified" },
			@{ Expression = { $_.modifiedBy }; label = "Modified By" }

			$policies | Format-Table -AutoSize $fmt | Out-String -Width 10000

		 }
		 catch 
		 {
			Write-Error  $_
		 }


}
END {}

}

function Pause-ES1Activities {
<#
.SYNOPSIS
	Pauses all SourceOne Activities with the specified type ID
.DESCRIPTION
	Pauses all SourceOne Activities with the specified type ID
	
.EXAMPLE
	Pause-ES1Activities 12

.EXAMPLE
	Pause-ES1Activities -activityTypeID 12
#>
[CmdletBinding()]
Param([Parameter( Mandatory=$True)]
        [Alias('type')]
        [int] $activityTypeID=0 )
BEGIN {
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

	if ($activityTypeID -eq 0)
	{
		Write-Error 'Invalid job/activity type id: ' $activityTypeID
		return
	}


    $jdfapiMgr=new-object -comobject ExJDFAPI.CoExJDFAPIMgr.1
 
	$policies=@()
	$activities=@()

	$policies=@($jdfapiMgr.GetPolicies())
    $activityType= $jdfapiMgr.GetTaskTypeById($activityTypeID)

    Write-Host "Searching for activities matching: $($activityType.Name) - Type: $activityTypeID"

	foreach ($policy in $policies)
	{
  
		$actFilter= $jdfapiMgr.CreateNewObject([EMC.Interop.ExJDFAPI.exJDFObjectType]::exJDFObjectType_ActivityFilter)
		$actFilter.policyID = $policy.id

		$activities= @($jdfapiMgr.GetActivities($actFilter))

		foreach($act in $activities)
		{
			Write-Debug "Activity ID $($act.id), Name $($act.name),  taskTypeID $($act.taskTypeID), $($act.description)"
    
            #$availStates=$act.GetAvailableActions()

			if ($activityTypeID -eq $act.taskTypeID)  
				{ 
				
				  Write-Host 'Pausing Activity: ' $act.name
                    try
                    {  
                        # Will throw if activity is not in a state which can be paused...
                       $act.ApplyAction([EMC.Interop.ExBase.exActivityActions]::exActivityAction_Suspend)
                    }
                    catch
                    {
                        Write-Warning 'Activity could not be Paused.'
                        Write-Error $_

                    }
                
			  }
		  }


		  [System.Runtime.Interopservices.Marshal]::ReleaseComObject($actFilter)  > $null     
	 
	}
 }
 catch 
 {
    Write-Error  $_
 }

}

END {}
}

function Resume-ES1Activities {
<#
.SYNOPSIS
Resumes all SourceOne Activities with the specified type ID
.DESCRIPTION
Resumes all SourceOne Activities with the specified type ID
.OUTPUTS
	
.EXAMPLE
	Resume-ES1Activities 12
.EXAMPLE
	Resume-ES1Activities -activityTypeID 12
#>
[CmdletBinding()]
Param([Parameter( Mandatory=$True)]
        [Alias('type')]
        [int] $activityTypeID=0 )
BEGIN {
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

	if ($activityTypeID -eq 0)
	{
		Write-Error 'Invalid job/activity type id: ' $activityTypeID
		return
	}


    $jdfapiMgr=new-object -comobject ExJDFAPI.CoExJDFAPIMgr.1
 
	$policies=@()
	$activities=@()

	$policies=@($jdfapiMgr.GetPolicies())
    $activityType= $jdfapiMgr.GetTaskTypeById($activityTypeID)

    Write-Host "Searching for activities matching: $($activityType.Name) - Type: $activityTypeID"

	foreach ($policy in $policies)
	{
  
		$actFilter= $jdfapiMgr.CreateNewObject([EMC.Interop.ExJDFAPI.exJDFObjectType]::exJDFObjectType_ActivityFilter)
		$actFilter.policyID = $policy.id

		$activities= @($jdfapiMgr.GetActivities($actFilter))

		foreach($act in $activities)
		{
			Write-Debug "Activity ID $($act.id), Name $($act.name),  taskTypeID $($act.taskTypeID), $($act.description)"
    
			if ($activityTypeID -eq $act.taskTypeID)  
				{ 
				  Write-Host 'Resuming Activity: ' $act.name
                  try
                    {  
                        # Will throw if activity is not in a state which can be resumed...
                       $act.ApplyAction([EMC.Interop.ExBase.exActivityActions]::exActivityAction_Resume)
                    }
                    catch
                    {
                        Write-Warning 'Activity could not be Resumed.'
                        Write-Error $_

                    }
				 
			  }
		  }

		  [System.Runtime.Interopservices.Marshal]::ReleaseComObject($actFilter)  > $null     
	 
	}
 }
 catch 
 {
    Write-Error  $_
 }

}

END {}
}

Function Show-ES1Activities {
<#
.SYNOPSIS
	Display a list of all the configured SourceOne activities
	
.DESCRIPTION
	Display a list of all the configured SourceOne activities
	
.EXAMPLE
Policy Name Activity Name       State  TaskType                       TaskTypeID Created              Last Modified         Modified By
----------- -------------       -----  --------                       ---------- -------              -------------         -----------
foo         Test 1              Active Journaling JBS                         16 6/10/2015 6:59:19 PM 11/13/2015 6:53:29 PM
foo         TestHAForReclassify Active Mailbox Management Archive JBS          3 8/3/2015 7:00:50 PM  11/13/2015 6:53:53 PM


#>
[CmdletBinding()]
Param( )

BEGIN {

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
		$jdfapiMgr=new-object -comobject ExJDFAPI.CoExJDFAPIMgr.1
    
		$policies=@()
		$activities=@()
		$policies=@($jdfapiMgr.GetPolicies())

		foreach ($policy in $policies)
		{
			$policyName=$policy.name
			$actFilter= $jdfapiMgr.CreateNewObject([EMC.Interop.ExJDFAPI.exJDFObjectType]::exJDFObjectType_ActivityFilter)
			$actFilter.policyID = $policy.id

			$activities= @($jdfapiMgr.GetActivities($actFilter))
            #
            # Ad some new columns
			$activities | Add-Member NoteProperty -Name "Policy" -Value $policyName
			$activities | Add-Member NoteProperty -Name "TaskType" -Value ""

            foreach ($act in $activities)
            {
                $taskString=$jdfapiMgr.GetTaskTypeByID($act.taskTypeID)
                $act.TaskType = $taskString.Name
            }

            $AllActivities+=$activities

		  [System.Runtime.Interopservices.Marshal]::ReleaseComObject($actFilter)  > $null     
	 
		}
       
		  # Make the output look nice
            #  The object does NOT return the DB value of lastState !! So no reason to display it !!
			$fmt = @{ Expression = { $_.Policy }; label = "Policy Name" },            
			@{ Expression = { $_.name }; label = "Activity Name" },
		    #@{ Expression = { $_.description }; label = "Description" },
			@{ Expression = { ([EMC.Interop.ExBase.exActivityState]$_.state).ToString().Substring(16) }; label = "State" },
           # @{ Expression = { ([EMC.Interop.ExBase.exActivityState]$_.lastState).ToString().Substring(16) }; label = "Previous State" },
            @{ Expression = { $_.TaskType }; label = "TaskType" },
            @{ Expression = { $_.taskTypeID }; label = "TaskTypeID" },
			@{ Expression = { $_.timeCreated }; label = "Created" },
			@{ Expression = { $_.timeLastModified }; label = "Last Modified" },
			@{ Expression = { $_.modifiedBy }; label = "Modified By" }

			$AllActivities | sort policyID, id | Format-Table -AutoSize $fmt | Out-String -Width 10000

		 }
		 catch 
		 {
			Write-Error  $_
		 }


}
END {}

}
New-Alias  Show-S1Policies          Show-ES1Policies 
New-Alias  Pause-S1Policies         Pause-ES1Policies
New-Alias  Resume-S1Policies        Resume-ES1Policies
#
#   Public Exports
#
Export-ModuleMember -function * -Alias * 


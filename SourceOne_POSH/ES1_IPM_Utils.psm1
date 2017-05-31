<#	
	.NOTES
	===========================================================================
	 Created on:   	8/16/2014 10:52 AM
	 Created by:   	jrosenthal
	 Organization: 	EMC Corp.
	 Filename:     	ES1_IPM_Utils.psm1
 	 Copyright (c) EMC Corporation.  All rights reserved.


    THIS CODE AND INFORMATION IS PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND,
    WHETHER EXPRESSED OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE IMPLIED
 	WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A PARTICULAR PURPOSE.
 	IF THIS CODE AND INFORMATION IS MODIFIED, THE ENTIRE RISK OF USE OR RESULTS IN
 	CONNECTION WITH THE USE OF THIS CODE AND INFORMATION REMAINS WITH THE USER. 
	===========================================================================
	.DESCRIPTION
		A collection of function and cmdlets used for getting In Place Migration
        information and statistics.
#>

#requires -Version 2

#
# SQL to get info about a running task instance
#
$global:SQLGetMigJob="select tsk.Name as TaskName,
		              Type = case [JobType]
                     when '1' then 'Inventory'
                     when '2' then 'Migration'
                     when '3' then 'Volume Validation'
                     when '4' then 'Index Validation'
                     END,
			     	[JobID], job.TaskID as TaskID,ProcessedVolumes,ProcessedIndexes, 
                     CAST(job.ProcessedVolumes / NULLIF (DATEDIFF(ss, job.CreatedTime, 
                     job.LastUpdatedTime) / 3600.0, 0.00) AS decimal(10, 1)) AS 'Volumes/Hr',
                    Status = case job.Status
                    when '0' then 'Complete'
                    when '1' then 'Pending'
                    when '2' then 'Running'
		            when '3' then 'Failed'  
		            when '4' then 'Stopped'	
                    else master.sys.fn_varbintohexstr(job.Status)
                    END,
                    job.[CreatedTime] as StartTime, job.[LastUpdatedTime] as UpdateTime,
                    convert(varchar, DATEDIFF(s, job.CreatedTime, job.LastUpdatedTime) / (60 * 60 * 24)) + ':' +
                    CONVERT(varchar, DATEADD(s, DATEDIFF(ss, job.CreatedTime, job.LastUpdatedTime), 0), 108) AS ElapsedTime, 
                    [WorkerName]
                    from [archiveDB].[dbo].[ipmJob] (NOLOCK) as job
                    join ipmTask as tsk on tsk.TaskID=job.TaskID
                    where job.TaskID=inJOBID"

$global:SQLGetMigJobErrors="select JobID,job.[CreatedTime] as StartTime, job.[LastUpdatedTime] as UpdateTime,
		            Type = case [JobType]
                     when '1' then 'Inventory'
                     when '2' then 'Migration'
                     when '3' then 'Volume Validation'
                     when '4' then 'Index Validation'
                     END,
                    xConfig.query('count(/MigrationParams/ErrorList/Error)').value('.','int')as ErrCnt,
                      ERRXML.ErrNode.query('.').value('.', 'varchar(2048)') as ErrString  
                    FROM
                    [archiveDB].[dbo].[ipmJob] (NOLOCK) as job  cross apply  xConfig.nodes('/MigrationParams/ErrorList/Error')
                    as ERRXML(ErrNode) where job.jobID=inJOBID --and Status< 0"



#
# SQL to calc mgirated messages and duplicates
#
$global:SQLJobMsgs="select Sum(ItemCount) as MigratedMessages, sum(ExceptionCount) as Exceptions,COUNT(VolumeName) as Volumes 
                     from [archiveDB].[dbo].[ipmVolume] (NOLOCK)
                     where jobID = jobinstance and Status =0"
 
 
$global:SQLEXServerVolumes="select ex.ExServerName, Sum(ItemCount) as MigratedMessages,
                            sum(ExceptionCount) as Exceptions,
                            COUNT(VolumeName)as Volumes, 
                            Status = case vol.Status when '0' then 'Complete' 
                             when '1' then 'Pending'
                             when '2' then 'Running'
                             else 'Failed'
                            END
                           from [archiveDB].[dbo].[ipmVolume] as vol
                            join ipmExServer as ex on ex.ExServerHash32 = vol.ExServerHash32
                            group by ex.ExServerName ,vol.Status order by ex.ExServerName"
   


#select ex.ExServerName, Sum(ItemCount) as MigratedMessages, sum(ExceptionCount) as Exceptions,
#                            COUNT(VolumeName) as Volumes  from [archiveDB].[dbo].[ipmVolume] as vol
#                            join ipmExServer as ex on ex.ExServerHash32 = vol.ExServerHash32
#
#                            where vol.Status =0 group by ex.ExServerName'


##--where ex.ExServerName='ex03' and vol.Status =0 group by ex.ExServerName

$global:SQLEXServerIndex='select  ex.ExServerName, count(idx.IndexPath) as MigratedIndexes
  from [ES1InPlaceMigratedArchive].[dbo].[ipmIndex] as idx
  left join ipmExServer as ex on ex.ExServerHash32 = idx.ExServerHash32

where idx.Status =0 group by ex.ExServerName '

##--where ex.ExServerName='ex03' and 

#
# SQL to get the pending and migrated volumes for a task
#    used to compute percent complete
#       
$global:SQLTaskVolumes= "select ex.ExServerName as EXServer,tsk.Name as TaskName,
                         Status = case vol.Status
                          when '0' then 'Complete'
                          when '1' then 'Pending'
                          when '2' then 'Running'
			              when '3' then 'Failed'  
                          END,
                         COUNT(vol.Status) ProcessedVolumes, 
                          from [archiveDB].[dbo].[IPMVolume] vol
                          join ipmTask as tsk on tsk.TaskID = vol.TaskID
                         join ipmExServer as ex on ex.ExServerHash32 = vol.ExServerHash32 
                         where vol.TaskID=inJOBID  order BY ex.ExServerName"

                  
$global:SQLServerMsgExceptions="select ex.ExServerName, mv.VolumeName,mv.Status, mv.ExceptionCount,mv.MSGExceptions
                                from [dbo].[IPMVolume] mv 
                                join ipmExServer as ex on ex.ExServerHash32 = mv.ExServerHash32
                                where ex.ExServerName = 'inputEXSERVER' and exceptioncount <> 0
                                order by ex.ExServerName"

 
$global:SQLServerMsgExceptions2= "select ex.ExServerName, mv.VolumeName,mv.Status, mv.ExceptionCount,
                                 MsgExceptions.query('count(/Cf/Gp/Msg)').value('.','int')as MsgExceptions,
                                 MissingNode.query('MissingMsgs').value('.', 'int') as MissingMsgs, 
                                 ErrNode.query('MsgID').value('.', 'varchar(52)') as MsgID  ,
                                 ErrNode.query('Error').value('.', 'varchar(2048)') as Exception  
                                  FROM [archiveDB].[dbo].[ipmVolume] as mv (NOLOCK)
                                 cross apply  MsgExceptions.nodes('/Cf') as CFXML(MissingNode) 
                                 outer apply  MsgExceptions.nodes('/Cf/Gp/Msg') as ERRXML(ErrNode) 
                                join [archiveDB].[dbo].[ipmExServer] as ex on ex.ExServerHash32 = mv.ExServerHash32 
                                where ex.ExServerName = 'inputEXSERVER' and exceptioncount <> 0
                                order by ex.ExServerName"

$global:SQLAllRunningTasks= "select tsk.name as TaskName,tsk.taskid, jobid, 
                              JobType = case [JobType]
                                when '1' then 'Inventory'
                                when '2' then 'Migration'
                                when '3' then 'Volume Validation'
                                when '4' then 'Index Validation'
                                END,
                             workername from [archiveDB].[dbo].[ipmJob] (NOLOCK) as jb
                            join [archiveDB].[dbo].ipmTask as tsk on tsk.TaskID=jb.TaskID where jb.status=2 "

$global:SQL_VolumeVerifyStat="select ex.ExServerName as EX_Server, tsk.name as TaskName ,vv.TaskID, 
             Level= case vv.Level
                    when '1' then 'Basic'
                    when '2' then 'Detailed'
                    when '3' then 'Complete'
                    END,
                    count(volumename) as Volumes,
             Status = case vv.Status
                    when '0' then 'Complete'
                    when '1' then 'Pending'
                    when '2' then 'Running'
		            when '3' then 'Failed'  
		            when '4' then 'Stopped'	
                    else master.sys.fn_varbintohexstr(vv.Status)
                    END
                from [archiveDB].[dbo].ipmVolumeVerify (NOLOCK) as vv 
                join [archiveDB].[dbo].ipmTask as tsk (NOLOCK) on tsk.TaskID=vv.TaskID
                join [archiveDB].[dbo].[ipmExServer](NOLOCK) as ex on ex.ExServerHash32 = tsk.ExServerHash32
                group by ex.ExServerName,tsk.name,vv.taskid,Level,vv.status
                order by EX_Server, TaskName,Level,Status"
                
  
$global:SQL_VolumeVerifyStatbyServer="select ex.ExServerName, vfy.status as VailidationStatus, sum(vfy.Volumes)as Volumes,
                                        vfy.level as ValidationType  from
                                      (select  tsk.ExServerHash32, tsk.name, 
                                             Level= case vv.Level
                                                    when '1' then 'Basic'
                                                    when '2' then 'Detailed'
                                                    when '3' then 'Complete'
                                                    END,
                                                    count(volumename) as Volumes,
                                             Status = case vv.Status
                                                    when '0' then 'Complete'
                                                    when '1' then 'Pending'
                                                    when '2' then 'Running'
                                		            when '3' then 'Failed'  
                                		            when '4' then 'Stopped'	
                                                    else master.sys.fn_varbintohexstr(vv.Status)
                                                    END
                                                from [archiveDB].[dbo].ipmVolumeVerify (NOLOCK) as vv 
                                               join [archiveDB].[dbo].ipmTask (NOLOCK) as tsk on tsk.TaskID=vv.TaskID           
                                                group by tsk.ExServerHash32,tsk.name,level,vv.status)as vfy
                                  join [archiveDB].[dbo].[ipmExServer](NOLOCK) as ex on ex.ExServerHash32 = vfy.ExServerHash32 
                                  group by ex.ExServername,vfy.level, vfy.status    
                                  order by ex.ExServername, vfy.status"
  
  


$global:SQL_GetMaxTaskID ="select MAX(TaskID) as MaxTaskID from [archiveDB].[dbo].[ipmTask] with (NOLOCK)"

$global:SQL_FindTaskViaDesc="select * from [archiveDB].[dbo].[ipmTask] 
                             where ExServerHash32 = ? AND SrcFolderHash32 = ? AND StartMonth = ? AND EndMonth = ?"

#########################################################
#
#  Public commands
# 
##########################################################
#
#####################################

function Get-IPMVolValidationStats {
<#
.SYNOPSIS
Display a summary of Volume Validation statuses

.DESCRIPTION
Display a summary of Volume Validation statuses for each task and validation level.

.PARAMETER sqlserver
Specifies the name of the SQL server hosting the SourceOne Archive database.  Should contain the SQL instance if needed as well.
.PARAMETER achiveDB
The name of the Archive database.  The default is "ES1Archive".
.PARAMETER outRaw
If present will output the raw objects.  By default the results are piped through "Format-Table" for pretty display


.EXAMPLE
Get-IPMVolValidationStats -sql DBACL20SQL2\es1_ex -arDB ES1InplaceArchive 

#>
[CmdletBinding()]

Param([Parameter(Position=0,Mandatory=$False)]
        [Alias('sql')]
        [string]$sqlserver="",
        [Parameter(Mandatory=$False)]
        [Alias('ipmDB')]
        [string] $ipmControlDB="ES1Archive",
        [Alias('raw')]
        [switch] $outRAW=$False

         )

BEGIN {

}
	PROCESS
	{
	
	
	if (!$sqlserver -or !$ipmControlDB)
	{
		$IPMControl = @(Get-IPMControllerDB)
		$sqlserver = $IPMControl[0]
		$ipmControlDB = $IPMControl[1]
	}
	
	Write-Verbose "Get-IPMVolValidationStats  "
    Write-Verbose "SQL Server: `"$sqlserver`",  Archive DB: `"$ipmControlDB`" "
    
    $SQLStatsCommand=$global:SQL_VolumeVerifyStat.replace("archiveDB",$ipmControlDB)
      
    #$SQLStatsCommand=$global:SQL_VolumeVerifyStatbyServer.replace("archiveDB",$ipmControlDB)
    #$SQLCommand=$global:SQL_GetMaxTaskID.replace("archiveDB",$ipmControlDB)
    
      
    #Write-Debug $SQLCommand
    Write-Debug $SQLStatsCommand
    
    $curTask=1
    $allTasks=@()
    
    try {
                       
            $content=@()
                        
            $content = @(Invoke-ES1SQLQuery $sqlserver $ipmControlDB $SQLStatsCommand)
             
           #  $content | sort -property "Name", "Level", "Status" | format-table

           # $MaxTaskID=  $content[0].MaxTaskID    
            
            #while ($curTask -le $MaxTaskID)
            #{
            #    $allTasks += @(Get-IPMTaskJob -sql $sqlserver -arDB $ipmControlDB -task $curTask )
            #    $curTask++
           # 
           # }
          
           #$allTasks | sort -property "TaskName", "Level", "Status"
                     
            
        }
        catch {
            Write-Output ""
            Write-Host "Caught Exception" -foregroundcolor red
    
            Write-output ""
            Write-Error $_
        
        }

if ($outRAW )
{
    $content
}
else
{
    $content | format-table -AutoSize | Out-String -Width 10000
}   
    
}

END {}
}

#####################################

function Get-IPMStatistics {
<#
.SYNOPSIS
Display the migration statistics for all tasks and jobs
.DESCRIPTION
Display the migration statistics for all tasks and jobs
.PARAMETER sqlserver
Specifies the name of the SQL server hosting the SourceOne Archive database.  Should contain the SQL instance if needed as well.
.PARAMETER achiveDB
The name of the Archive database.  The default is "ES1Archive".


.EXAMPLE
Get-IPMStatistics -sql DBACL20SQL2\es1_ex -arDB ES1InplaceArchive 

#>
[CmdletBinding()]

Param([Parameter(Position=0,Mandatory=$False)]
        [Alias('sql')]
        [string]$sqlserver="",
        [Parameter(Mandatory=$False)]
        [Alias('ipmDB')]
        [string] $ipmControlDB="ES1Archive"
         )

BEGIN {

}
	PROCESS
	{
	
	
	if (!$sqlserver -or !$ipmControlDB)
	{
		$IPMControl = @(Get-IPMControllerDB)
		$sqlserver = $IPMControl[0]
		$ipmControlDB = $IPMControl[1]
	}
	
	Write-Verbose "Get-IPMStatistics "
    Write-Verbose "SQL Server: `"$sqlserver`",  Archive DB: `"$ipmControlDB`" "
    
    $SQLCommand=$global:SQL_GetMaxTaskID.replace("archiveDB",$ipmControlDB)
    
    Write-Debug $SQLCommand
    
    $curTask=1
    $allTasks=@()
    
    try {
                       
            $content=@()
                        
            $content = @(Invoke-ES1SQLQuery $sqlserver $ipmControlDB $SQLCommand)
             # $content  
             
            $MaxTaskID=  $content[0].MaxTaskID    
            
            while ($curTask -le $MaxTaskID)
            {
                $allTasks += @(Get-IPMTaskJob -sql $sqlserver -ipmDB $ipmControlDB -task $curTask )
                $curTask++
            
            }
          
           $allTasks | sort -property "Type","TaskName"
                     
            
        }
        catch {
            Write-Output ""
            Write-Host "Caught Exception" -foregroundcolor red
    
            Write-output ""
            Write-Error $_
        
        }
   
    
}

END {}
}


#####################################
#
function Get-IPMRunningJobs {
<#
.SYNOPSIS
Get a list of all running migration jobs
.DESCRIPTION
Get a list of all currently running migration jobs on all migration workers
.PARAMETER ipmsqlserver
Specifies the name of the SQL server hosting the SourceOne IPM Archive database with the IPM control tables
	Should contain the SQL instance if needed as well.
.PARAMETER ipmcontrolDB
The name of the IPM Archive database with the IPM control tables.  The default is "ES1IPMArchive".
.PARAMETER detail
Output detailed job data including statistics
.EXAMPLE
Get-IPMRunningJobs -sql DBACL20SQL2\es1_ex -arDB ES1InplaceArchive 
.EXAMPLE
Get-IPMRunningJobs -sql DBACL20SQL2\es1_ex -arDB ES1InplaceArchive -detail

#>
[CmdletBinding()]

Param([Parameter(Position=0,Mandatory=$False)]
        [Alias('sql')]
        [string]$sqlserver="",
        [Parameter(Mandatory=$False)]
        [Alias('ipmDB')]
        [string] $ipmControlDB="ES1IPMArchive",
        [Parameter(Mandatory=$False)]
        [Alias('d')]
        [switch] $detail=$False )

BEGIN {
   

}
PROCESS {
	

  		$runningJobs=@()
        try {
			if (!$sqlserver -or !$ipmControlDB)
			{
				$IPMControl = @(Get-IPMControllerDB)
				$sqlserver = $IPMControl[0]
				$ipmControlDB = $IPMControl[1]
			}
			
            $content=@()
			
			Write-Verbose "IPM SQL Server: `"$sqlserver`",  IPM Control DB: `"$ipmControlDB`" "
			
			$SQLCommand = $global:SQLAllRunningTasks.replace("archiveDB", $ipmControlDB)
			
			Write-Debug $SQLCommand
			
			Write-Verbose "Executing SQL Query...."
			
			
            $content = @(Invoke-ES1SQLQuery $sqlserver $ipmControlDB $SQLCommand)
#            [int] $es1Count = $content.length
#          $content             
 
            if ($detail -ne $True)
            {
              $content             
            }
            else
            {
                foreach ($job in $content)
                {
                    $runningJob+= @(Get-IPMTaskJob -sql $sqlserver -ipmDB $ipmControlDB -task $job.taskid -job $job.jobid)
                }    
              
                $runningJob           
            }
            
        }
        catch {
            Write-Output ""
            Write-Host "Caught Exception " -foregroundcolor red
            
            Write-output ""
            Write-Error $_
        
        }
   
    
}

END {}
}



#####################################
#
function Get-VolumesFromUNC {
<#
.SYNOPSIS
Get the number of EmailXtender Volumes from the specified UNC.  Optionally write the list to a file.
.DESCRIPTION
Enumerates the volumes (*.emx) files on the specified UNC and returns the count.  Optionally the list of files can be written to
an output file.
.PARAMETER UNC
The UNC path or mounted drive to get the count and list of files from

.EXAMPLE
Get-VolumesFromUNC -path \\exserver1\s$\EmailXtender
.EXAMPLE
Get-VolumesFromUNC -path \\exserver1\s$\EmailXtender -out c:\temp\exserver1Vols.txt

#>
[CmdletBinding()]

Param([Parameter(Position=0,Mandatory=$True)]
        [Alias('p')]
        [string]$path="",
        [Parameter(Mandatory=$false)]
        [Alias('out')]
        [string]$outfile="" )

BEGIN {
    $filemask="*.emx"

}
PROCESS {
    Write-Verbose "Get-VolumesFromUNC"
    Write-Verbose "Path `"$path`" "
    
   $start = get-date;
    Write-Progress -Status 'Submitting background job' -Activity "Scanning for Volumes"
    
    #
    # Do not use get-childitem for this as it is extremely slow across network connections and for
    #    other implmentation issues
    #
    $job = start-job -name getVolumes -scriptblock {param([string]$path,[string]$filemask) [reflection.assembly]::loadwithpartialname("Microsoft.VisualBasic") | Out-Null
                $files=[Microsoft.VisualBasic.FileIO.FileSystem]::GetFiles( $path,[Microsoft.VisualBasic.FileIO.SearchOption]::SearchAllSubDirectories,$filemask
                ) 
                Write-OutPut $files
                } -ArgumentList $path,$filemask

    Write-Progress -Status 'Starting...' -Activity "Searching $path"

    $end=0
    
    #
    # Wait for the background job to complete....
    #
    While ($job.State -eq 'Running')
    {
        $i+=10
        Write-Progress -Status "This may take several minutes, Please Wait...." -percentcomplete $i `
                        -Currentoperation "Searching $path" -Activity "Scanning for Volumes"
        
        # use this to simulate movement in progress bar...
        if ($i -ge 90)
        {
            $i=0
        }
            
        $foo=wait-job -Timeout 15 $job  

    }

    $end=get-date
    #
    # grab the output from the job..
    $files = receive-job $job 
    
    # if an output file was specified write the list of files to it.
    if ($outfile -ne "")
    {
      $files | out-file $outfile
    }
    

    Write-Host 'Found ' $files.Count 'Volumes on' $path

    $elapsed=$end-$start
    Write-Host 'Elapsed time: '$elapsed.TotalMinutes.ToString("N") 'minutes'
    
}

END {}
}



#############################################
function Get-IPMJobErrors {
<#
.SYNOPSIS
Get Errors for a particular Job
.DESCRIPTION
Get the <ErrorList> from the job xConfig which contains a list of the specific errors that a job encountered
.PARAMETER sqlserver
Specifies the name of the SQL server hosting the SourceOne Archive database.  Should contain the SQL instance if needed as well.
.PARAMETER achiveDB
The name of the Archive database.  The default is "ES1Archive".
.PARAMETER jobID
The migration job ID

.EXAMPLE
Get-IPMJobErrors -sql DBACL20SQL2\es1_ex -arDB ES1InplaceArchive -jobid 1

#>
[CmdletBinding()]

Param([Parameter(Position=0,Mandatory=$False)]
        [Alias('sql')]
        [string]$sqlserver="",
        [Parameter(Mandatory=$False)]
        [Alias('ipmDB')]
        [string] $ipmControlDB="ES1Archive",
        [Parameter(Mandatory=$True)]
        [Alias('job')]
        [string] $jobID=""  )
     


BEGIN {

}
	PROCESS
	{
	
	if (!$sqlserver -or !$ipmControlDB)
	{
		$IPMControl = @(Get-IPMControllerDB)
		$sqlserver = $IPMControl[0]
		$ipmControlDB = $IPMControl[1]
	}
		
	Write-Verbose "Get-IPMJobErrors "
    Write-Verbose "SQL Server: `"$sqlserver`",  Archive DB: `"$ipmControlDB`" "
    
    $SQLCommand=$global:SQLGetMigJobErrors.replace("archiveDB",$ipmControlDB)
    $SQLCommand=$SQLCommand.replace("inJOBID",$jobID)
 

    Write-Debug $SQLCommand
   
    Write-Verbose "Executing SQL Query...."
   
        try {
                       
            $content=@()
            $migratedMsgs=@()
            
            $content = @(Invoke-ES1SQLQuery $sqlserver $ipmControlDB $SQLCommand)
            
            #
            # Compute percent complete
            #
 
            
            [int] $es1Count = $content.length
                     
          
          $content  
                     
            
        }
        catch {
            Write-Output ""
            Write-Host "Exception excuting SQL Query" -foregroundcolor red
            Write-Verbose $SQLCommand
            Write-output ""
            Write-Error $_
        
        }
   
    
}

END {}
}



#####################################

function Get-IPMMsgExceptions {
<#
.SYNOPSIS
Get the Volumes for an EmailXtender Server with message exceptions
.DESCRIPTION
Get the Volumes for an EmailXtender Server with message exceptions and roughly parse the exception XML.  XML
has the format:
            <Cf><Gp><Msg>
                <MsgID>435F41590000000000000000435F415942FCD0D49103A22701</MsgID>
                <Error>Mismatch Address id [MAPIPDL:"West Enterprise SR"&lt;&gt;] EmailXtenderID [4A8E552266400B01] SourceOneID [04B2008FD98C1DD4]</Error>
            </Msg></Gp></Cf>
.PARAMETER sqlserver
Specifies the name of the SQL server hosting the SourceOne Archive database.  Should contain the SQL instance if needed as well.
.PARAMETER achiveDB
The name of the Archive database.  The default is "ES1Archive".
.PARAMETER exserver
The EmialXtender server name

.EXAMPLE
Get-IPMMsgExceptions -sql DBACL20SQL2\es1_ex -arDB ES1InplaceArchive -exserver ex01

#>
[CmdletBinding()]

Param([Parameter(Position=0,Mandatory=$True)]
        [Alias('sql')]
        [string]$sqlserver="",
        [Parameter(Mandatory=$False)]
        [Alias('ipmDB')]
        [string] $ipmControlDB="ES1IPMArchive",
        [Parameter(Mandatory=$True)]
        [Alias('ex')]
        [string] $exserver="" )
     


BEGIN {

}
	PROCESS
	{
	
	if (!$sqlserver -or !$ipmControlDB)
	{
		$IPMControl = @(Get-IPMControllerDB)
		$sqlserver = $IPMControl[0]
		$ipmControlDB = $IPMControl[1]
	}
	
	Write-Verbose "Get-IPMMsgExceptions "
    Write-Verbose "SQL Server: `"$sqlserver`",  Archive DB: `"$ipmControlDB`" "
    
    $SQLCommand=$global:SQLServerMsgExceptions2.replace("archiveDB",$ipmControlDB)
    $SQLCommand=$SQLCommand.replace("inputEXSERVER",$exserver)
 

    
    Write-Debug $SQLCommand
   
    Write-Verbose "Executing SQL Query...."
   
        try {
                       
            $content=@()
            $exceptionOutput=@()
            
            Write-Progress -Activity "Getting exceptions..." -Status "Please wait..." -id 1
              
            $content = @(Invoke-ES1SQLQuery $sqlserver $ipmControlDB $SQLCommand)
            
                        
            [int] $es1Count = $content.length
            
            Write-Progress -Activity "Done" -Completed -Status "Done"
           
            $content
           
  
            
        }
        catch {
            Write-Output ""
            Write-Host "Exception excuting SQL Query" -foregroundcolor red
            Write-Verbose $SQLCommand
            Write-output ""
            Write-Error $_
        
        }
   
    
}

END {}
}


##########################################################
function Get-IPMTaskJob {
<#
.SYNOPSIS
Get the SourceOne migration job and instance data 
.DESCRIPTION
Get the SourceOne migration job and instance data 
.PARAMETER sqlserver
Specifies the name of the SQL server hosting the SourceOne Archive database.  Should contain the SQL instance if needed as well.
.PARAMETER achiveDB
The name of the Archive database.  The default is "ES1Archive".
.PARAMETER taskID
The migration task ID
.PARAMETER jobID
The migration task job id.  The default to return all instances
.PARAMETER exportCSV
Filename to export the task and job data into

.EXAMPLE
Get-IPMTaskJob -sql DBACL20SQL2\es1_ex -arDB ES1InplaceArchive -task 1
.EXAMPLE
Get-IPMTaskJob -sql DBACL20SQL2\es1_ex -arDB ES1InplaceArchive -task 1 -job 3
.EXAMPLE
Get-IPMTaskJob -sql DBACL20SQL2\es1_ex -arDB ES1InplaceArchive -task 1 -csv c:\temp\task1.csv

#>
[CmdletBinding()]

Param([Parameter(Position=0,Mandatory=$False)]
        [Alias('sql')]
        [string]$sqlserver="",
        [Parameter(Mandatory=$False)]
        [Alias('ipmDB')]
        [string] $ipmControlDB="ES1Archive",
        [Parameter(Mandatory=$True)]
        [Alias('task')]
        [string] $taskID="",
        [Parameter(Mandatory=$False)]
        [Alias('job')]
        [string] $jobID="",      
        [Parameter(Mandatory=$False)]
        [Alias('csv')]
        [string] $exportCSV="")
     


BEGIN {

}
	PROCESS
	{
	
	if (!$sqlserver -or !$ipmControlDB)
	{
		$IPMControl = @(Get-IPMControllerDB)
		$sqlserver = $IPMControl[0]
		$ipmControlDB = $IPMControl[1]
	}
	
	Write-Verbose "Inside Get-IPMTaskJob command"
    Write-Verbose "SQL Server: `"$sqlserver`",  Archive DB: `"$ipmControlDB`" "
    
    # Insert the archive db and task ID into the query string
    $SQLCommand=$global:SQLGetMigJob.replace("archiveDB",$ipmControlDB)
    
    $SQLCommand=$SQLCommand.replace("inJOBID",$taskID)
 
    #
    # If an instance was specific append the instance qualifyer to the SQL query
     if ($jobID -ne "" ) 
      {         
        $SQLCommand += " AND jobID = '$jobID'"
       }
       
     if ($exportCSV -ne "" ) 
      {         
        
      }
       
    Write-Debug $SQLCommand
   
    Write-Verbose "Executing SQL Query...."
   
        try {
                       
            $content=@()
            $migratedMsgs=@()
            
            #
            # Execute the SQL query
            $content = @(Invoke-ES1SQLQuery $sqlserver $ipmControlDB $SQLCommand)
     
            #
            # Compute the elapsed time and add that object to the results
            #  (now done in the query... JR), but needed to compute MSG/SEC
            
           # $content | Add-Member ScriptProperty -Name "Elapsed" -Value {(New-TimeSpan $this.StartTime $this.UpdateTime) } 
          
            [int] $es1Count = $content.length
            #Write-Output ""

        
            # for each jobinstance compute the Messages per second
           
            foreach ($jobIns in $content )
            {
                # Insert the archive db and instance ID into the query string
                $SQLCommand=$global:SQLJobMsgs.replace("archiveDB",$ipmControlDB)
                $SQLCommand=$SQLCommand.replace("jobinstance",$jobIns.jobId)
            
                # execute the SQL query
                $migratedMsgs =@( Invoke-ES1SQLQuery $sqlserver $ipmControlDB $SQLCommand)
                
                                
                #
                # If the inventory process is running and no messages have been processed
                #  the sql query will return an empty object, and the math throws an exception
                if ($migratedMsgs[0].MigratedMessages -ne [DBNull]::Value)
                {
                    #
                    # Compute messages per second...
                    #
                    $JobElaspedTime = New-TimeSpan $jobIns.StartTime $jobIns.UpdateTime
                    $msgSec=[Math]::Round(($migratedMsgs[0].MigratedMessages/ $JobElaspedTime.TotalSeconds),2)
                   
                }
                else 
                {
                    $msgSec = 0
                   
                }
                 
                 # Compute volumes per hour
#                 if ($jobIns.ProcessedVolumes -gt 0 )
#                 {
#                    $volsHour=[Math]::Round(($jobIns.ProcessedVolumes/ $jobIns.Elapsed.TotalHours),1)
#                 }
#                 else
#                 {
#                    $volsHour=0
#                 }
#                
                # Append 
           
                $jobIns | Add-Member NoteProperty -Name "Messages" -Value $migratedMsgs[0].MigratedMessages 
                $jobIns | Add-Member NoteProperty -Name "Exceptions" -Value $migratedMsgs[0].Exceptions
           
                $jobIns | Add-Member NoteProperty -Name "Msgs/Sec" -Value $msgSec
 #               $jobIns | Add-Member NoteProperty -Name "Vols/Hr" -Value $volsHour
            
                
            }
            
          # Output and re-order the columns
          if ($exportCSV -ne "" ) 
            {         
            $content  | select-object  ElapsedTime ,TaskName,Type,TaskID,JobID,Status,"Volumes/Hr","Msgs/Sec", `
                                     ProcessedVolumes,ProcessedIndexes,Messages,Exceptions,StartTime,UpdateTime,WorkerName `
                      | export-csv -notype $exportCSV
        
            }
            else
            {
            $content  | select-object  ElapsedTime ,TaskName,Type,TaskID,JobID,Status,"Volumes/Hr","Msgs/Sec", `
                                     ProcessedVolumes,ProcessedIndexes,Messages,Exceptions,StartTime,UpdateTime,WorkerName
                     
             }
          
              
            
        }
        catch {
            Write-Output ""
            Write-Host "Exception excuting SQL Query" -foregroundcolor red
            Write-Verbose $SQLCommand
            Write-output ""
            Write-Error $_
        
        }
   
    
}

END {}
}
#####################################

function Get-IPMProgress {
<#
.SYNOPSIS
Get the SourceOne migration progress by EmailXtender server
.DESCRIPTION
Get the SourceOne migration progress for EmailXtender servers.  Output includes the total Volumes,Indexes,
Messages and Validated Volumes for the validation level specified.

.PARAMETER sqlserver
Specifies the name of the SQL server hosting the SourceOne Archive database.  Should contain the SQL instance if needed as well.
.PARAMETER achiveDB
The name of the Archive database.  The default is "ES1Archive".
.PARAMETER outRaw
If present will output the raw objects.  By default the results are piped through "Format-Table" for pretty display


.EXAMPLE
Get-IPMProgress -sql DBACL20SQL2\es1_ex -arDB ES1InplaceArchive 

#>
[CmdletBinding()]

Param([Parameter(Position=0,Mandatory=$False)]
        [Alias('sql')]
        [string]$sqlserver="",
        [Parameter(Mandatory=$False)]
        [Alias('ipmDB')]
        [string] $ipmControlDB="ES1Archive",
        [Parameter(Mandatory=$False)]
        [Alias('raw')]
        [switch] $outRAW=$False
         )

BEGIN {

}
	PROCESS
	{
	if (!$sqlserver -or !$ipmControlDB)
	{
		$IPMControl = @(Get-IPMControllerDB)
		$sqlserver = $IPMControl[0]
		$ipmControlDB = $IPMControl[1]
	}
	Write-Verbose "Get-IPMProgress "
    Write-Verbose "SQL Server: `"$sqlserver`",  Archive DB: `"$ipmControlDB`" "
    
    
    $SQLStatsCommand= 'select ex.exservername as EX_Server, vol.Volumes as MigratedVolumes,ix.Indexes as MigratedIndexes,
                       vol.MigratedMessages, vfy.ValidatedVolumes from 
                      (select ExServerHash32, Sum(ItemCount) as MigratedMessages , COUNT(VolumeName)as Volumes
                      from [archiveDB].[dbo].[ipmVolume] (NOLOCK) where status!=1
                      group by ExServerHash32)as vol 
                      join 
                       (select ExServerHash32, COUNT(Status) Indexes from [archiveDB].[dbo].[ipmIndex](NOLOCK) where status!=1
                         group by ExServerHash32) as ix 
                         on vol.ExServerHash32=ix.ExServerHash32
                      join
                       (select  tsk.ExServerHash32 , count(volumename) as ValidatedVolumes
                         from [archiveDB].[dbo].[ipmVolumeVerify] (NOLOCK)as vv 
                         join [archiveDB].[dbo].[ipmTask] as tsk on tsk.TaskID=vv.TaskID
                         where vv.Level=3 and vv.status!=1
                         group by tsk.ExServerHash32)as vfy
                         on vfy.ExServerHash32 = vol.ExServerHash32
                        join [archiveDB].[dbo].[ipmExServer](NOLOCK) as ex on ex.ExServerHash32 = vol.ExServerHash32    
                        order by ex.ExServerName'


    $SQLCommand=$SQLStatsCommand.replace("archiveDB",$ipmControlDB)
  #  $SQLCommand=$SQLCommand.replace("inJOBID",$taskID)
 
 
    
    Write-Debug $SQLCommand
   
    Write-Verbose "Executing SQL Query...."
   
        try {
                       
            $content=@()
            
            $content = @(Invoke-ES1SQLQuery $sqlserver $ipmControlDB $SQLCommand )
            
            #
            # Compute percent complete
            #
 
            
            [int] $es1Count = $content.length
                     
          if ($outRaw)
          {
            $content  
          }
          else
          {
            $content  | Format-Table -AutoSize | Out-String -Width 10000
          }
                     
            
        }
        catch {
            Write-Output ""
            Write-Host "Get-IPMProgress Exception " -foregroundcolor red
            Write-output ""
            Write-Error $_
        
        }
   
    
}

END {}
}

#####################################

function Get-IPMTaskProgress {
<#
.SYNOPSIS
Get the SourceOne migration progress by EmailXtender server, by task.

.DESCRIPTION
Get the SourceOne migration progress for EmailXtender servers on a per task basis.  Output includes the count of Volumes
by status.

.PARAMETER sqlserver
Specifies the name of the SQL server hosting the SourceOne Archive database.  Should contain the SQL instance if needed as well.
.PARAMETER achiveDB
The name of the Archive database.  The default is "ES1Archive".
.PARAMETER outRaw
If present will output the raw objects.  By default the results are piped through "Format-Table" for pretty display

.EXAMPLE
    Get-IPMTaskProgress -sql DBACL20SQL2\es1_ex -arDB ES1InplaceArchive 

#>
[CmdletBinding()]

Param([Parameter(Position=0,Mandatory=$False)]
        [Alias('sql')]
        [string]$sqlserver="",
        [Parameter(Mandatory=$False)]
        [Alias('ipmDB')]
        [string] $ipmControlDB="ES1Archive",
        [Parameter(Mandatory=$False)]
        [Alias('raw')]
        [switch] $outRAW=$False
         )

BEGIN {

}
	PROCESS
	{
	if (!$sqlserver -or !$ipmControlDB)
	{
		$IPMControl = @(Get-IPMControllerDB)
		$sqlserver = $IPMControl[0]
		$ipmControlDB = $IPMControl[1]
		}
		
		Write-Verbose "Get-IPMTaskProgress "
    Write-Verbose "SQL Server: `"$sqlserver`",  Archive DB: `"$ipmControlDB`" "
    
    
    $SQLStatsCommand= "select ex.ExServerName as EXServer,tsk.Name as TaskName,
                 VolumeMigStatus = case vol.Status
                 when '0' then 'Completed OK'
                 when '1' then 'Pending'
                 when '2' then 'Running'
            	 when '3' then 'Failed'
            	 else 'Failed : ' + master.sys.fn_varbintohexstr(vol.Status)  
                  END,
                  COUNT(vol.Status) ProcessedVolumes 
                  from [archiveDB].[dbo].[IPMVolume] as vol
                  join [archiveDB].[dbo].[ipmTask] as tsk on tsk.TaskID = vol.TaskID
                  join [archiveDB].[dbo].[ipmExServer] as ex on ex.ExServerHash32 = vol.ExServerHash32 
                  group by ex.ExServerName, tsk.Name, vol.Status
            	order BY ex.ExServerName, tsk.Name, VolumeMigStatus"


    $SQLCommand=$SQLStatsCommand.replace("archiveDB",$ipmControlDB)
  #  $SQLCommand=$SQLCommand.replace("inJOBID",$taskID)
 
 
    
    Write-Debug $SQLCommand
   
    Write-Verbose "Executing SQL Query...."
   
        try {
                       
            $content=@()
            
            $content = @(Invoke-ES1SQLQuery $sqlserver $ipmControlDB $SQLCommand )
            
            #
            # Compute percent complete
            #
 
            
            [int] $es1Count = $content.length
                     
          if ($outRaw)
          {
            $content  
          }
          else
          {
            $content  | Format-Table -AutoSize | Out-String -Width 10000
          }
                     
            
        }
        catch {
            Write-Output ""
            Write-Host "Get-IPMTaskProgress Exception " -foregroundcolor red
            Write-output ""
            Write-Error $_
        
        }
   
    
}

END {}
}

function Collect-IPMRunningJobStats {
<#
.SYNOPSIS
    Collects statistics about running IPM jobs into a csv file

.DESCRIPTION
    Collects statistics about running IPM jobs into a csv file.
    Can be used to capture the progression of performance over some perioed of time.  This is designed
    to be wrapped in another script which can be scheduled to run using Windows Task Scheduler.

    The CSV file is appended to if it exists.

.PARAMETER exportCSV
    Full path and filename of the CSV file to contain the data.

.PARAMETER transcript
    Transcipt/log file to capture output that would go to the console or scren if run interactively.
    Useful for troubleshooting when running in a background task.


.EXAMPLE
    Collect-IPMRunningJobStats -csv IPMStats.csv

#>
[CmdletBinding()]

Param( [Parameter(Mandatory=$False)]
        [Alias('csv')]
        [string] $exportCSV="",
        [Parameter(Mandatory=$False)]
        [Alias('log')]
        [string] $transcript=""
         )

BEGIN {

}
	PROCESS
	{
        if ( $transcript )
        {
        Start-Transcript -Path $transcript -Append
        }
	
		$IPMControl = @(Get-IPMControllerDB)
		$dbserver = $IPMControl[0]
		$dbname = $IPMControl[1]
		
		
        Write-Verbose "Get-IPMRunningJobStats"
        Write-Verbose "SQL Server: `"$dbserver`",  Archive DB: `"$dbname`" "
    
    #
    # This query is derived from queries used by the IPMJobMonitor...
    #
$SQLCommand = @'
select Getdate() as TimeOfSample, srvr.ExServerName as EXServer, tsk.Name as TaskName,
	Type = CASE JobType
		when '1' then 'Inventory'
        when '2' then 'Migration'
        when '3' then 'Volume Validation'
        when '4' then 'Index Validation'
        END,
    job.[JobID], job.TaskID as TaskID,ProcessedVolumes,ProcessedIndexes,  
    CAST(job.ProcessedVolumes / NULLIF (DATEDIFF(ss, job.CreatedTime,  
    job.LastUpdatedTime) / 3600.0, 0.00) AS decimal(10, 1)) AS 'VolumesPerHr', 
    Status = case job.Status 
    when '0' then 'Complete' 
    when '1' then 'Pending' 
    when '2' then 'Running' 
    when '3' then 'Failed'  
    when '4' then 'Stopped' 
    else master.sys.fn_varbintohexstr(job.Status) 
    END, 
    job.[CreatedTime] as StartTime, job.[LastUpdatedTime] as UpdateTime, 
    convert(varchar, DATEDIFF(s, job.CreatedTime, job.LastUpdatedTime) / (60 * 60 * 24)) + ':' + 
    CONVERT(varchar, DATEADD(s, DATEDIFF(ss, job.CreatedTime, job.LastUpdatedTime), 0), 108) AS ElapsedTime,  
    [WorkerName] , vol.Messages,vol.Exceptions,volcnt.TotalVols, volcnt.Pending,volcnt.Done,volcnt.Running 
    from [ipmJob] (NOLOCK) as job 
    join ipmTask as tsk on tsk.TaskID=job.TaskID 
    join ipmExServer as srvr on tsk.ExServerHash32=srvr.ExServerHash32 
    left outer join ((select jobid, Sum(ItemCount) as Messages,sum(ExceptionCount) as Exceptions 
    from [ipmVolume] (NOLOCK) where Status =0 group by JobID)) as vol on vol.JobID=job.JobID 
     join 
     ( (select taskid, COUNT(volumename) as TotalVols, 
     sum (case Status when 1 then 1 else 0 end) as Pending, 
     sum (case Status when 0 then 1 else 0 end) as Done, 
     sum (case Status when 2 then 1 else 0 end) as Running 
     from [ipmVolume] (NOLOCK) group by TaskID ) )
     as volcnt on volcnt.TaskID=job.TaskID 
    where job.Status=2
     Order By srvr.ExServerName, tsk.Name, job.JobID

'@

    
    Write-Debug $SQLCommand
   
    Write-Verbose "Executing SQL Query...."
    $content=@()

   
    try {
            
            
         $content = @(Invoke-ES1SQLQuery $dbserver $dbname $SQLCommand)
            
         [int] $es1Count = $content.length

         if ($es1Count -gt 0)
         {
              
              if ($exportCSV -ne "" ) 
              {         

                    $content | export-csv -notype -Append -Path $exportCSV
        
              }
              else
              {
                    Write-Warning "No output CSV file specified !"

              }

              # Output subset of column for display
              Write-Warning "The output CSV file contains additional data not displayed."
              Write-Output ""
             $content  | Format-Table -Property TimeOfSample,EXServer,TaskName,Type, VolumesPerHr,ElapsedTime,TotalVols,Done,Running,Pending `
                        -AutoSize |Out-String -Width 10000
         }
         else
         {
            Write-Output "---------------------------------------------"
            Write-Output ""
            Write-Output "No Running jobs found." 
            Write-Output ""
            Write-Output "---------------------------------------------"
         }
                     
      }

    catch {
        Write-Output ""
        Write-Host "Collect-IPMRunningJobStats Exception " -foregroundcolor red
        Write-output ""
        Write-Error $_
        
    }
   
   if ( $transcript )
   {
    Stop-Transcript
    }
    
}

END {}
}


function Get-IPMSummaryStats {
<#
.SYNOPSIS
	Not Implemented  !!

.DESCRIPTION
	Not Implemented !!

.PARAMETER outRaw
If present will output the raw objects.  By default the results are piped through "Format-Table" for pretty display

.EXAMPLE


#>
[CmdletBinding()]

Param( [Parameter(Mandatory=$False)]
        [Alias('raw')]
        [switch] $outRAW=$False
         )

BEGIN {

		Write-Error 'Sorry, Not Implemented Yet !!'
        break

}
	PROCESS
	{
	
		$IPMControl = @(Get-IPMControllerDB)
		$dbserver = $IPMControl[0]
		$dbname = $IPMControl[1]
		
		
	Write-Verbose "Get-IPMSummaryStats"
    Write-Verbose "SQL Server: `"$dbserver`",  Archive DB: `"$dbname`" "
    
$SQLCommand = @'
-- Job Type:
-- Inventory = 1
-- Migration = 2
-- Validate Volumes = 3
-- Validate Indexes = 4
--
-- Job Status:
-- Complete = 0
-- Pending = 1
-- Running = 2
-- Failed = 3
-- Stopped = 4
-- Failed Other = -2046540530, -2147482021, etc.
-- 

Select j.JobID, j.CreatedTime, j.LastUpdatedTime, ex.ExServerName, ex.DXCenteraFlag, t.DestinationFolder, t.Name AS TaskName, t.StartMonth, t.EndMonth, j.JobType, j.Status, j.ProcessedVolumes, j.ProcessedIndexes, j.WorkerName, j.xConfig.value('(/MigrationParams/ReportPath)[1]','nvarchar(max)') AS ReportPath, 
	Type = CASE j.JobType
		when '1' then 'Inventory'
        when '2' then 'Migration'
        when '3' then 'Volume Validation'
        when '4' then 'Index Validation'
        END,
    JobStatus = CASE j.Status
        when '0' then 'Complete'
        when '1' then 'Pending'
        when '2' then 'Running'
        when '3' then 'Failed'  
        when '4' then 'Stopped'             
        else 'Failed ' + master.sys.fn_varbintohexstr(j.Status)
        END,
    j.xConfig.query('count(/MigrationParams/ErrorList/Error)').value('.','int')as ErrCount,
    REPLACE(j.xConfig.value('(/MigrationParams/ErrorList/Error)[last()]','nvarchar(max)'),CHAR(10),' ') AS LastError

From ipmJob j (nolock)
Join ipmTask t (nolock) On t.TaskID = j.TaskID
Join ipmExServer ex (nolock) On ex.ExServerHash32 = t.ExServerHash32
Where j.JobType > 1
Order By ex.ExServerName, t.Name, j.JobID

'@

	$dtOutput=@()
		
    
	$friendlyname = $dbserver.Replace('\','_') + "-$dbname"
  
    Write-Debug $SQLCommand
   
    Write-Verbose "Executing SQL Query...."
   
        try {
                       
            $content=@()
            
            $content = @(Invoke-ES1SQLQuery $dbserver $dbname $SQLCommand )
         
            [int] $es1Count = $content.length
                     
          if ($outRaw)
          {
            $content  
          }
          else
          {
            $content  | Format-Table -AutoSize | Out-String -Width 10000
          }
                     
            
        }
        catch {
            Write-Output ""
            Write-Host "Get-IPMSummaryStats Exception " -foregroundcolor red
            Write-output ""
            Write-Error $_
        
        }
   
    
}

END {}
}



#====================================================================
#

New-Alias IPMJob            Get-IPMTaskJob
New-Alias IPMTaskProgress   Get-IPMTaskProgress
New-Alias IPMExceptions     Get-IPMMsgExceptions

New-Alias IPMJobErr         Get-IPMJobErrors
New-Alias CountVolumes      Get-VolumesFromUNC
New-Alias IPMRunning        Get-IPMRunningJobs
New-Alias IPMStats          Get-IPMStatistics
New-Alias IPMVolValStats    Get-IPMVolValidationStats
New-Alias IPMProgress       Get-IPMProgress
#
#   Public Exports
#
Export-ModuleMember -Function * -Alias *




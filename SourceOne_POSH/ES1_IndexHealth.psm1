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
		Functions for inspecting SourceOne operations and getting health and status information
		related to Indexes.
		Functions adapted from Mike Tramont's S1emIndexMon.ps1 Health Check scripts

#>

#requires -Version 3

<#
.SYNOPSIS
  
.DESCRIPTION
  
.OUTPUTS

.EXAMPLE

#>
Function Get-ArchiveIndexStatus
{
	[CmdletBinding()]
PARAM (
	[Parameter(Position=0,Mandatory=$false)]
	$index_age_filter = 48
	)
BEGIN {
	$scriptStart = Get-Date
    
	# Change to script location
   	$scriptDirectory  = Split-Path -parent $PSCommandPath
    Set-Location $scriptDirectory
}


PROCESS {

Try
{
    $returnCode = 0
  
	$Archives = Get-ES1ArchiveDatabases

    #
    # Get Indexes in Error State
    #
    $cErrorStateIndexes = @()
	 foreach ($archive in $Archives)
	   {
       
            $dbName = $archive.DBName
            $dbServer = $archive.DBServer
     
            #
            # Query if this is an IPM Database
            #
            $ipm_database = $false
            
            $sqlQuery = @'
SELECT
	ConfigXML.value('(/ExAsCommonCfg/InPlaceMigrationOptions/EnableMigrationDB)[1]','int') AS EnableMigrationDB,
	ConfigXML.value('(/ExAsCommonCfg/InPlaceMigrationOptions/EnableMigrationArchive)[1]','int') AS EnableMigrationArchive
FROM ServerInfo (NOLOCK)
WHERE ServerName = 'ExAsCommon'
'@     

            $dtResults = Invoke-ES1SQLQuery $dbServer $dbName $sqlQuery
            if ($dtResults.EnableMigrationArchive -eq 1)
            {
                $ipm_database = $true
            }
            
            if ($ipm_database)
            {
                Add-Log "DATABASE $dbName on $dbServer`:  IPM Database"
            }
            else
            {
                Add-Log "DATABASE $dbName on $dbServer`:  Non-IPM Database"
            }
     
            Add-Log "DATABASE $dbName on $dbServer`:  Querying Indexes for Flagged Errors"
            
            #
            # Define SQL Query
            #
            $sqlQuery = @'
SELECT REPLACE(fp.Path, '\FPROOT\', '') AS FolderMonth, fti.IndexNum, fti.TotalDocs AS TotalIndexedDocs, fti.IndexFlags, fti.IndexSize AS IndexSize_MB, fti.MsgStartDate, fti.MsgEndDate
FROM FTIndex fti (NOLOCK)
JOIN FolderPlan fp (NOLOCK) on fp.FolderId = fti.FolderNodeID
WHERE fti.IndexFlags NOT IN (0,4,64)
ORDER BY FolderMonth, fti.IndexNum 
'@
    
            $dtResults = Invoke-ES1SQLQuery $dbServer $dbName $sqlQuery
            
            if ($dtResults -ne $null)
            {      
                Add-Log ("DATABASE $dbName on $dbServer`:  Indexes In Error State:  " + @($dtResults).Count)
                
                # Process Indexes From SQL
                foreach ($row in $dtResults)
                {
                    $object = New-Object System.Object
                    $object | Add-Member -MemberType NoteProperty -Name SQLServer -value $dbServer
                    $object | Add-Member -MemberType NoteProperty -Name Database -value $dbName
                    $object | Add-Member -MemberType NoteProperty -Name FolderMonth -value $row.FolderMonth
                    $object | Add-Member -MemberType NoteProperty -Name IndexNum -value $row.IndexNum
                    $object | Add-Member -MemberType NoteProperty -Name IndexFlags -value $row.IndexFlags
                    $object | Add-Member -MemberType NoteProperty -Name IndexSize_MB -value $row.IndexSize_MB                                        
                    $object | Add-Member -MemberType NoteProperty -Name TotalIndexedDocs -value $row.TotalIndexedDocs
                    $cErrorStateIndexes += $object
                }
            }
            else
            {
                Add-Log ("DATABASE $dbName on $dbServer`:  Indexes In Error State:  0")            
            }                                  
       
    }
    Add-Log ("Indexes In Error State:  " + $cErrorStateIndexes.Count)

    #
    # Scan for Missing Indexes & Indexes with Message Count Mismatch
    #
    $cMissingIndexes = @()
    $cCountMismatchIndexes = @()
   foreach ($archive in $Archives)
    {
       
            $dbName = $archive.DBName
            $dbServer = $archive.DBServer
     
            #
            # Query if this is an IPM Database
            #
            $ipm_database = $false
            
            $sqlQuery = @'
SELECT
	ConfigXML.value('(/ExAsCommonCfg/InPlaceMigrationOptions/EnableMigrationDB)[1]','int') AS EnableMigrationDB,
	ConfigXML.value('(/ExAsCommonCfg/InPlaceMigrationOptions/EnableMigrationArchive)[1]','int') AS EnableMigrationArchive
FROM ServerInfo (NOLOCK)
WHERE ServerName = 'ExAsCommon'
'@     

            $dtResults = Invoke-ES1SQLQuery $dbServer $dbName $sqlQuery
            if ($dtResults.EnableMigrationArchive -eq 1)
            {
                $ipm_database = $true
            }
            
            if ($ipm_database)
            {
                Add-Log "DATABASE $dbName on $dbServer`:  IPM Database"
            }
            else
            {
                Add-Log "DATABASE $dbName on $dbServer`:  Non-IPM Database"
            }


            Add-Log "DATABASE $dbName on $dbServer`:  Querying Index Locations"

            # Define SQL Query
            $sqlQuery = @'
SELECT REPLACE(Path,'\FPROOT','') AS ArchiveFolder, NodeProps.value('(/fpprops/IndexLocation)[1]','nvarchar(max)') AS FTLS
FROM FolderPlan (NOLOCK)
WHERE Type = 1
'@

            $dtResults = Invoke-ES1SQLQuery $dbServer $dbName $sqlQuery
            
            # Populate Hash of Index Locations
            $hIdxPaths = @{}
            foreach ($row in $dtResults)
            {
                $aValues = $row.FTLS.Split(";")
                foreach ($path in $aValues)
                {
                    if ($path.Contains("]"))
                    {
                        $bValues = $path.Split("]")
                        if ($bValues[1].Length -gt 0)
                        {
                            $hIdxPaths[$bValues[1]] = $True
                        }
                        
                    }
                    else
                    {
                        if ($path.Length -gt 0)
                        {
                            $hIdxPaths[$path] = $True
                        }
                    }
                }
            }
            
            # Delete temp IDX output file if it exists
            $tempIdxFile = $scriptDirectory + "\tempidxlist.txt"
            if (Test-Path $tempIdxFile)
            {
                Remove-Item $tempIdxFile
            }            
            
            # Scan Index paths
            foreach ($path in $hIdxPaths.Keys)
            {
                Add-Log ("Scanning Path:  " + $path)
                 
                if (Test-Path $path)
                {
                    # Not using Get-ChildItem -Recurse because it's too slow, especially over CIFS Shares.
                    # Using old fashioned cmd shell "dir" which is much faster for what we need.
                    cmd /c dir "`"${path}\ISYS.IXB`"" /s /b 2>$null >> $tempIdxFile
                }
                else
                {
                    Add-Log ("Path Does not exist:  " + $path)    
                }
            }

            # Process Scanned Indexes
            $hIndexes = @{}    
            if (Test-Path $tempIdxFile)
            {            
                $reader = [System.IO.File]::OpenText($tempIdxFile)
                try
                {
                    while ($reader.Peek() -ne -1)
                    {
                        $line = $reader.ReadLine()
                        if ($line -eq $null) { break }
                        
                        if ($ipm_database)
                        {
                            $hIndexes[$line.Replace('\ISYS.IXB','')] = $line
                        }
                        else
                        {
                            $aValues = $line.Split('\')
                            
                            if ($aValues.Length -ge 4)
                            {
                                $folder = $aValues[$aValues.Length - 4]
                                $calmonth = $aValues[$aValues.Length - 3]
                                $index = $aValues[$aValues.Length - 2]
                            
                                $volkey = "$folder\$calmonth\$index"
                                $hIndexes[$volkey] = $line
                            }
                        }
                    }
                }
                finally
                {
                    $reader.Close()
                }
            }      
            Add-Log ("Indexes found on File Systems/CIFS Shares:  " + $hIndexes.Count)

            # Query All Indexes from the current Archive Database and Check which ones are missing
            # Define SQL Query
            if ($ipm_database)
            {
                $sqlQuery = @'
SELECT fti.IndexPath, fti.IndexFlags, fti.IndexSize AS IndexSize_MB, fti.TotalDocs AS TotalIndexedDocs
FROM FTIndex fti (NOLOCK)
WHERE fti.TotalDocs > 0
ORDER BY fti.IndexPath, fti.IndexNum            
'@            
            }
            else
            {
                $sqlQuery = @'
SELECT REPLACE(fp.Path,'\FPROOT\','') + REPLACE(STR(fti.IndexNum, 3), SPACE(1), '0') AS IndexPath, fti.IndexFlags, fti.IndexSize AS IndexSize_MB, fti.TotalDocs AS TotalIndexedDocs
FROM FTIndex fti (NOLOCK)
JOIN FolderPlan fp (NOLOCK) ON fp.FolderID = fti.FolderNodeId
WHERE fti.TotalDocs > 0
ORDER BY fp.Path, fti.IndexNum
'@
            }

            $dtResults = Invoke-ES1SQLQuery $dbServer $dbName $sqlQuery
            
            if ($dtResults -ne $null)
            {
                # Process Indexes From SQL
                foreach ($row in $dtResults)
                {
                    if (! $hIndexes.ContainsKey($row.IndexPath))
                    {
                        Add-Log ("Missing Index:  " + $row.IndexPath)
                        
                        $object = New-Object System.Object
                        $object | Add-Member -MemberType NoteProperty -Name SQLServer -value $dbServer
                        $object | Add-Member -MemberType NoteProperty -Name Database -value $dbName
                        $object | Add-Member -MemberType NoteProperty -Name IndexPath -value $row.IndexPath
                        $object | Add-Member -MemberType NoteProperty -Name IndexFlags -value $row.IndexFlags
                        $object | Add-Member -MemberType NoteProperty -Name IndexSize_MB -value $row.IndexSize_MB
                        $object | Add-Member -MemberType NoteProperty -Name TotalIndexedDocs -value $row.TotalIndexedDocs
                        $cMissingIndexes += $object
                    }
                }
            }
            
            # Query Indexes from the current Archive Database with *POSSIBLE* Message Miscount Issue
            # Define SQL Query
            $sqlQuery = @'
--
-- Query provided by Barrett Aultman on Feb 26, 2013
--
-- Minor Changes by Micheal Tramont on Feb 27, 2013
--
-- Please Note:
--
-- !!! "Open" or Recent Indexes may show up in this report. !!!
-- !!! Check the age of the index before initiating Index Refresh or Rebuilt Operations !!!
--
create table #tt (VolumeName nvarchar(256), IndexPath nvarchar(2048),IndexNumber int,MessageTotal int,ArchiveTotal int,IndexTotal int)

insert into #tt (VolumeName, IndexPath, IndexNumber, MessageTotal, ArchiveTotal, IndexTotal)
select v.volumename, fp.path, v.indexnum, COUNT(fm.messageid) as MessageTotal, v.msgcount as ArchiveTotal, fti.TotalDocs as IndexTotal
from Volume v (NOLOCK)
join folderplan fp (NOLOCK) on fp.folderid = v.foldernodeid
join FTIndex fti (NOLOCK) on (fti.indexnum = v.indexnum and fti.FolderNodeId = fp.FolderId)
join FolderMessage fm (NOLOCK) on fm.volumeid = v.volumeid
group by v.volumename, fp.path, v.indexnum, fti.TotalDocs, v.msgcount
--order by fp.path, v.indexnum

SELECT REPLACE(IndexPath,'\FPROOT\','') + REPLACE(STR(IndexNumber, 3), SPACE(1), '0') AS IndexPath, SUM(MessageTotal) as MessageCount, SUM(ArchiveTotal) as VolumeCount, IndexTotal,
'Volume Count MisMatch' = CASE WHEN SUM(MessageTotal) != SUM(ArchiveTotal) THEN 'YES' ELSE 'NO' END,
'Reindex Required' = CASE WHEN SUM(MessageTotal) != IndexTotal THEN 'YES' ELSE 'NO' END
INTO #tt2
FROM #tt
GROUP by IndexPath, IndexNumber, IndexTotal

SELECT *
FROM #tt2
WHERE [Volume Count MisMatch] = 'YES' OR [Reindex Required] = 'YES'
ORDER by IndexPath

DROP Table #tt
DROP Table #tt2

'@

            $dtResults = Invoke-ES1SQLQuery $dbServer $dbName $sqlQuery
            
            if ($dtResults -ne $null)
            {
                # Process Indexes From SQL
                foreach ($row in $dtResults)
                {
                    if ($hIndexes.ContainsKey($row.IndexPath))
                    {
                        $file = dir $hIndexes[$row.IndexPath]
                        $diff = New-TimeSpan $($file.LastWriteTime) $scriptStart
                        $age_in_hours = $diff.TotalHours
                        if ($age_in_hours -gt $index_age_filter)
                        {
                            #Add-Log ("Index with Message Count Mismatch:  " + $row.IndexPath)

                            $object = New-Object System.Object
                            $object | Add-Member -MemberType NoteProperty -Name SQLServer -value $dbServer
                            $object | Add-Member -MemberType NoteProperty -Name Database -value $dbName
                            $object | Add-Member -MemberType NoteProperty -Name IndexPath -value $row.IndexPath
                            $object | Add-Member -MemberType NoteProperty -Name MessageCount -value $row.MessageCount
                            $object | Add-Member -MemberType NoteProperty -Name VolumeCount -value $row.VolumeCount
                            $object | Add-Member -MemberType NoteProperty -Name IndexTotal -value $row.IndexTotal
                            $object | Add-Member -MemberType NoteProperty -Name 'Volume Count MisMatch' -value $row.'Volume Count MisMatch'
                            $object | Add-Member -MemberType NoteProperty -Name 'Reindex Required' -value $row.'Reindex Required'                           
                            $object | Add-Member -MemberType NoteProperty -Name 'Index Age (Hours)' -value $("{0:N1}" -f $age_in_hours)                         
                            
                            $cCountMismatchIndexes += $object  
                        }
                    }
                }
            }            
     
    }

	}    
	Catch
	{
        throw $_

	}
    
    Add-Log ("Count of Indexes with Message Count MisMatch:  " + $cCountMismatchIndexes.Count)
    Add-Log ("Count of Missing Indexes:  " + $cMissingIndexes.Count) 

	# List of Indexes with Issues
	$cErrorStateIndexes

	# List of Indexes with Message Count MisMatch (Age Filter
	$cCountMismatchIndexes
	
	# List of Missing Indexes
	$cMissingIndexes


}

END {}
}




<#
.SYNOPSIS
    Get info from the Index Share passed in  
	WORK IN PROGRESS
.DESCRIPTION
	Get info from the Index Share passed in.
	Derived from Kenta's S1 dashboard scripts
	WORK IN PROGRESS
.OUTPUTS

.EXAMPLE

#>

#####################################################################
#  Function Get-S1IndexShareStats:
#
#			Returns info such as: 
#	        	Success =  $success  (0 = failed , 1 = success)
#   	        Path = $path 
#				Files = $dirlist
#				FilesCount = $FilesCount  (# of files in folder)
#				OldFilesCount = $OldFilesCount (# of files older than 24 hours)
#       
#####################################################################
function Get-ES1IndexShareStats{ 
    [cmdletbinding()] 
    param( 
		[Parameter(Position=0)]
        [string]$path
    ) 
    process{ 
		$OldFilesCount	= 0 
		$FilesCount = 0
		$dirlist = @()
		$agelimit = (Get-Date).AddDays(-1) #
		#Exclude the DropDir.lock file and subdirectories
		
		if (Test-Path $path) 
		{
			$success = 1
			$directorylist= @(get-Childitem $path -exclude 'dropdir.lock'  -ErrorAction Stop|where { ! $_.PSIsContainer})

				foreach ($l in $directorylist) {
					$currentfile = $l
					$filelist = get-Childitem $currentfile|Select-Object CreationTime,FullName
					$CreateDate = $filelist.CreationTime
					if ($l -like "dropdir.lock") {
						#skip
						}
					else {
						if ($filelist.CreationTime -lt $agelimit) {
							$Old = 1
							$OldFilesCount++
							$FilesCount++
							}
						else {
							$Old = 0 
							$FilesCount++
						}
						$dirlist += "$currentfile,$CreateDate,$Old"
					} #end skip
				}
		} #end if test path
		else {
			$success = 0
		}
         
        New-Object PSObject -Property [ordred]@{ 
            Success =  $success 
            Path = $path 
			Files = $dirlist
			FilesCount = $FilesCount
			OldFilesCount = $OldFilesCount
        } 
    } 
}
#### End get-indexsharestats Function



Export-ModuleMember -Function * -Alias *


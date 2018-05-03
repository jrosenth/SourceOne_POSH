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
		related to archive Volumes.
		Functions adapted from Mike Tramonts S1emVolMon.ps1 Health Check scripts

#>

#requires -Version 4

<#
.SYNOPSIS
  
	Adapted from Mike Tramont's S1emVolMon.ps1 health check script
.DESCRIPTION
   TBD
.OUTPUTS

.EXAMPLE

#>
Function Get-ArchiveVolumeStatus
{
	[CmdletBinding()]
	PARAM ()
BEGIN {
		$scriptStart = Get-Date
		$scriptDirectory  = Split-Path -parent $PSCommandPath
}

PROCESS {

	# TODO - Each one of the Foreach Server block can be parrallized 
Try
{
    $returnCode = 0
      
    #
    # Query "Open" Volumes with CCLIPS
    #
    $hOpenWithCclip = @{}
    $aOpenWithCclip = @()
	$Archives = Get-ES1ArchiveDatabases

    foreach ($archive in $Archives)
    {
       
            $dbName = $archive.DBName
            $dbServer = $archive.DBServer
     
            Add-Log "DATABASE $dbName on $dbServer`:  Querying Open Volumes with CClips"
            
            #
            # Define SQL Query
            #
			# TODO - Add support for Atmos OIDs, the XML is different
			#
            $sqlQuery = @'
SELECT VolStubXml.value('(/Cf/Gp/CCLIPID)[1]','nvarchar(max)') AS CCLIPID, VolumeName, VolumeFlags, MsgCount, CurrentUNCPath
FROM Volume (NOLOCK)
WHERE CurrentUNCPath NOT LIKE '%.emx' AND VolStubXml.value('(/Cf/Gp/CCLIPID)[1]','nvarchar(max)') <> 'NULL'
ORDER BY VolumeName 
'@
    
            $dtResults = Invoke-ES1SQLQuery $dbServer $dbName $sqlQuery
            
            if ($dtResults -ne $null)
            {
                foreach ($vol in $dtResults)
                {          
                    $year = $vol.VolumeName.SubString(0,4)
                    $month = $vol.VolumeName.SubString(4,2)
                    $day = $vol.VolumeName.SubString(6,2)
                    $hour = $vol.VolumeName.SubString(8,2)    
                    $minute = $vol.VolumeName.SubString(10,2) 
                    $second = $vol.VolumeName.SubString(12,2)  
                    $volCreateDateTime = Get-Date -Year $year -Month $month -Day $day -Hour $hour -Minute $minute -Second $second             
                    $volAgeDays = ($scriptStart).subtract($volCreateDateTime).TotalDays
                    
                    if ($volAgeDays -gt 1)
                    {
                        $aOpenWithCclip += $vol
                        $hOpenWithCclip[$vol.VolumeName] = $True
                    }               
                }            
            }                            
       
    }
    Add-Log ("Open Volumes With Centera CCLIPS:  " + $hOpenWithCclip.Count)    
    
    #
    # Get Volumes in Error State
    #
    $volumeResults = @()
  
    foreach ($archive in $Archives)
    {
       
            $dbName = $archive.DBName
            $dbServer = $archive.DBServer
     
            Add-Log "DATABASE $dbName on $dbServer`:  Querying Volumes with Errors"
            
            #
            # Define SQL Query
            #
            $sqlQuery = @'
SELECT REPLACE(Path, '\FPROOT\', '') AS FolderMonth, VolumeName, VolumeSize/1024 AS VolumeSize_MB, MsgCount, VolumeFlags, VolumeStartDate, VolumeEndDate
FROM Volume v (NOLOCK)
JOIN FolderPlan fp (NOLOCK) ON v.FolderNodeId = fp.FolderId
WHERE (VolumeFlags & 8) = 8
ORDER BY FolderMonth, VolumeName     
'@
    
            $dtResults =Invoke-ES1SQLQuery $dbServer $dbName $sqlQuery
            
            if ($dtResults -ne $null)
            {      
                Add-Log ("DATABASE $dbName on $dbServer`:  Volumes Found with Errors:  " + @($dtResults).Count)
                $volumeResults += $dtResults
            }
            else
            {
                Add-Log ("DATABASE $dbName on $dbServer`:  Volumes Found with Errors:  0")            
            }                                  
      
    }
    Add-Log ("Volumes With Issues:  " + $volumeResults.Count)
    
    #
    # Get Volumes in Closed State EXCEPT for Volumes stored directly on Centera
    #
    $aClosedVolumes = @()
  
    foreach ($archive in $Archives)
    {
       
            $dbName = $archive.DBName
            $dbServer = $archive.DBServer
      
            Add-Log "DATABASE $dbName on $dbServer`:  Querying Closed Volumes"
            
            #
            # Define SQL Query
            #
            $sqlQuery = @'
SELECT VolumeName, CurrentUNCPath, VolumeId, VolumeSize, MsgCount
FROM Volume (NOLOCK)
WHERE (VolumeFlags & 4) = 4 AND CurrentUNCPath LIKE '%.emx' AND LEN(CAST(VolStubXml AS VarChar(max))) = 0   
'@
    
            $dtResults = Invoke-ES1SQLQuery $dbServer $dbName $sqlQuery
            
            if ($dtResults -ne $null)
            {      
                Add-Log ("DATABASE $dbName on $dbServer`:  Closed Volumes Found:  " + @($dtResults).Count)
                $aClosedVolumes += $dtResults
            }
            else
            {
                Add-Log ("DATABASE $dbName on $dbServer`:  Closed Volumes Found:  0")            
            }                                  
     
    }
    Add-Log ("Closed Volumes found in SQL:  " + $aClosedVolumes.Count)
    
    #
    # Process Closed Volumes from SQL
    #
    $hVolumePaths = @{}
    $hClosedVolumesSQL = @{}
    foreach ($row in $aClosedVolumes)
    {   
        $aValues = $row.CurrentUNCPath.Split('\')
        if ($aValues.Length -gt 3)
        {
            $folder = $aValues[$aValues.Length - 3]
            $calmonth = $aValues[$aValues.Length - 2]
            $container = $aValues[$aValues.Length - 1]
            
            $volkey = "$folder\$calmonth\$container"
            $hClosedVolumesSQL[$volkey] = $row.CurrentUNCPath
            
            #$archive_path = $row.CurrentUNCPath.Replace($volkey,"")
            $archive_path = "\\$($aValues[2])\$($aValues[3])\"    
            $hVolumePaths[$archive_path] = $true   
        }
    }
    
    #
    # Delete temp EMX output file if it exists
    #
    $tempEmxFile = $scriptDirectory + "\tempemxlist.txt"
    if (Test-Path $tempEmxFile)
    {
        Remove-Item $tempEmxFile
    }

    #
    # Scan volume paths
    #
    foreach ($path in $hVolumePaths.Keys)
    {
        Add-Log ("Scanning Path:  " + $path)
         
        if (Test-Path $path)
        {
			#
			# TODO - Change this to use something else !! Jay R.
			#
            # Not using Get-ChildItem -Recurse because it's too slow, especially over CIFS Shares.
            # Using old fashioned cmd shell "dir" which is much faster for what we need.
            cmd /c dir "`"${path}*.emx`"" /s /b >> $tempEmxFile
        }
        else
        {
            Add-Log ("Path Does not exist:  " + $path)    
        }
    }
    
    #
    # Process Closed Volumes from File System(s)
    #
    $hClosedVolumesFS = @{}    
    if (Test-Path $tempEmxFile)
    {            
        $reader = [System.IO.File]::OpenText($tempEmxFile)
        try
        {
            while ($reader.Peek() -ne -1)
            {
                $line = $reader.ReadLine()
                if ($line -eq $null) { break }

                $aValues = $line.Split('\')
                if ($aValues.Length -ge 3)
                {
                    $folder = $aValues[$aValues.Length - 3]
                    $calmonth = $aValues[$aValues.Length - 2]
                    $container = $aValues[$aValues.Length - 1]
                
                    $volkey = "$folder\$calmonth\$container"
                    $hClosedVolumesFS[$volkey] = $path 
                }
            }
        }
        finally
        {
            $reader.Close()
        }
    }      
    Add-Log ("Closed Volumes found in File System(s):  " + $hClosedVolumesFS.Count)

    #
    # Find Missing Closed Volumes
    #
    $aMissingClosedVolumes = @()
    foreach ($vol in $hClosedVolumesSQL.Keys)
    {
        if (! $hClosedVolumesFS.ContainsKey($vol))
        {
            $aMissingClosedVolumes += $hClosedVolumesSQL[$vol]
        }
    }
    Add-Log ("Count of Missing Closed Volumes:  " + $aMissingClosedVolumes.Count)

    #
    # Find Extra Closed Volumes
    #
    $aExtraClosedVolumes = @()
    foreach ($vol in $hClosedVolumesFS.Keys)
    {
        if (! $hClosedVolumesSQL.ContainsKey($vol))
        {
            $aValues = $vol.Split('\')
            $volname = $aValues[$aValues.Length - 1]
            $year = $volname.SubString(0,4)
            $month = $volname.SubString(4,2)
            $day = $volname.SubString(6,2)
            $hour = $volname.SubString(8,2)    
            $minute = $volname.SubString(10,2) 
            $second = $volname.SubString(12,2)
            $volCreateDateTime = Get-Date -Year $year -Month $month -Day $day -Hour $hour -Minute $minute -Second $second        
            $volAgeDays = ($scriptStart).subtract($volCreateDateTime).TotalDays

            if ($volAgeDays -gt 1)
            {
                $aExtraClosedVolumes += $hClosedVolumesFS[$vol] + $vol
            }
        }
    }
    Add-Log ("Count of Extra Closed Volumes:  " + $aExtraClosedVolumes.Count)

    #
    # Get Volumes Incorrectly Marked as Closed
    #
    $aIncorrectClosedVolumes = @()
  
    foreach ($archive in $Archives)
    {
       
            $dbName = $archive.DBName
            $dbServer = $archive.DBServer
      
            Add-Log "DATABASE $dbName on $dbServer`:  Querying Incorrectly Closed Volumes"
            
            #
            # Define SQL Query
            #
            $sqlQuery = @'
SELECT VolumeName, CurrentUNCPath, VolumeId, VolumeSize, MsgCount
FROM Volume (Nolock)
WHERE (VolumeFlags & 4) = 4 And CurrentUNCPath NOT LIKE '%.emx'
'@
    
            $dtResults = Invoke-ES1SQLQuery $dbServer $dbName $sqlQuery
            
            if ($dtResults -ne $null)
            {
                foreach ($vol in $dtResults)
                {          
                    $year = $vol.VolumeName.SubString(0,4)
                    $month = $vol.VolumeName.SubString(4,2)
                    $day = $vol.VolumeName.SubString(6,2)
                    $hour = $vol.VolumeName.SubString(8,2)    
                    $minute = $vol.VolumeName.SubString(10,2) 
                    $second = $vol.VolumeName.SubString(12,2)  
                    $volCreateDateTime = Get-Date -Year $year -Month $month -Day $day -Hour $hour -Minute $minute -Second $second             
                    $volAgeDays = ($scriptStart).subtract($volCreateDateTime).TotalDays
                    
                    if ($volAgeDays -gt 1)
                    {
                        $aIncorrectClosedVolumes += $vol
                    }               
                }
            }                                 
      
    }
    Add-Log ("Incorrectly Closed Volumes found in SQL:  " + $aIncorrectClosedVolumes.Count)

    #
    # Query Open Volumes
    #
    $aOpenVolumes = @()
  
    foreach ($archive in $Archives)
    {
       
            $dbName = $archive.DBName
            $dbServer = $archive.DBServer
     
            Add-Log "DATABASE $dbName on $dbServer`:  Querying Open Volumes"
            
            #
            # Define SQL Query
            #
			# TODO - Doesn't take into account "RecordPending" or "ActiveRecording"
			#        might be OK, might cause a little confusion
			#
            $sqlQuery = @'
SELECT VolumeName, CurrentUNCPath, VolumeId, VolumeSize, MsgCount
FROM Volume (Nolock)
WHERE (VolumeFlags & 4) <> 4 And CurrentUNCPath NOT LIKE '%.emx'
'@
    
            $dtResults = Invoke-ES1SQLQuery $dbServer $dbName $sqlQuery
            
            if ($dtResults -ne $null)
            {      
                Add-Log ("DATABASE $dbName on $dbServer`:  Open Volumes Found:  " + @($dtResults).Count)
                $aOpenVolumes += $dtResults
            }
            else
            {
                Add-Log ("DATABASE $dbName on $dbServer`:  Open Volumes Found:  0")            
            }                                  
     
    }
    Add-Log ("Open Volumes found in SQL:  " + $aOpenVolumes.Count)
    
    #
    # Check Open Volumes for Missing Message Center Folders and for Open Volumes older than 7 Days
    #
    $aMissingOpenVolumes = @()
    $aOldOpenVolumes = @()
    foreach ($vol in $aOpenVolumes)
    {   
        $year = $vol.VolumeName.SubString(0,4)
        $month = $vol.VolumeName.SubString(4,2)
        $day = $vol.VolumeName.SubString(6,2)
        $hour = $vol.VolumeName.SubString(8,2)    
        $minute = $vol.VolumeName.SubString(10,2) 
        $second = $vol.VolumeName.SubString(12,2)
        
        $volCreateDateTime = Get-Date -Year $year -Month $month -Day $day -Hour $hour -Minute $minute -Second $second
        
        $volAgeDays = ($scriptStart).subtract($volCreateDateTime).TotalDays    
        
        if (! (Test-Path $vol.CurrentUNCPath))
        {
            if (! $hOpenWithCclip.ContainsKey($vol.VolumeName))
            {
                $aMissingOpenVolumes += $vol.CurrentUNCPath
            }
        } elseif ($volAgeDays -gt 7)
        {
            $aOldOpenVolumes += $vol.CurrentUNCPath
        }
    }
    Add-Log ("Missing Open Volumes found:  " + $aMissingOpenVolumes.Count)
    Add-Log ("Old Open Volumes found:  " + $aOldOpenVolumes.Count)
    
    #
    # Check for Volumes without an assigned Index (IndexNum = 0) older than 1 Day
    #
    $aVolumesNoIndex = @()
    
    foreach ($archive in $Archives)
    {
       
            $dbName = $archive.DBName
            $dbServer = $archive.DBServer
     
            Add-Log "DATABASE $dbName on $dbServer`:  Querying Volumes without assigned Index"
            
            #
            # Define SQL Query
            #
            $sqlQuery = @'
SELECT VolumeName, CurrentUNCPath, VolumeId, VolumeSize, MsgCount
FROM Volume (nolock)
WHERE IndexNum = 0
ORDER BY CurrentUNCPath
'@
    
            $dtResults = Invoke-ES1SQLQuery $dbServer $dbName $sqlQuery
            
            if ($dtResults -ne $null)
            {
                foreach ($vol in $dtResults)
                {          
                    $year = $vol.VolumeName.SubString(0,4)
                    $month = $vol.VolumeName.SubString(4,2)
                    $day = $vol.VolumeName.SubString(6,2)
                    $hour = $vol.VolumeName.SubString(8,2)    
                    $minute = $vol.VolumeName.SubString(10,2) 
                    $second = $vol.VolumeName.SubString(12,2)  
                    $volCreateDateTime = Get-Date -Year $year -Month $month -Day $day -Hour $hour -Minute $minute -Second $second             
                    $volAgeDays = ($scriptStart).subtract($volCreateDateTime).TotalDays
                    
                    if ($volAgeDays -gt 1)
                    {
                        $aVolumesNoIndex += $vol.CurrentUNCPath
                    }               
                }
            }                                          
     
    }
    Add-Log ("Volumes without Index Found:  " + $aVolumesNoIndex.Count)     
	}       
	Catch
	{
		throw $_
	}

	
	# List of Volumes with Issues
	Write-Output "vresults"
	$volumeResults | Select-Object FolderMonth, VolumeName, VolumeSize_MB, MsgCount, VolumeFlags, VolumeStartDate, VolumeEndDate
	Write-Output "1"
	#List of Missing Closed Volumes
	$aMissingClosedVolumes
	Write-Output "2"
	# List of Volumes Incorrectly marked as Closed
	$aIncorrectClosedVolumes
	Write-Output "3"
	#List of Missing Open Volumes
	$aMissingOpenVolumes
	Write-Output "4"
	#List of Missing Open Volumes with Centera CCLIPS
	$hOpenWithCclip
	Write-Output "5"
	#List of Open Volumes Older than 7 Days
	$aOldOpenVolumes
	Write-Output "6"
	# List of `"Extra`" Closed Volume Files not found in SQL Volume Table
	$aExtraClosedVolumes
	Write-Output "7"
	#List of Volumes without an assigned Index
	$aVolumesNoIndex
}
END {}
}

Export-ModuleMember -Function * -Alias *
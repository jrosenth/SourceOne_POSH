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
		Functions and objects for managing Indexes in a folder


#>


<#
.SYNOPSIS
   Issue a "Rebuild" request for the Indexes specified
.DESCRIPTION
  Issue a "Rebuild" request for the Indexes specified
  The process of rebuilding an index is handled by index servers on a scheduled basis.  The completion of the rebuild
  operation could take some time.

.PARAMETER ArchiveName
	The name of the archive connection 

.PARAMETER ArchiveFolder
	The archive folder containig the indexes.

.PARAMETER YearMonth
	The year and month folder which the indexes are part of

.PARAMETER IndexNumList
	A integer array of the index numbers to be rebuilt.

.OUTPUTS
	List of Indexes submitted for rebuild

.EXAMPLE

#>
function Rebuild-ES1Index{
[CmdletBinding(SupportsShouldProcess=$true,
			   ConfirmImpact=’High’)]
 	PARAM (
	 [Parameter(Mandatory=$true)]
		[Alias('archive')]
		[string] $ArchiveName,		
		[Parameter(Mandatory=$true)]
		[Alias('arfolder')]
		[string] $ArchiveFolder,
		[Parameter(Mandatory=$true)]
		[Alias('month')]
		[string] $YearMonth,
		[Parameter(Mandatory=$true)]
		[Alias('idxnums')]
		[int []] $IndexNumList

		)

BEGIN
	{
 	
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
		$asmgr = new-object -ComObject ExAsAdminAPI.CoExASAdminAPI
		$asmgr.SetTraceInfo($Global:S1LogFile)
		$asmgr.Initialize()
		$RetIndexList=@()

		# Get the index flag enumeration strings/names
		$idxFlags=[enum]::GetNames([EMC.Interop.ExAsBaseAPI.exASIndexFlags])

		# Get the specific repo.  
		$repo = $asmgr.GetRepository($ArchiveName)
		$repo.SetTraceInfo($Global:S1LogFile)

		# Need the folderplan object to issue the "Rebuild" on
		$folderplan=$repo.GetFolderPlan()

		# Get the archive folder we need
		$folder = Get-Es1ArchiveFolder -ArchiveName $ArchiveName -FolderName $ArchiveFolder 
		
		if ($folder -ne $null)
		{
			$folder.SetTraceInfo($Global:S1LogFile)
			$containerfolders=$folder.EnumerateContainerFolders()
        
			# dummy filter object because need to pass something to EnumerateIndexes but its not actually used  (I looked at the underlying code)
			$idxFilter = $repo.CreateNewObject([EMC.Interop.ExAsAdminAPI.exASObjectType]::exASObjectType_ArchiveFolder)
			[bool] $FoundYM = $false
			foreach ($cf in $containerfolders)
			{
				if ($cf.Name -eq $YearMonth)
				{
					$FoundYM = $true
					$cf.SetTraceInfo($Global:S1LogFile)
					Write-Verbose "Year Month name: $($cf.Name)"

					$indexes=$cf.EnumerateIndexes($idxFilter)
                         
					foreach ($index in $indexes)
					{                   
						Foreach($inum in $IndexNumList)
						{
								if ([int] $inum -eq [int] $index.IndexNum)
								{                   
										 # Make sure its not alreading ReIndexing or Refreshing
										if ( (-not ($index.IndexState -band [EMC.Interop.ExAsBaseAPI.exASIndexFlags]::exASIndexFlagRefreshing)) -and `
											 (-not ($index.IndexState -band [EMC.Interop.ExAsBaseAPI.exASIndexFlags]::exASIndexFlagReindexing)) )
										{
											if ($pscmdlet.ShouldProcess("Folder: $($cf.Name) Index: $($index.IndexNum) ?")) 
											{
												# issue rebuild
												Write-Verbose "Issueing rebuild for $($cf.Name), $($index.IndexNum)"
                                    
												$folderplan.ReIndex($index.FolderID, $index.IndexNum)
												$RetIndexList += $index
											}
										}
								}
						}
                
					}

					# stop cause we processed what was specified.
					break
				}
			} 
			if ( -not $FoundYM )
			{
				throw "Error: No matching Year or month folder found for $($YearMonth)"
			}  
		}
		else
		{
			throw "Error: Archive $($ArchiveName) or Folder $($ArchiveFolder) not found"
		}
	}
	catch {
		Write-Error $_
	}
	finally
	{
		# These might not be 100% necessary.. 
		[System.Runtime.Interopservices.Marshal]::ReleaseComObject($folderplan) > $null
		[System.Runtime.Interopservices.Marshal]::ReleaseComObject($repo) > $null
	}
	
	$RetIndexList
 }
 END {}
}

<#
.SYNOPSIS
   Get a list of indexes in the state(s) requested
.DESCRIPTION
  Get a list of indexes in the state(s) requested

.PARAMETER ArchiveName
	The name of the archive connection 

.PARAMETER ArchiveFolder
	The archive folder containig the indexes.

.PARAMETER YearMonth
	The year and month folder which the indexes are part of.  Can only be used in conjuction with the ArchiveFolder
	parameter

.PARAMETER States
	List of states.  The States correlate to some common combinations of the [EMC.Interop.ExAsBaseAPI.exASIndexFlags]
	enum of the volume flag bits.

	REPAIRING        will return Indexes with ReIndexing or Refreshing bits sets
	CORRUPT          will return Indexes with the Corrupt bit set
	INCOMPLETE       will return Indexes with the any of the InconsistentAncillaryDB,MissingMsgs, Missing, 
	                 MissingACE, MissingBCC, MissingOwner, or MissingRecpts bit set 
	UNPERFORMEDTRANS will return Indexes with the UnperformedTrans bit set


.OUTPUTS
	List of Indexes in the requested state(s)

.EXAMPLE

#>
Function Get-ES1IndexByState {
[CmdletBinding()]
PARAM( [Parameter(Mandatory=$true)]
		[Alias('archive')]
		[string] $ArchiveName,		
		[Parameter(Mandatory=$false)]
		[Alias('name')]
		[string] $ArchiveFolder,
		[Parameter(Mandatory=$false)]
		[Alias('month')]
		[string] $YearMonth,
		[Parameter(Mandatory=$true)]                      
		[ValidateSet ("REPAIRING","CORRUPT","INCOMPLETE","UNPERFORMEDTRANS")]
		[string[]] $States
		)


BEGIN{
		
		$MyDebug = $false

		# The YearMonth parameter only make sense when an ArchiveFolder is specified.  Otherwise you might get some meaningless results
		if ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey("YearMonth") -and(-not $PSCmdlet.MyInvocation.BoundParameters.ContainsKey("ArchiveFolder")))
		{
			Write-Error "Argument Error: YearMonth can only be specified with an ArchiveFolder"
			break
		}

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
PROCESS{

try {
		$asmgr = new-object -ComObject ExAsAdminAPI.CoExASAdminAPI
		$asmgr.SetTraceInfo($Global:S1LogFile)
		$asmgr.Initialize()
		$RetIndexList=@()

		# Get the index flag enumeration strings/names
		$idxFlags=[enum]::GetNames([EMC.Interop.ExAsBaseAPI.exASIndexFlags])

		# Get the specific repo.  
		$repo = $asmgr.GetRepository($ArchiveName)
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

		# dummy object because need to pass something but its not actually used
		$idxFilter = $repo.CreateNewObject([EMC.Interop.ExAsAdminAPI.exASObjectType]::exASObjectType_ArchiveFolder)

		foreach ($folder in $folders)
		{
			$containerfolders=$folder.EnumerateContainerFolders()
			
			foreach ($cf in $containerfolders)
			{
				#
				# Process only the YMFolder if specified.
				#
				if ($YearMonth -and ($YearMonth -ne $cf.Name) )
				{
					continue
				}
				
				$cf.SetTraceInfo($Global:S1LogFile)

				$indexes=$cf.EnumerateIndexes($idxFilter)
				Write-Verbose "Archive Folder: $($ArchiveFolder) YearMonth : $($cf.Name) Index Count $($indexes.Count)"
	                         
				foreach ($index in $indexes)
				{  
					$roles = @()
               		for ($i = 0 ; $i -lt ($idxFlags.Length); $i++)
					{
						[int] $bits = [EMC.Interop.ExAsBaseAPI.exASIndexFlags]$idxFlags[$i]
						
						# there are some inconsistent names in the EMC.Interop.ExAsBaseAPI.exASIndexFlags so making the string
						# readable friendly takes a little extra work
						if ($index.IndexState -band $bits)
						{
							if (([EMC.Interop.ExAsBaseAPI.exASIndexFlags]$idxFlags[$i]).ToString().Contains('exASIndexMissing') -or `
							([EMC.Interop.ExAsBaseAPI.exASIndexFlags]$idxFlags[$i]).ToString().Contains('exASIndex4xMBCSIndex') -or ` 
							([EMC.Interop.ExAsBaseAPI.exASIndexFlags]$idxFlags[$i]).ToString().Contains('exASIndexESIndex') 
							)
							{
								$roles += ([EMC.Interop.ExAsBaseAPI.exASIndexFlags]$idxFlags[$i]).ToString().Substring(9)
							}
							elseif (([EMC.Interop.ExAsBaseAPI.exASIndexFlags]$idxFlags[$i]).ToString().Contains('exAsInconsistent'))
							{
								$roles += ([EMC.Interop.ExAsBaseAPI.exASIndexFlags]$idxFlags[$i]).ToString().Substring(4)
							}
							else
							{
								$roles += ([EMC.Interop.ExAsBaseAPI.exASIndexFlags]$idxFlags[$i]).ToString().Substring(13)
							}
						}

					}

					# add a user readable string representation of the flags
					$index | Add-Member NoteProperty -Name "ArchiveFolder" -Value $folder.Name
					$index | Add-Member NoteProperty -Name "FolderName" -Value $cf.Name
					$index | Add-Member NoteProperty -Name "IndexStatus" -Value $roles
				

					foreach ($state in $States)
					{
						if ( ($state -eq 'REPAIRING') -and `
							(($index.IndexState -band [EMC.Interop.ExAsBaseAPI.exASIndexFlags]::exASIndexFlagRefreshing) -or `
							 ($index.IndexState -band [EMC.Interop.ExAsBaseAPI.exASIndexFlags]::exASIndexFlagReindexing) ))
						{
							$RetIndexList += $index
							break
						}

						if ( ($state -eq 'CORRUPT') -and `
							(($index.IndexState -band [EMC.Interop.ExAsBaseAPI.exASIndexFlags]::exASIndexFlagCorrupt) ))
						{
							$RetIndexList += $index
							break
						}
						if ( ($state -eq 'UNPERFORMEDTRANS') -and `
							(($index.IndexState -band [EMC.Interop.ExAsBaseAPI.exASIndexFlags]::exASIndexFlagUnperformedTrans) ))
						{
							$RetIndexList += $index
							break
						}
						if ( ($state -eq 'INCOMPLETE') -and `
							(($index.IndexState -band [EMC.Interop.ExAsBaseAPI.exASIndexFlags]::exAsInconsistentAncillaryDB) -or `
							 ($index.IndexState -band [EMC.Interop.ExAsBaseAPI.exASIndexFlags]::exASIndexMissingMsgs) -or `
							 ($index.IndexState -band [EMC.Interop.ExAsBaseAPI.exASIndexFlags]::exASIndexMissing)  -or `
							 ($index.IndexState -band [EMC.Interop.ExAsBaseAPI.exASIndexFlags]::exASIndexMissingBusinessFolder)  -or `
							 ($index.IndexState -band [EMC.Interop.ExAsBaseAPI.exASIndexFlags]::exASIndexMissingACE)  -or `
							 ($index.IndexState -band [EMC.Interop.ExAsBaseAPI.exASIndexFlags]::exASIndexMissingBCC)  -or `
							 ($index.IndexState -band [EMC.Interop.ExAsBaseAPI.exASIndexFlags]::exASIndexMissingOwner)  -or `
							 ($index.IndexState -band [EMC.Interop.ExAsBaseAPI.exASIndexFlags]::exASIndexMissingRecpts)  )
							 )
						{
							$RetIndexList += $index
							break
						}

					}

				}
			}

		}
	}
	catch {
		Write-Error $_
	}
	finally
	{
		# These might not be 100% necessary.. 
		[System.Runtime.Interopservices.Marshal]::ReleaseComObject($folderplan) > $null
		[System.Runtime.Interopservices.Marshal]::ReleaseComObject($repo) > $null
	}
	
	$RetIndexList

}

END{}

}



Export-ModuleMember -Function * -Alias *

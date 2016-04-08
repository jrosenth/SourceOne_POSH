<#	
	.NOTES
    ============================================================================
	 Created on:   	October 14, 2015
	 Created by:   	Jay Rosenthal
	 Organization: 	EMC Corp. PS Americas
	 Filename:     	

     Copyright © 2015 EMC Corporation, Professional Services, All rights reserved.
	===========================================================================

.SYNOPSIS
	

.DESCRIPTION
    
.OUTPUTS

.LINK

.EXAMPLE


#>

<#
	.SYNOPSIS
		Create a file of SQL commands to Update the clipID for a volume
	.DESCRIPTION
		Create a file of SQL commands to Update the clipID for a volume

	.PARAMETER  archDBServer

	.PARAMETER archDBname

	.PARAMETER  
		
	.PARAMETER  OutputFile
		Fully qualified path to output file.

	.EXAMPLE
		TBD

	.INPUTS
		System.String,System.Int32
		System.String,System.Int32
		TBD
		System.String,System.Int32

	.OUTPUTS
		TBD

	.NOTES
		Specially written for assisting CIBC restoration of deleted data
			
#>
function Create-VolumeUpdateVolStubXMLSQL
{
	[CmdletBinding()]
	param (
		[Parameter(Position = 0, Mandatory = $true)]
		[System.String]
		$archDBServer,
		[Parameter(Position = 1, Mandatory = $true)]
		[System.String]
		$archDBName,
		[Parameter(Position = 2, Mandatory = $true)]
		$VolumesToUpdate,
		[Parameter(Position = 3, Mandatory = $true)]
		[System.String]
		$OutputFile,
		[Parameter(Position = 4, Mandatory = $false)]
		[System.String]
		$AdditionalComments
		
	)
	begin
	{
		
	}
	process
	{
		$sbFile = new-object System.Text.StringBuilder
		[void]$sbFile.AppendLine("--")
		[void]$sbFile.AppendLine("-- Volume Update VolStubXML with new ClipID commands generated on $(Date)")
		[void]$sbFile.AppendLine("-- $AdditionalComments")
		[void]$sbFile.AppendLine("--")


#update [Volume]
#SET VolStubXml.modify('replace value of (/Cf/Gp/CCLIPID[1]/text())[1] with "2222222222222222222222222"')
#where VolumeName='esqlext4-j\20060829140724'

		$SQLPrefix = "USE [@databasename]"
		
		$SQLVolumeUpdate = @'
  Update [{0}].[dbo].[Volume]
  SET VolStubXml.modify('replace value of (/Cf/Gp/CCLIPID[1]/text())[1] with "{1}"')
  where VolumeName='{2}'
'@
        $theseVolumes=@()
		try
		{

            $theseVolumes= @($VolumesToUpdate | where {($_.ArchiveDB -eq $archDBName)})

            if ($theseVolumes.Length -gt 0)
            {

			    $outString = $SQLPrefix.replace("@databasename", $archDBName)
			    [void]$sbFile.AppendLine($outString)
			
            
			    foreach ($Volume in $theseVolumes)
			    {
            
				    #$name = "'" + $Volume.VolumeName + "'"
				    $updcmd = $SQLVolumeUpdate -f $archDBName, $Volume.NewClipID, $Volume.VolumeName
                				
				    [void]$sbFile.AppendLine($updcmd)
			    }
				
			    # Output the file
			    Set-Content -Path $OutputFile -Value $sbFile.ToString()
            }
            else
            {
                Write-Warning "No Volumes found for archive database: $archDBName"
            }

		}
		catch
		{
			Write-Error $_
		}
	}
	end
	{
		
	}
}

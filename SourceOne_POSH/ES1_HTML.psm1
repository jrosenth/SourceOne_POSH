<#
	.NOTES
	===========================================================================
 
	Copyright � 2018 Dell Inc. or its subsidiaries. All Rights Reserved.

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
		Functions for creating HTML fragments and content for reports or emails.

===============================================================================
#>

#-------------------------------------------------------------------------------
# Function:  Get-HtmlHead
#-------------------------------------------------------------------------------
function Get-HtmlHead
{
	[CmdletBinding()]
	
	#
    Param
    (
        [Parameter (Mandatory=$false)]
        [string] $Title,
		[Parameter (Mandatory=$false)]
        [string] $cssFile =""
    )
 
BEGIN {
 }   
 PROCESS {
 
	# get script location, load defaults from it...
	$scriptDirectory  = Split-Path -parent $PSCommandPath
	$CSSDefaults = join-path $scriptDirectory 'ES1_DefaultCSS.txt'

	#-------------------------------------------------------------------------------
	# Read in CSS for HTML
	#-------------------------------------------------------------------------------
	if ($cssFile -and (Test-Path $cssFile))
	{
		$css = Get-Content $cssFile
	}
	else
	{
		$css = Get-Content $CSSDefaults
	}

	$headFrag=@"
<html><head>
<meta content=`"text/html; charset=utf-8`" http-equiv=`"Content-Type`"/>
<title>$Title</title>
$css

</head>
 <body >

"@   

$headFrag

}

END {}

}


#-------------------------------------------------------------------------------
# Function:  Get-HtmlTail
#-------------------------------------------------------------------------------
function Get-HtmlTail
{
@" 

    </body></html>
"@
}


#-------------------------------------------------------------------------------
# Function:  Prettify-HtmlTable
#-------------------------------------------------------------------------------
function Prettify-HtmlTable
{
    Param
    (
        [Parameter(
            Position=0, 
            Mandatory=$true, 
            ValueFromPipeline=$true)
        ]
        [String[]]$HtmlData,
        
        [Parameter()]
        [switch] $Zebra,
        
        [Parameter()]
        [switch] $Alerts,

        [Parameter()]
        [string] $ColAlign = 'LEFT'
    )
    
    Begin
    {
        $aNewLines = @()
        $i = 0
        
        if ($ColAlign.Contains(','))
        {
            $aAlign = $ColAlign.Split(',')
        }
        else
        {
            $aAlign = @($ColAlign)
        }
        $colCount = -1
    }

    Process
    {
        if ($_ -match "^<col/>")
        {
            $colCount++
            if ($colCount -le $aAlign.getupperbound(0))
            {
                $aNewLines += $_.Replace('<col/>', '<col align="' + $aAlign[$colCount].ToLower().Trim() +'" />')
            }
            else
            {
                $aNewLines += $_.Replace('<col/>', '<col align="' + $aAlign[$aAlign.getupperbound(0)].ToLower().Trim() +'" />')            
            }       
        }
        elseif (($_ -match "^<tr>") -and $Zebra)
        {
            $i++
            if (($i % 2) -eq 1)
            {
                $aNewLines += $_.Replace('<tr>', '<tr class="even">')
            }
            else
            {
                $aNewLines += $_.Replace('<tr>', '<tr class="odd">')
            } 
        }            
        else
        {
            $aNewLines += $_
        }
    }
    
    End
    {
        if ($Alerts)
        {
            $aNewLines2 = @()
            foreach ($line in $aNewLines)
            {
                if ($line -match "^(<tr.*?>)<td>")
                {
                    $mod = $matches[1]
                    $xmldata = [xml]$line                    
                    foreach ($cell in $xmldata.tr.td)
                    {
                        if (($cell -imatch "Fail") -or ($cell -imatch "Stopped"))
                        {
                            $mod += "<td class=`"fail`">$cell</td>"
                        }
                        elseif (($cell -imatch "Pass")  -or ($cell -imatch "Running"))
                        {
                            $mod += "<td class=`"pass`">$cell</td>"
                        }
                        else
                        {
                            $mod += "<td>$cell</td>"
                        }
                    }
                    $mod += '</tr>'
                    $aNewLines2 += $mod        
                }
                else
                {
                    $aNewLines2 += $line
                }
            
            }
            $aNewLines2
        }
        else
        {
            $aNewLines
        }
    }
}
    
Export-ModuleMember -Function * -Alias *

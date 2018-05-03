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
	===========================================================================

.DESCRIPTION
		This file is a workaround to isolate some "Help" commands from PowerShell
		scoping anomolies.
#>



function Get-ES1Commands{
<#
	.SYNOPSIS
		Nicely formats the list of commands available in the SourceOne_POSH module
	
	.DESCRIPTION
		Nicely formats the list of commands available in the SourceOne_POSH module
	.EXAMPLE
		Get-ES1Commands
	
#>

	[CmdletBinding()]
	param ()
	
	$displayList=@()

	$S1Commands = Get-Command -Module SourceOne_POSH | Sort CommandType,Name
	 for ($i=0; $i -lt $S1Commands.Length; $i++) 
    {
		$props = @{
					'Type' = $S1Commands[$i].CommandType; 'Command' = $S1Commands[$i].Name; "Num" = ($i+1)
				}
		
		$displayList +=New-Object -TypeName PSObject -Property $props
	}

	Format-Table -InputObject $displayList -AutoSize -Property Num, Command, Type | Out-String -Width 10000 
}

Export-ModuleMember -function Get-ES1Commands
<#	
	.NOTES
	===========================================================================
	 Created on:   	
	 Created by:   	jrosenthal
	 Organization: 	EMC Corp.
	 Filename:     	ES1POSH_HelperUtils.ps1
	===========================================================================
	
    THIS CODE AND INFORMATION IS PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND,
    WHETHER EXPRESSED OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE IMPLIED
 	WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A PARTICULAR PURPOSE.
 	IF THIS CODE AND INFORMATION IS MODIFIED, THE ENTIRE RISK OF USE OR RESULTS IN
 	CONNECTION WITH THE USE OF THIS CODE AND INFORMATION REMAINS WITH THE USER. 
	===========================================================================

.DESCRIPTION
		General Helper and convenience functions
#>


function Get-POSHVersionAndArchitecture{
<#
	.SYNOPSIS
		Returns an object containing the Powershell version and architecture
	
	.DESCRIPTION
		Returns an object containing the Powershell version and architecture
	
	.OUTPUTS
	Version        Architecture                                                                           
    -------        ------------                                                                           
       3.0            64-bit                                                                                 

	.EXAMPLE
	Get-POSHVersionAndArchitecture
	Version            Architecture
    -------            ------------
     3.0                 32-bit
	
	 .EXAMPLE
	 $POSHVersion=Get-POSHVersionAndArchitecture
	
	if ($POSHVersion.Architecture -eq '64-bit')
	{
		Write-Error 'This must run in a 32 bit PowerShell !'
	   return
	}

#>

	[CmdletBinding()]
	param ()
	
	#$POSH = "{0}, {1}"
	$POSHVer = Get-Host | Select Version
	
	$Arch = (Get-Process -Id $PID).StartInfo.EnvironmentVariables["PROCESSOR_ARCHITECTURE"];
	if ($Arch -eq 'x86')
	{
		$Arch = '32-bit';
	}
	elseif ($Arch -eq 'amd64')
	{
		$Arch = '64-bit';
		
	}

	$POSHVersion=New-Object System.Object
	$POSHVersion | Add-Member NoteProperty -Name "Version" -Value $POSHVer.Version
	$POSHVersion | Add-Member NoteProperty -Name "Architecture" -Value $Arch

	#$POSHVersion = $POSH -f $POSHVer.Version, $Arch
	
	$POSHVersion
	
}

Function Test-IsAdmin   
{  
<#     
.SYNOPSIS     
   Function used to detect if current user is an Administrator.  
     
.DESCRIPTION   
   Function used to detect if current user is an Administrator. Presents a menu if not an Administrator  
      
.NOTES     
    Name: Test-IsAdmin  
    Author: Boe Prox   
    DateCreated: 30April2011  
	From : https://gallery.technet.microsoft.com/scriptcenter/1b5df952-9e10-470f-ad7c-dc2bdc2ac946  
      
.EXAMPLE     
    Test-IsAdmin  
      
   
Description   
-----------       
Command will check the current user to see if an Administrator. If not, a menu is presented to the user to either  
continue as the current user context or enter alternate credentials to use. If alternate credentials are used, then  
the [System.Management.Automation.PSCredential] object is returned by the function.  
#>  
    [cmdletbinding()]  
    Param()  
      
    Write-Verbose "Checking to see if current user context is Administrator"  
    If (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator"))  
    {  
        Write-Warning "You are not currently running this under an Administrator account! `nThere is potential that this command could fail if not running under an Administrator account."  
        Write-Verbose "Presenting option for user to pick whether to continue as current user or use alternate credentials"  
        #Determine Values for Choice  
        $choice = [System.Management.Automation.Host.ChoiceDescription[]] @("Use &Alternate Credentials","&Continue with current Credentials")  
  
        #Determine Default Selection  
        [int]$default = 0  
  
        #Present choice option to user  
        $userchoice = $host.ui.PromptforChoice("Warning","Please select to use Alternate Credentials or current credentials to run command",$choice,$default)  
  
        Write-Debug "Selection: $userchoice"  
  
        #Determine action to take  
        Switch ($Userchoice)  
        {  
            0  
            {  
                #Prompt for alternate credentials  
                Write-Verbose "Prompting for Alternate Credentials"  
                $Credential = Get-Credential  
                Write-Output $Credential      
            }  
            1  
            {  
                #Continue using current credentials  
                Write-Verbose "Using current credentials"  
                Write-Output "CurrentUser"  
            }  
        }          
          
    }  
    Else   
    {  
        Write-Verbose "Passed Administrator check"  
    }  
}
#====================================================================
#



function Test-PsRemoting
{
<#
	.SYNOPSIS
	Test if Powershell remoting is enbaled on the target machine	
	.DESCRIPTION	
	Test if Powershell remoting is enbaled on the target machine	
	http://www.leeholmes.com/blog/2009/11/20/testing-for-powershell-remoting-test-psremoting/
	
	.OUTPUTS
	
	.EXAMPLE
	
#>

    param(
        [Parameter(Mandatory = $true)]
        $computername
    )
   
    try
    {
        $errorActionPreference = "Stop"
        $result = Invoke-Command -ComputerName $computername { 1 }
    }
    catch
    {
        Write-Verbose $_
        return $false
    }
   
    ## I’ve never seen this happen, but if you want to be
    ## thorough….
    if($result -ne 1)
    {
        Write-Verbose "Remoting to $computerName returned an unexpected result."
        return $false
    }
   
    $true   
} 
#
#   Public Exports
#
New-Alias  Get-POSHVer           Get-POSHVersionAndArchitecture
Export-ModuleMember -function *
Export-ModuleMember -alias Get-POSHVer





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
	$POSHVer = Get-Host | Select-Object Version
	
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

Function Test-IsAdminWithPrompt
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

Function Test-IsAdmin   
{  
<#     
.SYNOPSIS     
   Function used to detect if current user is an Administrator.  
     
.DESCRIPTION   
   Function used to detect if current user is an Administrator.
      
.NOTES     
    Name: Test-IsAdmin  
    Author: Boe Prox   
    DateCreated: 30April2011  
	From : https://gallery.technet.microsoft.com/scriptcenter/1b5df952-9e10-470f-ad7c-dc2bdc2ac946  
      
.EXAMPLE     
    Test-IsAdmin  
      
   
Description   
-----------       
Command will check the current user to see if an Administrator. 
#>  
	[OutputType('System.Boolean')]
    [cmdletbinding()]  
    Param()  
      
    [bool] $result=$false

    Write-Verbose "Checking to see if current user context is Administrator"  
    If (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator"))  
    {  
        Write-Host "You are not currently running this under an Administrator account! `nThere is potential that this command could fail if not running under an Administrator account.`nStart SourceOne PowerShell with `"Run as administrator`"" -ForegroundColor red
        
          
    }  
    Else   
    {  
        Write-Verbose "Passed Administrator check"  
        $result=$true

    }  

    $result
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

<#
.Synopsis
Verify Active Directory credentials

.DESCRIPTION
This function takes a user name and a password as input and will verify if the combination is correct. 
The function returns a boolean based on the result.

.NOTES   
Name: Test-ADCredential
Author: Jaap Brasser
Version: 1.0
DateUpdated: 2013-05-10

.PARAMETER UserName
The samaccountname of the Active Directory user account
	
.PARAMETER Password
The password of the Active Directory user account

.EXAMPLE
Test-ADCredential -username jaapbrasser -password Secret01

Description:
Verifies if the username and password provided are correct, returning either true or false based on the result
#>
function Test-ADCredential {
    [CmdletBinding()]
    Param
    (
        [string]$UserName,
        [System.Security.SecureString]$Password
    )
    if (!($UserName) -or !($Password)) {
        Write-Warning 'Test-ADCredential: Please specify both user name and password'
    } else {

		$bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password)                                                                                                       
		$s1pw = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr) 

        Add-Type -AssemblyName System.DirectoryServices.AccountManagement
        $DS = New-Object System.DirectoryServices.AccountManagement.PrincipalContext('domain')
        $DS.ValidateCredentials($UserName, $s1pw)
    }
}


<#
.SYNOPSIS
	Helper wrapper around Powershell Send-MailMessage cmdlet
.DESCRIPTION
    Helper wrapper around Powershell Send-MailMessage cmdlet
  
.OUTPUTS

.EXAMPLE

#>
function Send-Email {
  [OutputType('System.Boolean')]
  [CmdletBinding()]
    Param
    (
		[Parameter(Mandatory=$false)]
		[Alias('ini')]
		[string] $INIFile="",
        [Parameter(Mandatory=$false)]
		[Alias('sub')]
        [string] $Subject = '',

        [Parameter(Mandatory=$true)]
        [string] $Body = '',

        [Parameter(Mandatory=$true)] [ValidateSet('Text','Html')]
        [string] $Type = 'Text',

        [Parameter(Mandatory=$false)] [ValidateSet('Normal','Low','High')]
		[Alias('pri')]
        [string] $Priority = 'Normal',
        
        [Parameter(Mandatory=$false)]
		[Alias('atts')]
        $Attachments,  # Can be a Comma-delimited String or an Array
        
        [Parameter(Mandatory=$false)]
		[Alias('sprefix')]
        [string] $SubjectPrefix            
    )

BEGIN {

	# get script location, load SMTP defaults from it...
	$scriptDirectory  = Split-Path -parent $PSCommandPath
	$INIDefaults = join-path $scriptDirectory 'Common-Config.ini'

	# Use the INI file passed in via command line, or the default one
	if ($INIFile -and (Test-Path $INIFile))
	{
		$hConfig = Get-IniContent $INIFile
	}
	else
	{
		Write-Verbose "$($MyInvocation.MyCommand.Name):: using default settings in $($INIDefaults)"
		$hConfig = Get-IniContent $INIDefaults
	}
}

PROCESS {

	if ($hConfig)
	{
		$EmailServer=$hConfig["SMTPSERVER"]["SMTP_SERVER"]
		$To=$hConfig["EMAILADDRESSES"]["SMTP_TO"]
		$From=$hConfig["EMAILADDRESSES"]["SMTP_FROM"]
		$CC=$hConfig["EMAILADDRESSES"]["SMTP_CC"]
		$SubPrefix=$hConfig["EMAILCONTENT"]["EMAIL_SUBJECT_PREFIX"]
	}

    if ($EmailServer -and $From -and $To)
    {
        # Convert SMTP_TO to an Array
        if ($To.Contains(','))
        {
            $aTo = $To.Split(',')
        }
        else
        {
            $aTo = ($To)
        }             

        if ($SubPrefix)
        {
            $Subject = "$SubPrefix $Subject"
        } 
    
        if ($SubjectPrefix)
        {
            $Subject = "$SubjectPrefix $Subject"
        }     

        # Assemble Command Text    
        $cmdtext = 'Send-MailMessage -ErrorAction Stop -SmtpServer $EmailServer -Subject $Subject -Priority $Priority -Body $Body -From $From -To $aTo'
        
        # Convert SMTP_CC to an Array    
        if ($CC)
        {
            if ($CC.Contains(','))
            {
                $aCc = $CC.Split(',')
            }
            else
            {
                $aCc = ($CC)
            }              
            $cmdtext += ' -Cc $aCc'
        }
        
        if ($Type -eq 'Html')
        {
            $cmdtext += ' -BodyAsHtml'
        }
        
        if ($Attachments)
        {
            if ($Attachments -is [System.Array])
            {
                $aFiles = $Attachments            
            }
            else
            {
                if ($Attachments.Contains(','))
                {
                    $aFiles = $Attachments.Split(',')
                }
                else
                {
                    $aFiles = ($Attachments)
                }
            }
            
            $aFilesToAttach = @()
            foreach ($file in $aFiles)
            {
                if (Test-Path $file.Trim())
                {
                    $aFilesToAttach += $file.Trim()
                }
                else
                {
                    Write-Error "File does not exist, cannot add as email attachment:  $($file)"
					return $false
                }
            }
            
            if ($aFilesToAttach.Length -gt 0)
            {
                $cmdtext += ' -Attachments $aFilesToAttach'
            }         
        }            
        
        Try
        {
            Invoke-Expression -Command "$cmdtext"
            Write-Verbose "Sent Email:  $($Subject)"
        }
        Catch
        {
            Write-Error "Failed To Send Email:  $($Subject), $($_.Exception.Message) " 
            return $false
        }
        
    }
    else
    {
        Write-Error "Configuration does not support sending email message: $($Subject)"
		Write-Error "Check input parameters !"
		return $false
    }

	$true

}

END {}

}

<#
.SYNOPSIS
   Usefull for creating new scripts from commands in an interactive session

.DESCRIPTION
   Usefull for creating new scripts from commands in an interactive session

.EXAMPLE
	Get-RecentCommands
#>

function Get-RecentCommands
{
 # Useful for creating new scripts from commands in session
Get-History | Select-Object commandline
}

#
#   Public Exports
#
New-Alias  Get-POSHVer           Get-POSHVersionAndArchitecture
Export-ModuleMember -function *
Export-ModuleMember -alias Get-POSHVer





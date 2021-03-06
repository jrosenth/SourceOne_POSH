#	 
#	Copyright � 2018 Dell Inc. or its subsidiaries. All Rights Reserved.
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#	       http://www.apache.org/licenses/LICENSE-2.0
#  
# THIS CODE AND INFORMATION IS PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND,
# WHETHER EXPRESSED OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A PARTICULAR PURPOSE.
# IF THIS CODE AND INFORMATION IS MODIFIED, THE ENTIRE RISK OF USE OR RESULTS IN
# CONNECTION WITH THE USE OF THIS CODE AND INFORMATION REMAINS WITH THE USER. 
#

$global:ES1PromptSettings = New-Object PSObject -Property @{
    DefaultForegroundColor    = $Host.UI.RawUI.ForegroundColor

    BeforeText                = ' ['
    BeforeForegroundColor     = [ConsoleColor]::Yellow
    BeforeBackgroundColor     = $Host.UI.RawUI.BackgroundColor
    DelimText                 = ' |'
    DelimForegroundColor      = [ConsoleColor]::Yellow
    DelimBackgroundColor      = $Host.UI.RawUI.BackgroundColor

    AfterText                 = ']'
    AfterForegroundColor      = [ConsoleColor]::Yellow
    AfterBackgroundColor      = $Host.UI.RawUI.BackgroundColor

    WorkingForegroundColor    = [ConsoleColor]::DarkRed
    WorkingBackgroundColor    = $Host.UI.RawUI.BackgroundColor


    EnableWindowTitle         = 'EMC SourceOne PowerShell'

    Debug                     = $false
}


$productName = "EMC SourceOne Powershell"
$productShortName = "SourceOne-"
$version = "xx.xx.xx.xx"
$windowTitle = "EMC SourceOne Powershell"
$host.ui.RawUI.WindowTitle = $ES1PromptSettings.EnableWindowTitle
$Host.UI.RawUI.ForegroundColor = "white"
$Host.UI.RawUI.BackgroundColor = "DarkBlue"

# Change buffer before window size
$buffer = $Host.UI.RawUI.BufferSize
$buffer.width=100
$buffer.height=2000
$Host.UI.RawUI.bufferSize=$buffer

$buffer = $Host.UI.RawUI.windowSize
$buffer.width=100
$buffer.height=40
$Host.UI.RawUI.WindowSize=$buffer

$currentDir = Split-Path $MyInvocation.MyCommand.Path

$WindowTitleSupported = $true
if (Get-Module SourceOne_POSH) {
    $WindowTitleSupported = $false
}

function Write-Prompt($Object, $ForegroundColor, $BackgroundColor = -1) {
    if ($BackgroundColor -lt 0) {
        Write-Host $Object -NoNewLine -ForegroundColor $ForegroundColor
    } else {
        Write-Host $Object -NoNewLine -ForegroundColor $ForegroundColor -BackgroundColor $BackgroundColor
    }
}

# Modify the prompt function to change the console prompt.
# Save the previous function, to allow restoring it back.
$originalPromptFunction = $function:prompt
function global:prompt{

    # change prompt text
    Write-Host "$productShortName>" -NoNewLine 
   # Write-Host ((Get-location).Path + ">") -NoNewLine
    return " "
}

Clear-Host
# the -DisableNameChecking prevents the warning about illegal verbs being shown
import-module "SourceOne_POSH.psd1" -DisableNameChecking
$version = (Get-Module SourceOne_POSH).version.ToString()

# Launch text
write-host ""
write-host "                 Welcome to the $productName! (v $version)"
write-host "                 Questions or problems should be posted in the Issues section on GitHub"
write-host ""
write-host "To find out what commands are available, type          : " -NoNewLine
write-host "Get-ES1Commands" -foregroundcolor yellow
write-host "To get additional help for any of those commands, type : " -NoNewline
write-host "Get-Help <command>" -foregroundcolor yellow
write-host "   where <command> is the command you want help on." 
Write-Host ""
Write-Host "The commands to manage SourceOne services require that the shell be started"
Write-Host '  with "Run as Admin" '
Write-Host ""




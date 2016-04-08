$global:IPMPromptSettings = New-Object PSObject -Property @{
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
$host.ui.RawUI.WindowTitle = $IPMPromptSettings.EnableWindowTitle
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
write-host " Copyright (C) 2015 EMC Corp. Professsional Services, All rights reserved."
write-host "                 Email questions or problems to SourceOneTools@emc.com"
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




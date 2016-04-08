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


    EnableWindowTitle         = 'EMC SourceOne IPM PowerShell'

    Debug                     = $false
}


$productName = "EMC DPAD SourceOne IPM Powershell"
$productShortName = "IPM-POSH"
$version = "xx.xx.xx.xx"
$windowTitle = "EMC DPAD SourceOne IPM Powershell"
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
$buffer.height=50
$Host.UI.RawUI.WindowSize=$buffer


#$CustomInitScriptName = "Initialize-PowerCLIEnvironment_Custom.ps1"
$currentDir = Split-Path $MyInvocation.MyCommand.Path
#$CustomInitScript = Join-Path $currentDir $CustomInitScriptName


$WindowTitleSupported = $true
if (Get-Module ES1_IPM_UTILS) {
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
    Write-Host "$productShortName > " -NoNewLine 
   # Write-Host ((Get-location).Path + ">") -NoNewLine
    return " "
}

Clear-Host
import-module "$currentDir\es1_ipm_utils.psd1"

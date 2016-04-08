#
# This scripts is run in the "pre-build" event of the VS 2013 solution
#  This script modifies the module manifest file AND the
#  ModuleVersion.wxi file so both the module and the installer are stamped
#  With the same version
#

# Change to script location
$scriptDirectory = Split-Path $myinvocation.mycommand.path
Set-Location $scriptDirectory

$file=$scriptDirectory+ '\SourceOne_POSH\SourceOne_POSH.psd1'
$wixfile = $scriptDirectory+ '\ES1PowerShellInstall\ModuleVersion.wxi'

#
# First modify the module manifest file
#
$lines = [System.IO.File]::ReadAllLines($file)
[int]$i=0
$newVersion=''

foreach ($line in $lines) {
    #$line

    if ($line.Contains('ModuleVersion =') )
   
    {
        $splitLine=$line.Split('=')
        $oldversion= $version= $splitLine[1]
        
        #remove leading and trailing '

        $version = $version -replace "'",""

        $splitVer=$version.Split('.')

        #increment the build number
        [int]$build=([int]$splitVer[3]) +1

        $newVersion="'{0}.{1}.{2}.{3}'" -f $splitVer[0].TrimStart(), $splitVer[1],$splitVer[2],$build
        $newInstVersion="{0}.{1}.{2}.{3}" -f $splitVer[0].TrimStart(), $splitVer[1],$splitVer[2],$build

        #$newVersion
        $line=$line.Replace($oldversion,$newVersion)
        $lines[$i]=$line
        Write-Host ""
        Write-Host "Update module version from $oldversion to  $newVersion"
        Write-Host ""

        break
    } 
    
    $i++


}

#$lines
try 
{
    [System.IO.File]::WriteAllLines($file,$lines,[System.Text.Encoding]::Unicode)
}
catch
{
    Write-Host "Error updating manifest file !"
    Write-Host $_
}

#
# Now generate/modify the include file for the installer
#
[xml] $wixVer= Get-Content $wixfile
 $newProdVersion='ProductVersion="{0}" '

 $versionNode= $wixVer.SelectSingleNode("//processing-instruction('define')")

 if ($versionNode -ne $null)
 {
    $versionNode.Value=$newProdVersion -f $newInstVersion
 }

 try 
{
   $wixVer.Save($wixfile)
}
catch
{
    Write-Host "Error updating Installer ModuleVersion.wxi file !"
    Write-Host $_
}
 

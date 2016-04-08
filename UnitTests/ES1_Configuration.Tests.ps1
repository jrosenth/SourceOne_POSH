$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$here = "..\SourceOne_POSH"
$here
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace '\.Tests\.', '.'
"$here\$sut"
#. "$here\$sut"


Describe "ES1 Configuration Functions" {
AfterAll {
		# return to the state before tests were run
		if ((Get-Module -Name "SourceOne_POSH"))
		{
			Remove-Module SourceOne_POSH
		}
	}
	
	BeforeAll {
		# return to the state before tests were run
		import-module SourceOne_POSH -DisableNameChecking -Force
        $local = hostname
        $configFile = "$local-Test-Settings.xml"
        [xml]$config = gc $configFile
        $remoting = $config.settings.remoting
        if ($remoting -eq 'no')
        {    
            $notremoting = $true
        }
        else
        {
           $notremoting = $false
        }
        $archive1

	}
    It "Get-ES1ActivityObj" {
        $test = $false
        $results = Get-ES1ActivityObj
        if (($results.activitydb.length -gt 0) -and ($results.activityserver.length -gt 0))
        {
            if (($s1Actdb -gt 0) -and ($s1ActServer -gt 0))
            {

                $test = $true

            }
        }
        $test | Should Be $true
    }
    It "Get-S1Workers" {
        $test = $false
        $results = Get-S1Workers
        if (($results.servername.length -gt 0) -and ($results.workerid -gt 0))
        {
            if ($s1Workers.Count -gt 0)
            {
            $test = $true
            }
        }
        $test | Should Be $true
    }
    It "Get-S1Archivers" {
        $test = $false
        $results = Get-S1Archivers
        if ($results.count -gt 0)
        {
            $test = $true
        }
        $test | Should Be $true
    }

    It "Get-S1ServerList" {
        $test = $false
        $results = Get-S1ServerList
        if ($results.count -eq 2)
        {
            
            $test = $true
            
        }
        $test | Should Be $true
    }
    It "Show-S1Servers" {
        $test = $false
        $results = Show-S1Servers
        if ($results.count -eq 2)
        {
            
            $test = $true
            
        }
        $test | Should Be $true
    }
     It "Get-S1Servers" {
        $test = $false
        $results = Get-S1Servers
        if ($results.count -eq 2)
        {
            if ($s1servers.Count -eq 2)
            {
            $test = $true
            }
        }
        $test | Should Be $true
    }
    It "Get-S1JobLogDir" {
        $test = $false
        $results = Get-S1JobLogDir
        if ($results.count -gt 0)
        {
            $test = $true
            
        }
        $test | Should Be $true
    }
    It "Get-S1InstallDir" {
        $test = $false
        $results = Get-S1JobLogDir
        if ($results.count -gt 0)
        {
            $test = $true
            
        }
        $test | Should Be $true
    }

    It "Get-ES1ArchiveDatabases" {
        $test = $false
        $results = @(Get-ES1ArchiveDatabases)
        if ($results.count -gt 0)
        {
            $Script:archive1 = $results[0]
            $Script:archive1
            $test = $true
        }
        
        $test | Should Be $true
    }

    It "Get-S1NAServers" {
        $test = $false
        try
        {
        $results = Get-S1NAServers $s1ActServer $s1ActDb
        }
        catch
        {
            $test = $true
        }
        $test | Should Be $true
    }
    It "Get-S1NAServers" {
        $test = $false
        try
        {
        $results = Get-S1NAServers $Script:archive1.dbserver $Script:archive1.dbname
        $test = $true
        }
        catch
        {
            $test = $false
        }
        $test | Should Be $true
    }
    It "Get-S1Binaries" {
        $test = $false
        
        try
        {
        $results = Get-S1Binaries  3>warnings.txt
            if ($results.count -gt 0)
            {
                if (($notremoting) -and ((gc warnings.txt).count -gt 0))
                {
                    $test = $true
                }
            }
        }
        catch
        {
            $test = $false
        }
        $test | Should Be $true
    }
    

}
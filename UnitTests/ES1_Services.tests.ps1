$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$here = "..\SourceOne_POSH"
$here
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace '\.Tests\.', '.'
"$here\$sut"
#. "$here\$sut"



Describe "ES1 Services Functions" {
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
        $tservers = $config.settings.servers
        $tservices = $config.settings.services.Object
        #$servicename = $tservices[0].Property[0].'#text'
        #$machinename = $tservices[0].Property[1].'#text'

        $Script:localServiceCount = $config.settings.servers[0].servicecount
        $Script:TotalServiceCount = [int] $Script:localServiceCount +  [int]$config.settings.servers[1].servicecount


	}
    It "Get-ES1Services" {
        $test = $false
        $results = Get-ES1Services
        if ($results.count -eq $Script:localServiceCount) 
        {
            $results[0]
            
            if ($results[0].DisplayName -match 'EMC SourceOne')
            {
                $test = $true
            }
                        
        }
        $test | Should Be $true
    }
   It "Show-AllES1Services" {
        $test = $false
        $results = Get-AllES1Services
        if ($results.count -gt 0) 
        {
           
            if ($Script:TotalServiceCount -eq $results.count)
            {
                $test = $true
             }
                        
        }
        $test | Should Be $true
    }

    It "Stop-ES1Services" {
        $test = $false
        $results = Stop-ES1Services
        sleep 10
        if ($results.count -gt 0) 
        {
           $results = Get-ES1Services
           $Script:localServiceCount = $results.count
           $results[0]
            if ($results[0].Status -eq 'Stopped')
            {
                $test = $true
            }
                        
        }
        $test | Should Be $true
    }

      It "Start-ES1Services" {
        $test = $false
        $results = Start-ES1Services
        sleep 10
        if ($results.count -gt 0) 
        {
           $results = Get-ES1Services
           $Script:localServiceCount = $results.count
           write-output $results[0].tostring()
            if ($results[0].Status -eq 'Running')
            {
                $test = $true
                }
                        
        }
        $test | Should Be $true
    }
    $local = hostname
    It "Stop-AllES1Services" {
        $test = $false
        $results = Stop-AllES1Services
        sleep 10
        if ($results.count -gt 0) 
        {
           $results = Get-AllES1Services
           $Script:localServiceCount = $results.count
           write-output $results[0].tostring()
           
            if ($results[0].Status -eq 'Stopped')
            {
                foreach ($entry in $results)
                {


                    if ($entry.machinename -ne $local)
                    {
                    $test = $true
                    }

                }
            }
                        
        }
        $test | Should Be $true
    }

    It "Start-AllES1Services" {
        $test = $false
        $results = Start-AllES1Services
        sleep 10
        if ($results.count -gt 0) 
        {
           $results = Get-AllES1Services
           $Script:localServiceCount = $results.count
           write-output $results[0].tostring()
            if ($results[0].Status -eq 'Running')
            {
                     foreach ($entry in $results)
                {


                    if ($entry.machinename -ne $local)
                    {
                    $test = $true
                    }

                }
                }
                        
        }
        $test | Should Be $true
    }
}
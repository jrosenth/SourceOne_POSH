#
# This is a PowerShell Unit Test file.
# You need a unit test framework such as Pester to run PowerShell Unit tests. 
# You can download Pester from http://go.microsoft.com/fwlink/?LinkID=534084
#

Describe "Test Cmdlets which get info from Databases or registry directly" {
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
	}
	Context "Testing DB Utils cmdlets"{

		It "Are we running on SourceOne Master" {
			$isMaster=Test-IsOnS1Master

			$isMaster | should be $False
			
		}

		It "Return the Activity DB and Activity SQL server names" {
				$actDB =  @(Get-ES1ActivityDatabase)

				$actDB.Length | Should be 1
				$actDB.DBServer | Should Not BeNullOrEmpty
				$actDB.DBName | Should Not BeNullOrEmpty

			
		}
		
		It "Return list of Worker machine(s)" {
				$workernames =  Get-ES1Workers

				$workernames.Length | Should BeGreaterThan 0
				
				foreach( $worker in $workernames)
				{
					$worker | Should Not BeNullOrEmpty
				}

			
		}

	}
}
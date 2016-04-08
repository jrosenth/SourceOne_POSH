
Describe "SourceOne PowerShell Activity Mock" {
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
	Context "Test Mock database"{

	}
}
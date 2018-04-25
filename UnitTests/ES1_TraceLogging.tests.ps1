#
# This is a PowerShell Unit Test file.
# You need a unit test framework such as Pester to run PowerShell Unit tests. 
# You can download Pester from http://go.microsoft.com/fwlink/?LinkID=534084
#

Describe "SourceOne Trace Verbosity and Logging Test" {
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
	
	
	
	
	}
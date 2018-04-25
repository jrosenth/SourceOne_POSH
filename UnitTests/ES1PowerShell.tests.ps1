#
# This is a PowerShell Unit Test file.
# You need a unit test framework such as Pester to run PowerShell Unit tests. 
# You can download Pester from http://go.microsoft.com/fwlink/?LinkID=534084
#

Describe "SourceOne PowerShell Test Installation and Import-Module " {
	AfterAll {
		# return to the state before tests were run
		if ((Get-Module -Name "SourceOne_POSH"))
		{
			Remove-Module SourceOne_POSH
		}
	}
	Context "SourceOne PowerShell basic path and import module tests" {
		It "SourceOne Powershell directory should be in module path (if installed with msi instaler)" {
			$modPath=$env:PSModulePath
			$good=($modPath.Contains('SourceOne PowerShell'))

			$good | Should be $True
		}
	
		It "SourceOne Powershell module should import" {
			
			# Import-module uses a non terminating exception so cant use try/catch
			$loadFailed=$False
			import-module SourceOne_POSH -DisableNameChecking -ErrorAction SilentlyContinue -ErrorVariable importError
			if ($importError)
			{
				$loadFailed=$True
			}
			
			$loadFailed | Should be $False
		}
	}
}


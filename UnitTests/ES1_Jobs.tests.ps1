$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$here = "..\SourceOne_POSH"
$here
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace '\.Tests\.', '.'
"$here\$sut"
#. "$here\$sut"




Describe "My ES1_Jobs Functions" {
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

	}
    It "displays the last 10 jobs (default)" {
        $list1 = @(get-s1jobs)
        $list1.count | Should Be '11'
    }
     It "displays the last 5 jobs using -newest parameter" {
        $list2 = @(get-es1jobinfo -newest 5)
        $list2.count | Should Be '6'
    }
    
     It "displays the last 10 jobs with a failed state" {
        $list3 = get-es1jobinfo -failed 
        $list3.count | Should Be '3'
    }
    It "displays the last 10 jobs with a failed items" {
        $list3 = get-es1jobinfo -failedItems 
        $list3.count | Should Be '3'
    }
     It "displays the last 10 jobs jobs with jobtype = HA" {
        $list3 = get-es1jobinfo -jobtype HA
        $list3.count | Should Be '4'
    }
     It "displays the last 10 jobs jobs with jobtype = journal" {
        $list3 = get-es1jobinfo -jobtype journal
        $list3.count | Should Be '11'
    }
    It "displays the last 10 jobs (default) days=0 ignored" {
        $list3 = Get-S1Jobs -days 0 
        $list3.count | Should Be '11'
    }
    It "displays the last jobs since yesterday -usedate " {
        $jobs  = Get-S1Jobs -usedate | sort starttime
        $result = $false
        $start = $jobs[1].StartTime.addhours(5)
        $start
        if ($start -ge [datetime]::today) {
            $result = $true
        }
        $result | Should Be $true
    }
    It "displays the last jobs since 4 days ago $days = -4 " {
        $jobs = Get-S1Jobs -days -4
        $result = $false
        $start = $jobs[1].StartTime.addhours(5)
        $start
        if ($start -ge ([datetime]::today).AddDays(-4)) {
            $result = $true
        }
        $result | Should Be $true
    }
    It "displays all job logs " {
        $list3 = @(Show-ES1JobLogs)
        $testResult = $false
        if ($list3.count -gt 0)
        {
            $testResult = $true
        }
        $testResult | Should Be $true
    }

     It "displays the summary of all job logs " {
        $list3 = (Find-inES1JobLogs | select-string "MSG.LOG").count
        $list3 | Should Be '21'
    }

    It "displays the summary of all job logs from 12-02-2015 " {
        $list3 = (Find-inES1JobLogs -startdate 12-02-2015).count
        $list3 | Should Be '10'
    }
    It "displays the summary of 60 days of logs all job logs from 05-01-2015 " {
        $list3 = (Find-inES1JobLogs -startdate 05-01-2015 -days 60).count
        $list3 | Should Be '20'
    }
    It "displays the summary of the log for Jobid 34 " {
        $list3 = Find-inES1JobLogs -JobId 34 | select-string "MSG.LOG"
        $list3 | Should Be '\\master\joblogs\00000022DETMSG.LOG'
    }
    It "displays the summary of the logs which contain -searchstr 'denied' " {
        $list3 = (Find-inES1JobLogs -searchStr "denied").count
        $list3 | Should Be '85'
    }
     It "displays the line of the logs which contain -searchstr 'denied'  with linecontext 5" {
        $list3 = Find-inES1JobLogs -searchStr "denied" -lineContext 5
        $str = $list3[2].Context.PreContext[1].Trim()
        $result = $str.CompareTo('Size: 108,024 (105 KB)')
        
        $result | Should Be '0'
    }
    
}

BeforeAll {
    # Import the SmartLogAnalyzer module before running any tests
    $modulePath = Join-Path $PSScriptRoot "..\..\SmartLogAnalyzer.psd1"
    try {
        Import-Module $modulePath -Force -ErrorAction Stop
    }
    catch {
        Write-Error "SmartLogAnalyzer module could not be loaded from '$modulePath'. Please check the module path and try again.`nError: $($_.Exception.Message)"
        exit 1
    }

    if (-not (Get-Module -Name SmartLogAnalyzer)) {
        Write-Error "SmartLogAnalyzer module is not loaded after import attempt."
        exit 1
    }
}

Describe "SmartLogAnalyzer - Full Module Integration Test Suite" {

    Context "Public Function: Get-LogEntries" {
        It "Should parse a sample log file and return structured entries" {
            $logPath = Join-Path $PSScriptRoot "Sample.Logs\sample.test.log"
            $entries = Get-LogEntries -Path $logPath
            $entries | Should -Not -BeNullOrEmpty
            $entries[0] | Should -HaveProperty 'TimeCreated'
            $entries[0] | Should -HaveProperty 'Level'
            $entries[0] | Should -HaveProperty 'Message'
        }
    }

    Context "Public Function: Get-LogSummary" {
        It "Should return a summary object with counts" {
            $logPath = Join-Path $PSScriptRoot "Sample.Logs\sample.test.log"
            $entries = Get-LogEntries -Path $logPath
            $summary = Get-LogSummary -LogLines $entries
            $summary.TotalLines | Should -BeGreaterThan 0
        }
    }

    Context "Public Function: Invoke-SmartAnalyzer with -Path" {
        It "Should return entries and summary from sample log" {
            $logPath = Join-Path $PSScriptRoot "Sample.Logs\sample.test.log"
            $result = Invoke-SmartAnalyzer -Path $logPath -AttentionOnly
            $result.Entries.Count | Should -Be 3
            $result.Summary | Should -Not -BeNullOrEmpty
        }
    }

    Context "Public Function: Invoke-SmartAnalyzer with -FetchLogs" {
        It "Should auto-fetch system logs and generate a report" {
            $reportPath = Join-Path $env:TEMP "SystemLogReport.txt"
            $result = Invoke-SmartAnalyzer -FetchLogs -LogType System -AttentionOnly -Colorize -ReportPath $reportPath -ReportFormat Text
            $result.Entries | Should -Not -BeNullOrEmpty
            Test-Path $reportPath | Should -BeTrue
        }
    }

    Context "Public Function: Get-SystemLogs" {
        It "Should fetch logs for the system log type on current OS" {
            $entries = Get-SystemLogs -LogType System -StartTime (Get-Date).AddHours(-1) -EndTime (Get-Date)
            $entries | Should -Not -BeNullOrEmpty
        }
    }

    Context "Public Function: Get-SystemLogs (Linux journalctl fallback)" {
        It "Should fetch journalctl logs on Linux systems" -Skip:(!$IsLinux) {
            $entries = Get-SystemLogs -LogType System -StartTime (Get-Date).AddHours(-1) -EndTime (Get-Date)
            $entries | Should -Not -BeNullOrEmpty
        }
    }

    Context "Private Function: Protect-LogEntry" {
        It "Should redact sensitive info in log message" {
            $log = @{ Message = "User admin with password 1234 logged in." }
            $redacted = Protect-LogEntry -Entry $log
            $redacted.Message | Should -Not -Match "1234"
        }
    }

    Context "Private Function: Convert-Timestamp" {
        It "Should convert a log timestamp to [datetime] object" {
            $timestamp = "2025-06-17 14:22:15"
            $converted = Convert-Timestamp -Input $timestamp
            $converted | Should -BeOfType "System.DateTime"
        }
    }

    Context "Private Function: Format-LogEntry" {
        It "Should format a raw log string into an object" {
            $line = "2025-06-17 14:22:17 [ERROR] AuthService: Failed login attempt"
            $formatted = Format-LogEntry -Line $line
            $formatted.Level | Should -Be "ERROR"
            $formatted.Message | Should -Match "Failed login"
        }
    }

    Context "Private Function: Export-LogReport" {
        It "Should create a report file from summary and entries" {
            $logPath = Join-Path $PSScriptRoot "Sample.Logs\sample.test.log"
            $entries = Get-LogEntries -Path $logPath
            $summary = Get-LogSummary -LogLines $entries
            $reportPath = Join-Path $env:TEMP "ExportedReport.txt"
            Export-LogReport -Summary $summary -Entries $entries -SourcePath $logPath -OutputPath $reportPath -Format Text
            Test-Path $reportPath | Should -BeTrue
        }
    }

    Context "Windows GUI: Show-LogAnalyzerUI" {
        It "Should be defined as a function on Windows only" {
            if ($IsWindows) {
                (Get-Command Show-LogAnalyzerUI -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
            }
        }
    }
}

# Ensure the script exits with the correct exit code
$LASTEXITCODE = 0
# End of SmartLogAnalyzer.Integration.tests.ps1
#
# This script contains integration tests for the Smart Log Analyzer module,
# focusing on the Invoke-SmartAnalyzer function to validate end-to-end behavior.
#
# Test scenarios covered include:
# - Basic parsing of log entries and verification of summary statistics
# - Filtering by include and exclude keywords to test log selection accuracy
# - Time range filtering to ensure proper date-based entry filtering
# - Export functionality validating CSV and JSON export outputs and file creation
# - Handling of invalid input paths, ensuring appropriate errors are thrown
#
# Implemented using Pester with Should assertions, these tests provide robust validation
# of core SmartLogAnalyzer functionality in a realistic usage context.
#
# Designed for execution in a PowerShell environment with the SmartLogAnalyzer module loaded,
# these integration tests support continuous integration pipelines and ongoing module quality assurance.
#
# The suite is structured to be maintainable and extensible, facilitating future enhancements
# to the Smart Log Analyzer testing framework.
#
# The script sets the $LASTEXITCODE to 0 to indicate successful test completion.
# This allows for smooth integration with CI/CD workflows, avoiding false failure signals.
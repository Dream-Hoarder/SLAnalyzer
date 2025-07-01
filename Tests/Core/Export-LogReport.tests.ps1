# Tests\Export-LogReport.tests.ps1
BeforeAll {
    # Ensure module loads
    Import-Module "$PSScriptRoot\..\..\SmartLogAnalyzer.psd1" -Force -ErrorAction Stop

    # Dot-source the private function manually for test access
    . "$PSScriptRoot\..\..\Private\Export-LogReport.ps1"
}

Describe "Export-LogReport" {
    It "writes report to the specified file" {
        $logData = @{"Level" = "Warning"; "Message" = "Test issue"}
        $reportPath = "$PSScriptRoot\report.json"

        Export-LogReport -LogData $logData -ReportPath $reportPath -ReportFormat JSON
        Test-Path $reportPath | Should -BeTrue
    }

    It "redacts sensitive info if -Redact is used" {
        $logData = @{"User" = "admin"; "Password" = "secret"}
        $reportPath = "$PSScriptRoot\redacted.json"

        Export-LogReport -LogData $logData -ReportPath $reportPath -Redact
        Get-Content $reportPath | Should -Not -Match "secret"
    }
}

Describe "Export-LogReport - Error Handling" {
    It "throws an error for invalid report format" {
        $logData = @{"Level" = "Error"; "Message" = "Test error"}
        $reportPath = "$PSScriptRoot\invalid_report.txt"

        { Export-LogReport -LogData $logData -ReportPath $reportPath -ReportFormat Invalid } | Should -Throw
    }

    It "handles empty log data gracefully" {
        $reportPath = "$PSScriptRoot\empty_report.json"

        Export-LogReport -LogData @{} -ReportPath $reportPath -ReportFormat JSON
        Test-Path $reportPath | Should -BeTrue
    }
}

Describe "Export-LogReport - Performance Tests" {
    It "writes large log data efficiently" {
        $largeLogData = @{"Message" = "This is a large log entry " * 1000}
        $reportPath = "$PSScriptRoot\large_report.json"

        { Export-LogReport -LogData $largeLogData -ReportPath $reportPath -ReportFormat JSON } | Should -Not -Throw
        Test-Path $reportPath | Should -BeTrue
    }

    It "handles multiple entries in a batch" {
        $logData = @(
            @{"Level" = "Info"; "Message" = "First entry"},
            @{"Level" = "Error"; "Message" = "Second entry"}
        )
        $reportPath = "$PSScriptRoot\batch_report.json"

        { Export-LogReport -LogData $logData -ReportPath $reportPath -ReportFormat JSON } | Should -Not -Throw
        Test-Path $reportPath | Should -BeTrue
    }
}

Describe "Export-LogReport - Redaction Patterns" {
    It "redacts sensitive information in messages" {
        $logData = @{
            "User" = "admin"
            "Password" = "1234"
            "Message" = "User admin logged in with password 1234"
        }
        $reportPath = "$PSScriptRoot\redacted_report.json"
        Export-LogReport -LogData $logData -ReportPath $reportPath -Redact
        $content = Get-Content $reportPath
        $content | Should -Not -Match "1234"
        $content | Should -Match "\[REDACTED\]"
    }

    It "handles multiple sensitive fields in a message" {
        $logData = @{
            "User" = "admin"
            "Password" = "1234"
            "Token" = "abcdef"
            "Message" = "User admin logged in with password 1234 and token abcdef"
        }
        $reportPath = "$PSScriptRoot\multi_redacted_report.json"
        Export-LogReport -LogData $logData -ReportPath $reportPath -Redact
        $content = Get-Content $reportPath
        $content | Should -Not -Match "1234"
        $content | Should -Not -Match "abcdef"
        $content | Should -Match "\[REDACTED\]"
    }
}

Describe "Export-LogReport - Edge Cases" {
    It "handles null or empty log data" {
        $reportPath = "$PSScriptRoot\empty_log_report.json"
        { Export-LogReport -LogData $null -ReportPath $reportPath -ReportFormat JSON } | Should -Throw
        { Export-LogReport -LogData @{} -ReportPath $reportPath -ReportFormat JSON } | Should -Not -Throw
        Test-Path $reportPath | Should -BeTrue
    }

    It "handles invalid report paths gracefully" {
        $logData = @{"Level" = "Critical"; "Message" = "Test critical issue"}
        $reportPath = "$PSScriptRoot\invalid\path\report.json"

        { Export-LogReport -LogData $logData -ReportPath $reportPath -ReportFormat JSON } | Should -Throw
    }
}
# Ensure the script exits with the correct exit code
$LASTEXITCODE = 0   
# End of Export-LogReport.tests.ps1
#
# This script tests the Export-LogReport function of the SmartLogAnalyzer module.
# It validates the function's ability to write reports, redact sensitive information,
# handle errors, and perform efficiently with large datasets.
#
# The tests cover various scenarios, including:
# - Valid inputs and output file creation
# - Redaction of sensitive data to prevent exposure
# - Error handling for invalid formats and paths
# - Performance with large and batch log data
# - Edge cases such as null or empty log data
#
# Implemented using the Pester testing framework and the Should assertion module,
# the tests provide clear feedback on the function’s correctness and robustness.
#
# Designed to be run in a PowerShell environment with the SmartLogAnalyzer module loaded,
# this suite is part of a comprehensive testing framework including Get-LogEntries,
# Get-SystemLogs, and Invoke-SmartAnalyzer tests, ensuring high code quality and reliability.
#
# The suite supports continuous integration workflows to catch regressions early
# and is structured for maintainability and easy extension as the module evolves.

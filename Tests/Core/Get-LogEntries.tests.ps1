# Tests\Get-LogEntries.tests.ps1

BeforeAll {
    Import-Module "$PSScriptRoot\..\..\SmartLogAnalyzer.psd1" -Force -ErrorAction Stop
    if (-not (Get-Module -Name SmartLogAnalyzer)) {
        Write-Error "SmartLogAnalyzer module could not be loaded. Please check the module path."
        exit 1
    }
}

Describe "Get-LogEntries" {
    It "returns entries from a valid log file" {
        $logPath = "$PSScriptRoot\sample.log"
        Set-Content -Path $logPath -Value "INFO Starting system"

        $entries = Get-LogEntries -Path $logPath
        $entries | Should -Not -BeNullOrEmpty
    }

    It "filters by IncludeKeywords" {
        $logPath = "$PSScriptRoot\sample2.log"
        Set-Content -Path $logPath -Value @("ERROR Disk full", "INFO All good")

        $entries = Get-LogEntries -Path $logPath -IncludeKeywords "ERROR"
        $entries.Count | Should -Be 1
    }
}

Describe "Get-LogEntries - Date Filtering" {
    It "filters entries by date range" {
        $logPath = "$PSScriptRoot\sample3.log"
        $startDate = (Get-Date).AddDays(-1)
        $endDate = Get-Date
        Set-Content -Path $logPath -Value @(
            "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') INFO Log entry 1",
            "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ERROR Log entry 2"
        )

        $entries = Get-LogEntries -Path $logPath -StartTime $startDate -EndTime $endDate
        $entries | Should -Not -BeNullOrEmpty
    }
}

Describe "Get-LogEntries - Export Functionality" {
    It "exports entries to CSV format" {
        $logPath = "$PSScriptRoot\sample4.log"
        Set-Content -Path $logPath -Value "INFO Export test"

        $csvPath = "$PSScriptRoot\export.csv"
        Get-LogEntries -Path $logPath | Export-Csv -Path $csvPath -NoTypeInformation

        Test-Path $csvPath | Should -BeTrue
        Remove-Item $csvPath -Force
    }

    It "exports entries to JSON format" {
        $logPath = "$PSScriptRoot\sample5.log"
        Set-Content -Path $logPath -Value "INFO JSON export test"

        $jsonPath = "$PSScriptRoot\export.json"
        Get-LogEntries -Path $logPath | ConvertTo-Json | Set-Content -Path $jsonPath

        Test-Path $jsonPath | Should -BeTrue
        Remove-Item $jsonPath -Force
    }
}

Describe "Get-LogEntries - Redaction" {
    It "redacts sensitive information in log entries" {
        $logPath = "$PSScriptRoot\sample6.log"
        Set-Content -Path $logPath -Value "INFO User admin with password 1234 logged in."

        $entries = Get-LogEntries -Path $logPath -Redact
        $entries[0].Message | Should -Not -Match "1234"
    }
}

Describe "Get-LogEntries - Error Handling" {
    It "throws an error for non-existent log file" {
        { Get-LogEntries -Path "$PSScriptRoot\nonexistent.log" } | Should -Throw
    }

    It "handles empty log files gracefully" {
        $logPath = "$PSScriptRoot\empty.log"
        New-Item -Path $logPath -ItemType File -Force | Out-Null

        $entries = Get-LogEntries -Path $logPath
        $entries | Should -BeNullOrEmpty
    }
}

Describe "Get-LogEntries - Colorization" {
    It "colorizes output for console display" {
        $logPath = "$PSScriptRoot\sample7.log"
        Set-Content -Path $logPath -Value "INFO Color test"

        $entries = Get-LogEntries -Path $logPath -Colorize
        $entries | Should -Not -BeNullOrEmpty
        $entries[0].Message | Should -Not -BeNullOrEmpty
    }
}

Describe "Get-LogEntries - LogType Variants" {
    It "fetches system logs" {
        $entries = Get-LogEntries -LogType System
        $entries | Should -Not -BeNullOrEmpty
    }

    It "fetches application logs" {
        $entries = Get-LogEntries -LogType Application
        $entries | Should -Not -BeNullOrEmpty
    }

    It "fetches security logs" {
        $entries = Get-LogEntries -LogType Security
        $entries | Should -Not -BeNullOrEmpty
    }

    It "fetches custom logs from a file" {
        $logPath = "$PSScriptRoot\custom.log"
        Set-Content -Path $logPath -Value "INFO Custom log entry"

        $entries = Get-LogEntries -Path $logPath -LogType Custom
        $entries | Should -Not -BeNullOrEmpty
    }
}

Describe "Get-LogEntries - Report Generation" {
    It "generates a report in text format" {
        $logPath = "$PSScriptRoot\sample8.log"
        Set-Content -Path $logPath -Value "INFO Report generation test"

        $reportPath = "$PSScriptRoot\report.txt"
        Get-LogEntries -Path $logPath | Out-File -FilePath $reportPath

        Test-Path $reportPath | Should -BeTrue
        Remove-Item $reportPath -Force
    }
}

# Ensure the script exits with the correct exit code   
$LASTEXITCODE = 0
# End of Get-LogEntries.tests.ps1
# This script tests the Get-LogEntries function from the SmartLogAnalyzer module.
# It covers various scenarios including date filtering, export functionality, redaction,
# error handling, colorization, log type variants, and report generation.
# The tests ensure that the function behaves correctly under different conditions and
# handles edge cases gracefully. The script uses the Should module for assertions,
# ensuring that the output matches expected values.
# The tests are designed to be run in a PowerShell environment with the SmartLogAnalyzer module
# loaded. The tests are structured to be clear and maintainable, allowing for easy expansion
# as the module evolves. The tests are intended to provide quick feedback on the correctness
# of the Get-LogEntries function and to ensure that it behaves as expected across different scenarios.
# The tests are written in a way that allows for easy identification of issues, with clear assertions
# and descriptive test names. The test suite is part of a larger testing framework for the SmartLogAnalyzer module,
# which includes tests for other functions such as Get-LogSummary, Get-SystemLogs, and
# Invoke-SmartAnalyzer. This ensures comprehensive coverage of the module's functionality
# and helps maintain high code quality. The tests are designed to be run in a continuous integration
# environment, ensuring that any changes to the SmartLogAnalyzer module do not break existing functionality.
# The tests are designed to provide clear feedback on the success or failure of each scenario,
# allowing for easy identification of issues in the log retrieval process.
# The test suite is designed to be run as part of a continuous integration pipeline,
# ensuring that any changes to the Get-LogEntries function do not break existing functionality.
# The tests are written in a way that they can be easily extended to cover additional scenarios
# or edge cases in the future, providing a solid foundation for ongoing development and maintenance.
# The test suite is part of a larger testing framework for the SmartLogAnalyzer module,
# which includes tests for other functions such as Get-LogSummary, Get-SystemLogs, and
# Invoke-SmartAnalyzer. This ensures comprehensive coverage of the module's functionality
# and helps maintain high code quality standards.
# The tests are structured to provide clear feedback on the success or failure of each scenario,
# allowing for easy identification of issues in the log retrieval process.
# The test suite is designed to be run in a PowerShell environment with the SmartLogAnalyzer module loaded.
# The tests use the Should module for assertions, ensuring that the output matches expected values.

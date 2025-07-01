# BeforeAll - Import the module
BeforeAll {
    Import-Module "$PSScriptRoot\..\..\SmartLogAnalyzer.psd1" -Force -ErrorAction Stop
    if (-not (Get-Module -Name SmartLogAnalyzer)) {
        Write-Error "SmartLogAnalyzer module could not be loaded. Please check the module path."
        exit 1
    }
}

Describe "Invoke-SmartAnalyzer - Basic Functionality" {
    It "Returns structured entries and summary from a sample path" {
        $logPath = Join-Path $PSScriptRoot "../Sample.Logs/sample.test.log"
        $result = Invoke-SmartAnalyzer -Path $logPath

        $result | Should -HaveProperty 'Entries'
        $result.Entries.Count | Should -BeGreaterThan 0
        $result.Summary.TotalLines | Should -Be $result.Entries.Count
    }
}

Describe "Invoke-SmartAnalyzer - FetchLogs Mode" {
    It "Generates a report from fetched system logs" {
        $reportPath = Join-Path $PSScriptRoot "../tmp/SystemLogReport.txt"
        $result = Invoke-SmartAnalyzer -FetchLogs -LogType System -AttentionOnly -Colorize -ReportPath $reportPath -ReportFormat Text

        $result.Entries | Should -Not -BeNullOrEmpty
        Test-Path $reportPath | Should -BeTrue

        Remove-Item $reportPath -Force
    }
}

Describe "Invoke-SmartAnalyzer - AttentionOnly" {
    It "Returns only attention entries from a sample log" {
        $logPath = Join-Path $PSScriptRoot "../Sample.Logs/sample.test.log"
        $result = Invoke-SmartAnalyzer -Path $logPath -AttentionOnly

        $result.Entries | Should -Not -BeNullOrEmpty
        $result.Entries | Where-Object { $_.Level -eq 'Attention' } | Should -Not -BeNullOrEmpty
    }
}

Describe "Invoke-SmartAnalyzer - IncludeKeywords" {
    It "Includes only lines with specified keywords" {
        $logPath = Join-Path $PSScriptRoot "../Sample.Logs/sample.test.log"
        $result = Invoke-SmartAnalyzer -Path $logPath -IncludeKeywords 'fatal'

        $result.Entries.Count | Should -BeGreaterThan 0
        ($result.Entries -join "`n") | Should -Match 'fatal'
    }
}

Describe "Invoke-SmartAnalyzer - ExcludeKeywords" {
    It "Excludes lines with specified keywords" {
        $logPath = Join-Path $PSScriptRoot "../Sample.Logs/sample.test.log"
        $result = Invoke-SmartAnalyzer -Path $logPath -ExcludeKeywords 'debug'

        ($result.Entries -join "`n") | Should -Not -Match 'debug'
    }
}

Describe "Invoke-SmartAnalyzer - Date Filtering" {
    It "Filters lines by date range" {
        $logPath = Join-Path $PSScriptRoot "../Sample.Logs/sample.test.log"
        $start = Get-Date '2023-01-01'
        $end   = Get-Date '2023-12-31'
        $result = Invoke-SmartAnalyzer -Path $logPath -StartTime $start -EndTime $end

        foreach ($line in $result.Entries) {
            $parsed = Convert-Timestamp -TimestampString $line.Timestamp
            if ($parsed) {
                $parsed | Should -BeGreaterThanOrEqualTo $start
                $parsed | Should -BeLessThanOrEqualTo $end
            }
        }
    }
}

Describe "Invoke-SmartAnalyzer - Exporting Logs" {
    It "Exports entries to CSV and JSON correctly" {
        $logPath = Join-Path $PSScriptRoot "../Sample.Logs/sample.test.log"
        $csvPath = Join-Path $PSScriptRoot "../tmp/export.csv"
        $jsonPath = Join-Path $PSScriptRoot "../tmp/export.json"

        Invoke-SmartAnalyzer -Path $logPath -ExportPath $csvPath -ExportFormat CSV | Out-Null
        Invoke-SmartAnalyzer -Path $logPath -ExportPath $jsonPath -ExportFormat JSON | Out-Null

        Test-Path $csvPath | Should -BeTrue
        Test-Path $jsonPath | Should -BeTrue

        Remove-Item $csvPath, $jsonPath -Force
    }
}

Describe "Invoke-SmartAnalyzer - Redaction" {
    It "Redacts sensitive information in log entries" {
        $logPath = Join-Path $PSScriptRoot "../Sample.Logs/sample.test.log"
        $result = Invoke-SmartAnalyzer -Path $logPath -Redact

        foreach ($entry in $result.Entries) {
            $entry.Message | Should -Not -Match 'password|secret'
        }
    }
}

Describe "Invoke-SmartAnalyzer - Colorization" {
    It "Colorizes output for console display" {
        $logPath = Join-Path $PSScriptRoot "../Sample.Logs/sample.test.log"
        $result = Invoke-SmartAnalyzer -Path $logPath -Colorize

        $result.Entries | Should -Not -BeNullOrEmpty
        $result.Entries[0].Message | Should -Not -BeNullOrEmpty
    }
}

Describe "Invoke-SmartAnalyzer - LogType Variants" {
    It "Fetches system logs" {
        $result = Invoke-SmartAnalyzer -LogType System
        $result.Entries | Should -Not -BeNullOrEmpty
        $result.Summary.TotalLines | Should -Be $result.Entries.Count
    }

    It "Fetches application logs" {
        $result = Invoke-SmartAnalyzer -LogType Application
        $result.Entries | Should -Not -BeNullOrEmpty
        $result.Summary.TotalLines | Should -Be $result.Entries.Count
    }

    It "Fetches security logs" {
        $result = Invoke-SmartAnalyzer -LogType Security
        $result.Entries | Should -Not -BeNullOrEmpty
        $result.Summary.TotalLines | Should -Be $result.Entries.Count
    }

    It "Fetches custom logs from a file" {
        $logPath = Join-Path $PSScriptRoot "../Sample.Logs/custom.test.log"
        $result = Invoke-SmartAnalyzer -Path $logPath -LogType Custom
        $result.Entries | Should -Not -BeNullOrEmpty
        $result.Summary.TotalLines | Should -Be $result.Entries.Count
    }
}

Describe "Invoke-SmartAnalyzer - Report Generation" {
    It "Generates a report in text format" {
        $logPath = Join-Path $PSScriptRoot "../Sample.Logs/sample.test.log"
        $reportPath = Join-Path $PSScriptRoot "../tmp/report.txt"

        Invoke-SmartAnalyzer -Path $logPath -ReportPath $reportPath -ReportFormat Text | Out-Null
        Test-Path $reportPath | Should -BeTrue

        Remove-Item $reportPath -Force
    }
}

Describe "Invoke-SmartAnalyzer - Error Handling" {
    It "Throws an error for invalid log paths" {
        { Invoke-SmartAnalyzer -Path "InvalidPath.log" } | Should -Throw
    }

    It "Handles empty log files gracefully" {
        $emptyLogPath = Join-Path $PSScriptRoot "../Sample.Logs/empty.log"
        New-Item -Path $emptyLogPath -ItemType File -Force | Out-Null

        $result = Invoke-SmartAnalyzer -Path $emptyLogPath
        $result.Entries | Should -BeNullOrEmpty
        $result.Summary.TotalLines | Should -Be 0

        Remove-Item $emptyLogPath -Force
    }
}

# Cleanup temporary files created during tests
AfterAll {
    $tempFiles = @(
        Join-Path $PSScriptRoot "../tmp/SystemLogReport.txt",
        Join-Path $PSScriptRoot "../tmp/export.csv",
        Join-Path $PSScriptRoot "../tmp/export.json",
        Join-Path $PSScriptRoot "../tmp/report.txt"
    )

    foreach ($file in $tempFiles) {
        if (Test-Path $file) {
            Remove-Item $file -Force
        }
    }
}

# End of Invoke-SmartAnalyzer.tests.ps1
#
# This script tests the Invoke-SmartAnalyzer function from the SmartLogAnalyzer module.
# It validates core functionality including log parsing, filtering, redaction, exporting, and reporting.
#
# The tests cover a wide range of scenarios such as:
# - Basic operation with sample logs and system logs fetching
# - FetchLogs mode with attention-only filtering and colorized output
# - Keyword-based inclusion and exclusion filters
# - Date range filtering and timestamp validation
# - Exporting parsed logs to CSV and JSON formats
# - Redaction of sensitive information in log messages
# - Handling of various log types (System, Application, Security, Custom)
# - Report generation in text format
# - Robust error handling for invalid paths and empty files
#
# Using the Pester framework and Should assertions, these tests provide clear feedback on function correctness,
# ensuring the output structure and content meet expectations.
#
# Designed to run in a PowerShell environment with the SmartLogAnalyzer module loaded,
# this suite integrates with other module tests for comprehensive coverage.
#
# The tests facilitate continuous integration workflows by detecting regressions early
# and are written for maintainability and extensibility as the module evolves.
# The suite is structured to provide quick feedback on the correctness of the Invoke-SmartAnalyzer function,
# ensuring it behaves as expected across different scenarios.
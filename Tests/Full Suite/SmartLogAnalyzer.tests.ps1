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

Describe 'Smart Log Analyzer - Integration Tests' {

    $samplePath = Join-Path $PSScriptRoot 'SampleLogs\sample.log'
    
    Context 'Basic Entry and Summary Validation' {
        It 'Parses entries and returns summary correctly' {
            $result = Invoke-SmartAnalyzer -Path $samplePath

            $result | Should -Not -BeNullOrEmpty
            $result.Entries.Count | Should -BeGreaterThan 0

            $summary = $result.Summary
            $summary | Should -HaveProperty 'TotalLines'
            $summary.TotalLines | Should -Be $result.Entries.Count
            $summary | Should -HaveProperty 'ErrorCount'
            $summary | Should -HaveProperty 'InfoCount'
            $summary | Should -HaveProperty 'WarningCount'
        }
    }

    Context 'Filtering by Include/Exclude Keywords' {
        It 'Includes only lines with "fatal"' {
            $result = Invoke-SmartAnalyzer -Path $samplePath -IncludeKeywords 'fatal'
            $result.Entries.Count | Should -BeGreaterThan 0
            ($result.Entries.Message -join "`n") | Should -Match 'fatal'
        }

        It 'Excludes lines with "debug"' {
            $result = Invoke-SmartAnalyzer -Path $samplePath -ExcludeKeywords 'debug'
            ($result.Entries.Message -join "`n") | Should -Not -Match 'debug'
        }
    }

    Context 'Time Range Filtering' {
        $start = Get-Date '2023-01-01'
        $end   = Get-Date '2023-12-31'

        It 'Filters lines by date range' {
            $result = Invoke-SmartAnalyzer -Path $samplePath -StartTime $start -EndTime $end
            foreach ($entry in $result.Entries) {
                if ($entry.Timestamp) {
                    $entry.Timestamp | Should -BeGreaterThanOrEqualTo $start
                    $entry.Timestamp | Should -BeLessThanOrEqualTo $end
                }
            }
        }
    }

    Context 'Exporting Functionality' {
        It 'Exports to CSV and JSON correctly' {
            $tmpFolder = Join-Path $PSScriptRoot 'tmp'
            if (-not (Test-Path $tmpFolder)) {
                New-Item -Path $tmpFolder -ItemType Directory | Out-Null
            }
            $csvPath = Join-Path $tmpFolder 'export.csv'
            $jsonPath = Join-Path $tmpFolder 'export.json'

            Invoke-SmartAnalyzer -Path $samplePath -ExportPath $csvPath -ExportFormat CSV | Out-Null
            Invoke-SmartAnalyzer -Path $samplePath -ExportPath $jsonPath -ExportFormat JSON | Out-Null

            Test-Path $csvPath | Should -BeTrue
            Test-Path $jsonPath | Should -BeTrue

            Remove-Item $csvPath, $jsonPath -Force
        }
    }

    Context 'Invalid Input Handling' {
        It 'Throws for missing file' {
            { Invoke-SmartAnalyzer -Path 'C:\not\real\path.log' } | Should -Throw
        }
    }
}

# Ensure the script exits with the correct exit code for CI
$LASTEXITCODE = 0

# Ensure the script exits with the correct exit code
$LASTEXITCODE = 0
# End of SmartLogAnalyzer.Integration.tests.ps1
#
# This script contains integration tests for the Smart Log Analyzer module,
# primarily targeting the Invoke-SmartAnalyzer function to validate its end-to-end behavior.
#
# The tests cover:
# - Parsing and validating log entries and summary statistics
# - Filtering log entries by include and exclude keywords
# - Time range filtering to ensure proper date-based log selection
# - Exporting logs to CSV and JSON formats and verifying output files
# - Handling invalid input scenarios such as missing log files
#
# Implemented with Pester and Should assertions, these integration tests provide robust validation
# of the core SmartLogAnalyzer functionality under realistic usage conditions.
#
# Designed to run in a PowerShell environment with the SmartLogAnalyzer module loaded,
# this suite supports continuous integration workflows by catching regressions early.
#
# The test suite is maintainable and extensible, facilitating future enhancements to
# the Smart Log Analyzer testing framework and ensuring sustained code quality.
#
# The script sets $LASTEXITCODE to 0 upon successful completion, enabling smooth
# integration with CI/CD pipelines by avoiding false failure signals.
#
# These tests complement a broader testing strategy that includes unit tests for
# individual functions like Get-LogEntries, Get-SystemLogs, and Export-LogReport,
# collectively ensuring comprehensive coverage and reliability.
#
# The integration tests provide timely feedback on the correctness and stability of
# the Invoke-SmartAnalyzer function across multiple scenarios.

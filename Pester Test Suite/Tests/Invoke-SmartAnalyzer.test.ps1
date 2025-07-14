# Requires -Module Pester
# File: Invoke-SmartAnalyzer.tests.ps1

$modulePath = Join-Path $PSScriptRoot "..\..\SmartLogAnalyzer.psm1"
Import-Module $modulePath -Force

Describe "Invoke-SmartAnalyzer" {

    BeforeAll {
        $script:mockLogEntries = @(
            [PSCustomObject]@{ TimeCreated = Get-Date; LevelDisplayName = "Information"; ProviderName = "App"; EventId = 1001; Message = "System started" },
            [PSCustomObject]@{ TimeCreated = Get-Date; LevelDisplayName = "Error"; ProviderName = "Kernel"; EventId = 9999; Message = "Kernel panic" }
        )

        $script:mockSummary = [PSCustomObject]@{
            TotalLines     = 2
            ErrorCount     = 1
            WarningCount   = 0
            InfoCount      = 1
            DebugCount     = 0
            FatalCount     = 0
            OtherCount     = 0
            FirstTimestamp = (Get-Date).AddMinutes(-1)
            LastTimestamp  = Get-Date
        }
    }

    Context "When FetchLogs is used" {
        Mock Get-SystemLogs { return $script:mockLogEntries }
        Mock Get-LogSummary { param ($LogLines) return $script:mockSummary }
        Mock Export-LogReport {}

        It "Fetches logs using Get-SystemLogs and summarizes" {
            $result = Invoke-SmartAnalyzer -FetchLogs -LogType System -ReportPath "C:\report.txt" -WhatIf
            $result.Entries | Should -HaveCount $script:mockLogEntries.Count
            $result.Summary.TotalLines | Should -Be $script:mockSummary.TotalLines
        }

        It "Calls Export-LogReport if ReportPath is specified" {
            $script:called = $false
            Mock Export-LogReport {
                $script:called = $true
            }

            Invoke-SmartAnalyzer -FetchLogs -LogType System -ReportPath "C:\report.txt" -Confirm:$false
            $script:called | Should -BeTrue
        }
    }

    Context "When reading logs from a CSV path" {
        Mock Test-Path { return $true }
        Mock Import-Csv { return $script:mockLogEntries }
        Mock Get-LogEntries { param ($Path) return $script:mockLogEntries }
        Mock Get-LogSummary { param ($LogLines) return $script:mockSummary }
        Mock Export-LogReport {}

        It "Processes logs from a valid path with filters" {
            $result = Invoke-SmartAnalyzer -Path "C:\logs.csv" -IncludeKeywords "panic" -AttentionOnly
            $result.Entries | Should -Contain { $_.Message -eq "Kernel panic" }
            $result.Summary.ErrorCount | Should -Be $script:mockSummary.ErrorCount
        }

        It "Throws an error if path does not exist" {
            Mock Test-Path { return $false }

            { Invoke-SmartAnalyzer -Path "C:\missing.csv" } | Should -Throw "File not found"
        }
    }

    Context "Report generation options" {
        Mock Get-SystemLogs { return $script:mockLogEntries }
        Mock Get-LogSummary { return $script:mockSummary }

        Mock Export-LogReport {
            param (
                $Summary,
                $Entries,
                $SourcePath,
                $OutputPath,
                $Format,
                $Redact,
                $IncludeMetadata,
                $GenerateRedactionLog
            )
            Set-Variable -Name ExportLogReportCalled -Value $true -Scope Global
            $Summary.TotalLines | Should -Be $script:mockSummary.TotalLines
            $Redact | Should -Be $true
            $IncludeMetadata | Should -Be $true
            $GenerateRedactionLog | Should -Be $true
        }

        It "Calls Export-LogReport with redaction and metadata flags" {
            Remove-Variable -Name ExportLogReportCalled -Scope Global -ErrorAction SilentlyContinue
            Invoke-SmartAnalyzer -FetchLogs -ReportPath "C:\final.txt" -RedactSensitiveData -IncludeMetadata -GenerateRedactionLog -Confirm:$false
            $Global:ExportLogReportCalled | Should -BeTrue
        }
    }

    Context "Error handling" {
        Mock Get-SystemLogs { throw "Simulated failure" }

        It "Catches and rethrows a user-friendly error message" {
            { Invoke-SmartAnalyzer -FetchLogs } | Should -Throw "❌ Smart Analyzer failed"
        }
    }
}

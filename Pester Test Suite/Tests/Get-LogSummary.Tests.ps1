# Requires -Module Pester
# File: Get-LogSummary.tests.ps1

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$modulePath = Join-Path $here "..\..\SmartLogAnalyzer.psm1"
Import-Module $modulePath -Force

Describe "Get-LogSummary" {

    Context "Basic log level counting" {
        $logLines = @(
            "2025-07-14 12:00:00 INFO System started",
            "2025-07-14 12:01:00 ERROR Disk failure",
            "2025-07-14 12:02:00 WARN Memory usage high",
            "2025-07-14 12:03:00 DEBUG Verbose mode enabled",
            "2025-07-14 12:04:00 FATAL Kernel panic",
            "2025-07-14 12:05:00 TRACE Unknown level",
            "",
            "   "
        )

        $result = $logLines | Get-LogSummary

        It "Counts total lines excluding blank" {
            $result.TotalLines | Should -Be 6
        }

        It "Counts INFO entries" {
            $result.InfoCount | Should -Be 1
        }

        It "Counts ERROR entries" {
            $result.ErrorCount | Should -Be 1
        }

        It "Counts WARN entries" {
            $result.WarningCount | Should -Be 1
        }

        It "Counts DEBUG entries" {
            $result.DebugCount | Should -Be 1
        }

        It "Counts FATAL entries" {
            $result.FatalCount | Should -Be 1
        }

        It "Counts unrecognized (Other) log levels" {
            $result.OtherCount | Should -Be 1
        }
    }

    Context "Timestamp detection and ordering" {
        $logLines = @(
            "2025-07-13 10:00:00 INFO Start",
            "2025-07-14 15:30:00 ERROR Failure",
            "Not a log line"
        )

        $result = $logLines | Get-LogSummary

        It "Extracts the first timestamp correctly" {
            $result.FirstTimestamp | Should -Be (Get-Date "2025-07-13 10:00:00")
        }

        It "Extracts the last timestamp correctly" {
            $result.LastTimestamp | Should -Be (Get-Date "2025-07-14 15:30:00")
        }
    }

    Context "Handles log lines without timestamps" {
        $logLines = @(
            "INFO No timestamp",
            "WARN Also no timestamp"
        )

        $result = $logLines | Get-LogSummary

        It "Returns null for FirstTimestamp" {
            $result.FirstTimestamp | Should -Be $null
        }

        It "Returns null for LastTimestamp" {
            $result.LastTimestamp | Should -Be $null
        }
    }

    Context "Handles multiple valid timestamp formats" {
        $logLines = @(
            "2025-07-14T12:00:00Z INFO UTC format",
            "2025-07-14T13:00:00.000Z ERROR Millisecond format",
            "Jul 14 2025 14:00:00 DEBUG Legacy format"
        )

        $result = $logLines | Get-LogSummary

        It "Detects all timestamps" {
            $result.TotalLines | Should -Be 3
            $result.FirstTimestamp | Should -Be (Get-Date "2025-07-14T12:00:00Z")
            $result.LastTimestamp  | Should -Be (Get-Date "2025-07-14 14:00:00")
        }
    }
}

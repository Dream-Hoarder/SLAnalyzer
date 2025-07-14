# Requires -Module Pester
# File: Get-SystemLogs.tests.ps1

$modulePath = Join-Path $PSScriptRoot "..\..\SmartLogAnalyzer.psm1"
Import-Module $modulePath -Force

Describe "Get-SystemLogs" {

    BeforeAll {
        function New-LogObject {
            param (
                [datetime]$Time = (Get-Date),
                [string]$Level = "Information",
                [string]$Provider = "TestProvider",
                [int]$EventId = 1000,
                [string]$Message = "Test log message"
            )
            [PSCustomObject]@{
                TimeCreated      = $Time
                LevelDisplayName = $Level
                ProviderName     = $Provider
                EventId          = $EventId
                Message          = $Message
            }
        }
    }

    Context "On Windows platform" {
        Mock -CommandName Get-WinEvent -MockWith {
            @(
                New-LogObject -Level "Information" -Message "Heartbeat OK",
                New-LogObject -Level "Error" -Message "Access denied",
                New-LogObject -Level "Warning" -Message "Disk space low"
            )
        }

        Mock -CommandName Get-EventLog -MockWith { @() }

        It "Returns logs with expected properties (WinEvent)" {
            # Adjust the mock here if you want to return only one log to match assertions
            Mock -CommandName Get-WinEvent -MockWith {
                @(
                    [pscustomobject]@{
                        TimeCreated      = [datetime]"2025-07-14T13:00:00"
                        LevelDisplayName = "Information"
                        ProviderName     = "EventProvider"
                        Id               = 1234
                        Message          = "All systems go"
                    }
                )
            }

            $logs = Get-SystemLogs -LogType System
            $logs | Should -HaveCount 1
            $logs[0].ProviderName | Should -Be "EventProvider"
            $logs[0].LevelDisplayName | Should -Be "Information"
            $logs[0].EventId | Should -Be 1234
        }

        It "Filters logs if AttentionOnly is specified" {
            Mock -CommandName Get-WinEvent -MockWith {
                @(
                    New-LogObject -Level "Information" -Message "Heartbeat OK",
                    New-LogObject -Level "Error" -Message "Access denied",
                    New-LogObject -Level "Warning" -Message "Disk space low"
                )
            }

            $logs = Get-SystemLogs -AttentionOnly -LogType System
            $logs | Should -HaveCount 2
            $logs.LevelDisplayName | Should -Contain "Error"
            $logs.LevelDisplayName | Should -Contain "Warning"
        }

        It "Exports logs if OutputPath is set" {
            $testFile = "$env:TEMP\test-logs.csv"
            Remove-Item $testFile -Force -ErrorAction SilentlyContinue

            Mock -CommandName Get-WinEvent -MockWith {
                @(New-LogObject -Message "Export me")
            }

            # Call function without assigning to variable since return is unused
            Get-SystemLogs -LogType System -OutputPath $testFile

            Test-Path $testFile | Should -BeTrue

            Remove-Item $testFile -Force
        }
    }

    Context "On Linux platform (simulated journalctl)" {
        Mock -CommandName bash -MockWith {
            @(
                '{"__REALTIME_TIMESTAMP": "1720972800000000", "PRIORITY": 3, "SYSLOG_IDENTIFIER": "sshd", "MESSAGE": "authentication failure"}'
            )
        }

        It "Parses journalctl output into log objects" {
            $logs = Get-SystemLogs -LogType System
            $logs | Should -HaveCount 1
            $logs[0].ProviderName | Should -Be "sshd"
            $logs[0].LevelDisplayName | Should -Be "Error"
            $logs[0].Message | Should -Match "authentication"
        }
    }

    Context "Unsupported platform" {
        It "Throws on unknown OS" {
            Mock -CommandName Get-WinEvent -MockWith { throw "Should not run" }
            Mock -CommandName bash -MockWith { throw "Should not run" }

            Mock -CommandName Get-Variable -ParameterFilter { $Name -eq 'PSVersionTable' } -MockWith {
                @{ OS = "AmigaOS" }
            }

            { Get-SystemLogs } | Should -Throw "Unsupported operating system"
        }
    }
}

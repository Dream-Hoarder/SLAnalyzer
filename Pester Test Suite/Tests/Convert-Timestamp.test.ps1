# Requires -Module Pester
# File: Convert-Timestamp.tests.ps1

# Adjust path as needed to your module
$modulePath = Join-Path $PSScriptRoot "..\..\SmartLogAnalyzer.psm1"
Import-Module $modulePath -Force

InModuleScope SmartLogAnalyzer {

    Describe "Convert-Timestamp" {

        Context "Standard ISO and Extended Formats" {
            It "Parses ISO8601 'o' format correctly" {
                $result = Convert-Timestamp -TimestampString "2025-07-14T13:45:30.0000000Z"
                $result | Should -BeOfType "datetime"
            }

            It "Parses 'yyyy-MM-dd HH:mm:ss' correctly" {
                $result = Convert-Timestamp -TimestampString "2025-07-14 13:45:30"
                $result | Should -BeOfType "datetime"
            }

            It "Parses 'yyyy-MM-ddTHH:mm:ssZ' format correctly" {
                $result = Convert-Timestamp -TimestampString "2025-07-14T13:45:30Z"
                $result.Kind | Should -Be "Local"
            }
        }

        Context "Culture-specific formats" {
            It "Parses US-style date MM/dd/yyyy" {
                $result = Convert-Timestamp -TimestampString "07/14/2025"
                $result | Should -BeOfType "datetime"
            }

            It "Parses UK-style date dd/MM/yyyy with Culture 'en-GB'" {
                $result = Convert-Timestamp -TimestampString "14/07/2025" -Culture (Get-Culture -Name 'en-GB')
                $result | Should -BeOfType "datetime"
            }
        }

        Context "Syslog-style formats (MMM dd HH:mm:ss)" {
            It "Parses 'Jul 14 13:45:30' using current year" {
                $result = Convert-Timestamp -TimestampString "Jul 14 13:45:30"
                $result.Year | Should -Be (Get-Date).Year
                $result.Hour | Should -Be 13
            }

            It "Parses single-digit days like 'Jul  3 04:01:02'" {
                $result = Convert-Timestamp -TimestampString "Jul  3 04:01:02"
                $result | Should -BeOfType "datetime"
            }
        }

        Context "Ambiguous or fallback formats" {
            It "Returns null for empty input" {
                $result = Convert-Timestamp -TimestampString ""
                $result | Should -Be $null
            }

            It "Returns null for whitespace-only input" {
                $result = Convert-Timestamp -TimestampString "   "
                $result | Should -Be $null
            }

            It "Returns null for unparseable string" {
                $result = Convert-Timestamp -TimestampString "not a timestamp"
                $result | Should -Be $null
            }
        }

        Context "Generic DateTime fallback" {
            It "Parses loosely formatted date if all others fail" {
                $result = Convert-Timestamp -TimestampString "Monday, July 14, 2025"
                $result | Should -BeOfType "datetime"
            }
        }

    }
}

# Requires -Module Pester
# File: Convert-Timestamp.tests.ps1

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$privateFunctionPath = Join-Path $here "..\..\Private\Convert-Timestamp.ps1"

# Dot-source the private function directly for testing
. $privateFunctionPath

Describe "Convert-Timestamp" {

    Context "Standard ISO and Extended Formats" {
        It "Parses ISO8601 'o' format correctly" {
            $testString = "2025-07-14T13:45:30.0000000Z"
            $result = Convert-Timestamp -TimestampString $testString
            $result | Should -Not -Be $null
            $result | Should -BeOfType "datetime"
        }

        It "Parses 'yyyy-MM-dd HH:mm:ss' correctly" {
            $testString = "2025-07-14 13:45:30"
            $result = Convert-Timestamp -TimestampString $testString
            $result | Should -Not -Be $null
            $result | Should -BeOfType "datetime"
        }

        It "Parses 'yyyy-MM-ddTHH:mm:ssZ' format correctly" {
            $testString = "2025-07-14T13:45:30Z"
            $result = Convert-Timestamp -TimestampString $testString
            $result | Should -Not -Be $null
            $result.Kind | Should -Be "Local"
        }
    }

    Context "Culture-specific formats" {
        It "Parses US-style date MM/dd/yyyy" {
            $testString = "07/14/2025"
            $result = Convert-Timestamp -TimestampString $testString
            $result | Should -Not -Be $null
            $result | Should -BeOfType "datetime"
        }

        It "Parses UK-style date dd/MM/yyyy with Culture 'en-GB'" {
            $testString = "14/07/2025"
            $culture = [System.Globalization.CultureInfo]::GetCultureInfo('en-GB')
            $result = Convert-Timestamp -TimestampString $testString -Culture $culture
            $result | Should -Not -Be $null
            $result | Should -BeOfType "datetime"
        }
    }

    Context "Syslog-style formats (MMM dd HH:mm:ss)" {
        It "Parses 'Jul 14 13:45:30' using current year" {
            $testString = "Jul 14 13:45:30"
            $result = Convert-Timestamp -TimestampString $testString
            $result | Should -Not -Be $null
            $result.Year | Should -Be (Get-Date).Year
            $result.Hour | Should -Be 13
        }

        It "Parses single-digit days like 'Jul  3 04:01:02'" {
            $testString = "Jul  3 04:01:02"
            $result = Convert-Timestamp -TimestampString $testString
            $result | Should -Not -Be $null
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
            $testString = "not a timestamp"
            $result = Convert-Timestamp -TimestampString $testString
            $result | Should -Be $null
        }
    }

    Context "Generic DateTime fallback" {
        It "Parses loosely formatted date if all others fail" {
            $testString = "Monday, July 14, 2025"
            $result = Convert-Timestamp -TimestampString $testString
            $result | Should -Not -Be $null
            $result | Should -BeOfType "datetime"
        }
    }

}

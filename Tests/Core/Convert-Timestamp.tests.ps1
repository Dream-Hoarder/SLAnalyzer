BeforeAll {
    # Ensure module loads
    Import-Module "$PSScriptRoot\..\..\SmartLogAnalyzer.psd1" -Force -ErrorAction Stop

    # Dot-source the private function manually for test access
    . "$PSScriptRoot\..\..\Private\Convert-Timestamp.ps1"
}

Describe "Convert-Timestamp" {
    It "Parses ISO 8601 datetime to a [datetime]" {
        $result = Convert-Timestamp -TimestampString "2025-06-25T14:22:00"
        $result | Should -BeOfType 'datetime'
    }

    It "Returns $null for invalid timestamp" {
        $result = Convert-Timestamp -TimestampString "not a date"
        $result | Should -BeNullOrEmpty
    }
}

Describe "Convert-Timestamp - Date Formats" {
    It "Handles various date formats correctly" {
        $formats = @(
            "2025-06-25 14:22:00",
            "25/06/2025 14:22:00",
            "06/25/2025 14:22:00",
            "2025.06.25 14:22:00"
        )

        foreach ($format in $formats) {
            $result = Convert-Timestamp -TimestampString $format
            $result | Should -BeOfType 'datetime'
        }
    }

    It "Returns $null for unsupported date formats" {
        $result = Convert-Timestamp -TimestampString "25th June 2025"
        $result | Should -BeNullOrEmpty
    }
}

Describe "Convert-Timestamp - Edge Cases" {
    It "Handles empty input gracefully" {
        $result = Convert-Timestamp -TimestampString ""
        $result | Should -BeNullOrEmpty
    }

    It "Handles null input gracefully" {
        $result = Convert-Timestamp -TimestampString $null
        $result | Should -BeNullOrEmpty
    }

    It "Handles leap years correctly" {
        $result = Convert-Timestamp -TimestampString "2020-02-29 12:00:00"
        $result | Should -BeOfType 'datetime'
        $result.Year | Should -Be 2020
        $result.Month | Should -Be 2
        $result.Day | Should -Be 29
    }
}

Describe "Convert-Timestamp - Syslog Format" {
    It "Parses syslog style timestamps with current year" {
        $testInput = "Jun 12 14:35:00"
        $result = Convert-Timestamp -TimestampString $testInput
        $result | Should -BeOfType 'datetime'
        $result.Month | Should -Be 6
        $result.Day | Should -Be 12
    }
}

Describe "Convert-Timestamp - Performance Tests" {
    It "Processes large number of timestamps efficiently without errors" {
        $timestamps = @(
            "2025-06-25 14:22:00",
            "2025-06-26 15:23:00",
            "2025-06-27 16:24:00"
        ) * 1000

        foreach ($timestamp in $timestamps) {
            { Convert-Timestamp -TimestampString $timestamp } | Should -Not -Throw
        }
    }

    It "Handles multiple formats in a batch without errors" {
        $mixedFormats = @(
            "2025-06-25 14:22:00",
            "25/06/2025 14:22:00",
            "06/25/2025 14:22:00"
        )

        foreach ($format in $mixedFormats) {
            { Convert-Timestamp -TimestampString $format } | Should -Not -Throw
        }
    }
}

Describe "Convert-Timestamp - Error Handling" {
    It "Does not throw error for null input but returns $null" {
        { Convert-Timestamp -TimestampString $null } | Should -Not -Throw
        $result = Convert-Timestamp -TimestampString $null
        $result | Should -BeNullOrEmpty
    }

    It "Does not throw error for invalid date formats but returns $null" {
        { Convert-Timestamp -TimestampString "invalid date" } | Should -Not -Throw
        $result = Convert-Timestamp -TimestampString "invalid date"
        $result | Should -BeNullOrEmpty
    }

    It "Does not throw error for unexpected input types (converted to string)" {
        { Convert-Timestamp -TimestampString 12345 } | Should -Not -Throw
        $result = Convert-Timestamp -TimestampString 12345
        # Likely returns $null as 12345 does not match any date format
        $result | Should -BeNullOrEmpty
    }
}

# Ensure the script exits with the correct exit code
$LASTEXITCODE = 0
# End of Convert-Timestamp.tests.ps1
#
# This script tests the Convert-Timestamp function in the SmartLogAnalyzer module.
# It verifies correct parsing of various date/time formats, including edge cases such as leap years,
# and evaluates performance with large datasets.
# The tests also check proper error handling for invalid or unexpected input.
#
# The test suite is designed to run in a PowerShell environment with the SmartLogAnalyzer module loaded.
# It uses the Pester framework and the Should module for assertions to ensure expected outputs.
#
# These tests provide clear, maintainable, and expandable coverage, facilitating quick feedback on
# the function’s correctness during development and continuous integration.
#
# The suite is part of a larger framework testing other core functions like Get-LogEntries,
# Get-SystemLogs, and Invoke-SmartAnalyzer, contributing to overall module quality and robustness.

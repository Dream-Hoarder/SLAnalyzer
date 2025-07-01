BeforeAll {
    # Ensure module loads
    Import-Module "$PSScriptRoot\..\..\SmartLogAnalyzer.psd1" -Force -ErrorAction Stop

    # Dot-source the private function manually for test access
    . "$PSScriptRoot\..\..\Private\Convert-Timestamp.ps1"
}

Describe "Convert-Timestamp - Parsing Tests" {
    It "Parses ISO 8601 datetime to a [datetime]" {
        $result = Convert-Timestamp -TimestampString "2025-06-25T14:22:00"
        $result | Should -BeOfType 'datetime'
    }

    It "Returns `$null for invalid timestamp" {
        Convert-Timestamp -TimestampString "not a date" | Should -BeNullOrEmpty
    }

    It "Handles syslog-style format like 'Jun 12 14:35:00'" {
        $timestamp = "Jun 12 14:35:00"
        $result = Convert-Timestamp -TimestampString $timestamp
        $result | Should -BeOfType 'datetime'
        $result.Month | Should -Be 6
        $result.Day   | Should -Be 12
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

    It "Returns `$null for unsupported date formats" {
        Convert-Timestamp -TimestampString "25th June 2025" | Should -BeNullOrEmpty
    }
}

Describe "Convert-Timestamp - Edge Cases" {
    It "Handles empty input gracefully" {
        Convert-Timestamp -TimestampString "" | Should -BeNullOrEmpty
    }

    It "Handles null input gracefully" {
        Convert-Timestamp -TimestampString $null | Should -BeNullOrEmpty
    }

    It "Handles leap years correctly" {
        $result = Convert-Timestamp -TimestampString "2020-02-29 12:00:00"
        $result | Should -BeOfType 'datetime'
        $result.Year  | Should -Be 2020
        $result.Month | Should -Be 2
        $result.Day   | Should -Be 29
    }
}

Describe "Convert-Timestamp - Performance Tests" {
    It "Processes large number of timestamps efficiently" {
        $timestamps = @(
            "2025-06-25 14:22:00",
            "2025-06-26 15:23:00",
            "2025-06-27 16:24:00"
        ) * 1000

        foreach ($timestamp in $timestamps) {
            { Convert-Timestamp -TimestampString $timestamp } | Should -Not -Throw
        }
    }

    It "Handles multiple formats in a batch" {
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
    It "Throws an error for unexpected input types" {
        { Convert-Timestamp -TimestampString 12345 } | Should -Throw
    }
}

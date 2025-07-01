BeforeAll {
    # Ensure module loads
    Import-Module "$PSScriptRoot\..\..\SmartLogAnalyzer.psd1" -Force -ErrorAction Stop

    # Dot-source the private function manually for test access
    . "$PSScriptRoot\..\..\Private\Format-LogEntry.ps1"
}

Describe "Format-LogEntry" {
    It "Extracts Level and Message from a log line" {
        $line = "2025-07-01 12:00:00 [ERROR] Service crashed"
        $entry = Format-LogEntry -Line $line
        $entry.Level | Should -Be "ERROR"
        $entry.Message | Should -Match "Service crashed"
    }
}

Describe "Format-LogEntry - Edge Cases" {
    It "Handles empty log lines gracefully" {
        $line = ""
        $entry = Format-LogEntry -Line $line
        $entry | Should -BeNullOrEmpty
    }

    It "Handles log lines without a timestamp" {
        $line = "[INFO] Service started"
        $entry = Format-LogEntry -Line $line
        $entry.Level | Should -Be "INFO"
        $entry.Message | Should -Match "Service started"
    }

    It "Handles log lines with unexpected formats" {
        $line = "Invalid log entry format"
        { Format-LogEntry -Line $line } | Should -Throw
    }
}

Describe "Format-LogEntry - Performance Tests" {
    It "Processes large log entries efficiently" {
        $largeMessage = "This is a large log entry " * 1000
        $line = "2025-07-01 12:00:00 [INFO] $largeMessage"
        { Format-LogEntry -Line $line } | Should -Not -Throw
    }

    It "Handles multiple entries in a batch" {
        $lines = @(
            "2025-07-01 12:00:00 [INFO] First entry",
            "2025-07-01 12:01:00 [ERROR] Second entry"
        )
        foreach ($line in $lines) {
            { Format-LogEntry -Line $line } | Should -Not -Throw
        }
    }
}

Describe "Format-LogEntry - Redaction Patterns" {
    It "Redacts sensitive information in log messages" {
        $line = "2025-07-01 12:00:00 [INFO] User admin with password 1234 logged in."
        $entry = Format-LogEntry -Line $line
        $entry.Message | Should -Not -Match "1234"
        $entry.Message | Should -Match "\[REDACTED\]"
    }

    It "Handles multiple sensitive fields in a message" {
        $line = "2025-07-01 12:00:00 [INFO] User admin with password 1234 and token abcdef."
        $entry = Format-LogEntry -Line $line
        $entry.Message | Should -Not -Match "1234"
        $entry.Message | Should -Not -Match "abcdef"
        $entry.Message | Should -Match "\[REDACTED\]"
    }
}

Describe "Format-LogEntry - Error Handling" {
    It "Throws an error for null or empty input" {
        { Format-LogEntry -Line $null } | Should -Throw
        { Format-LogEntry -Line "" } | Should -Throw
    }

    It "Handles unexpected log formats gracefully" {
        $line = "This is not a valid log entry"
        { Format-LogEntry -Line $line } | Should -Throw
    }
}

Describe "Format-LogEntry - Logging Levels" {
    It "Correctly identifies log levels" {
        $line = "2025-07-01 12:00:00 [DEBUG] Debugging information"
        $entry = Format-LogEntry -Line $line
        $entry.Level | Should -Be "DEBUG"

        $line = "2025-07-01 12:00:00 [WARN] Warning message"
        $entry = Format-LogEntry -Line $line
        $entry.Level | Should -Be "WARN"

        $line = "2025-07-01 12:00:00 [CRITICAL] Critical error occurred"
        $entry = Format-LogEntry -Line $line
        $entry.Level | Should -Be "CRITICAL"
    }
}

Describe "Format-LogEntry - Timestamp Handling" {
    It "Extracts and converts timestamps correctly" {
        $line = "2025-07-01 12:00:00 [INFO] Service started"
        $entry = Format-LogEntry -Line $line
        $entry.Timestamp | Should -BeOfType "System.DateTime"
        $entry.Timestamp.ToString("yyyy-MM-dd HH:mm:ss") | Should -Be "2025-07-01 12:00:00"
    }

    It "Handles log lines with different timestamp formats" {
        $line = "01/07/2025 12:00:00 [INFO] Service started"
        $entry = Format-LogEntry -Line $line
        $entry.Timestamp | Should -BeOfType "System.DateTime"
    }
}

Describe "Format-LogEntry - Localization Support" {
    It "Handles localized timestamps correctly" {
        $line = "01.07.2025 12:00:00 [INFO] Service started"
        $entry = Format-LogEntry -Line $line
        $entry.Timestamp | Should -BeOfType "System.DateTime"
        $entry.Timestamp.ToString("dd.MM.yyyy HH:mm:ss") | Should -Be "01.07.2025 12:00:00"
    }

    It "Supports different date formats in log entries" {
        $line = "2025/07/01 12:00:00 [INFO] Service started"
        $entry = Format-LogEntry -Line $line
        $entry.Timestamp | Should -BeOfType "System.DateTime"
    }
}

Describe "Format-LogEntry - Custom Log Formats" {
    It "Handles custom log formats with additional fields" {
        $line = "2025-07-01 12:00:00 [INFO] User admin logged in from IP 192.168.1.1"
        $entry = Format-LogEntry -Line $line
        $entry.Level | Should -Be "INFO"
        $entry.Message | Should -Match "User admin logged in from IP"
    }
}
# End of Format-LogEntry.tests.ps1
#
# This script tests the Format-LogEntry function of the SmartLogAnalyzer module.
# It verifies the function’s ability to parse log lines and extract key elements such as
# Level, Message, and Timestamp accurately.
#
# The tests cover a variety of scenarios including:
# - Standard log lines with timestamp, level, and message
# - Edge cases like empty lines, missing timestamps, and malformed entries
# - Performance with large log entries and batch processing
# - Redaction of sensitive information within log messages
# - Robust error handling for null, empty, or unexpected input formats
# - Recognition of multiple log levels and localized timestamp formats
# - Support for custom log formats with additional fields
#
# Implemented using the Pester testing framework and the Should assertion module,
# the tests provide clear and immediate feedback on function correctness and resilience.
#
# Designed to be run in a PowerShell environment with the SmartLogAnalyzer module loaded,
# this suite complements other tests such as Get-LogEntries, Get-SystemLogs, and Invoke-SmartAnalyzer,
# contributing to overall code quality and reliability.
#
# The suite supports continuous integration workflows to detect regressions promptly
# and is structured for maintainability and future expansion as the module evolves.
# The tests are written to be clear and descriptive, allowing for easy identification of issues
# and ensuring that the Format-LogEntry function behaves as expected across various scenarios.
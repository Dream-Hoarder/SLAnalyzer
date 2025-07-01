BeforeAll {
    # Ensure module loads
    Import-Module "$PSScriptRoot\..\..\SmartLogAnalyzer.psd1" -Force -ErrorAction Stop

    # Dot-source the private function manually for test access
    . "$PSScriptRoot\..\..\Private\Protect-LogEntry.ps1"
}

Describe "Protect-LogEntry" {
    It "Redacts sensitive content like passwords" {
        $entry = @{ Message = "User admin with password 1234" }
        $protected = Protect-LogEntry -Entry $entry
        $protected.Message | Should -Not -Match "1234"
        $protected.Message | Should -Match "\[REDACTED\]"
    }
}
Describe "Protect-LogEntry - Redaction Tests" {
    It "Redacts multiple sensitive fields" {
        $entry = @{ Message = "User admin with password 1234 and token abcdef" }
        $protected = Protect-LogEntry -Entry $entry
        $protected.Message | Should -Not -Match "1234"
        $protected.Message | Should -Not -Match "abcdef"
        $protected.Message | Should -Match "\[REDACTED\]"
    }

    It "Handles entries without sensitive content gracefully" {
        $entry = @{ Message = "No sensitive data here." }
        $protected = Protect-LogEntry -Entry $entry
        $protected.Message | Should -Be "No sensitive data here."
    }
}
Describe "Protect-LogEntry - Edge Cases" {
    It "Handles null or empty entries" {
        { Protect-LogEntry -Entry $null } | Should -Throw
        { Protect-LogEntry -Entry @{} } | Should -Not -Throw
    }

    It "Redacts sensitive content in complex messages" {
        $entry = @{ Message = "User admin logged in with password 1234 at 2023-10-01 12:00:00" }
        $protected = Protect-LogEntry -Entry $entry
        $protected.Message | Should -Not -Match "1234"
        $protected.Message | Should -Match "\[REDACTED\]"
    }
}
Describe "Protect-LogEntry - Performance Tests" {
    It "Processes large entries efficiently" {
        $largeMessage = "User admin with password 1234 " * 1000
        $entry = @{ Message = $largeMessage }
        { Protect-LogEntry -Entry $entry } | Should -Not -Throw
    }

    It "Handles multiple entries in a batch" {
        $entries = @(
            @{ Message = "User admin with password 1234" },
            @{ Message = "User guest with token abcdef" }
        )
        foreach ($entry in $entries) {
            { Protect-LogEntry -Entry $entry } | Should -Not -Throw
        }
    }
}
Describe "Protect-LogEntry - Redaction Patterns" {
    It "Redacts passwords in various formats" {
        $entry = @{ Message = "User admin with password 1234 and token xyz" }
        $protected = Protect-LogEntry -Entry $entry
        $protected.Message | Should -Not -Match "1234"
        $protected.Message | Should -Match "\[REDACTED\]"
    }

    It "Redacts tokens in different formats" {
        $entry = @{ Message = "User admin with token abcdef123456" }
        $protected = Protect-LogEntry -Entry $entry
        $protected.Message | Should -Not -Match "abcdef123456"
        $protected.Message | Should -Match "\[REDACTED\]"
    }
}
Describe "Protect-LogEntry - Custom Redaction Patterns" {
    It "Allows custom patterns for redaction" {
        $entry = @{ Message = "User admin with credit card 1234-5678-9012-3456" }
        $protected = Protect-LogEntry -Entry $entry -CustomPatterns @("credit card \d{4}-\d{4}-\d{4}-\d{4}")
        $protected.Message | Should -Not -Match "1234-5678-9012-3456"
        $protected.Message | Should -Match "\[REDACTED\]"
    }
}
# End of Protect-LogEntry.tests.ps1
#
# This script tests the Protect-LogEntry function in the SmartLogAnalyzer module.
# It validates the function's ability to redact sensitive information within log entries,
# ensuring sensitive data like passwords, tokens, and custom patterns are replaced safely.
#
# The tests cover scenarios such as:
# - Redacting single and multiple sensitive fields in log messages
# - Handling entries without sensitive content gracefully
# - Managing edge cases including null or empty entries and complex message formats
# - Performance with large messages and batch processing of multiple entries
# - Supporting custom redaction patterns for user-defined sensitive data
#
# Using the Pester framework with Should assertions, the tests verify that the redaction
# properly replaces sensitive content with placeholder tokens like [REDACTED].
#
# Designed to be run in a PowerShell environment with the SmartLogAnalyzer module loaded,
# this suite is part of a larger test framework to maintain code quality and reliability.
#
# The tests support continuous integration by detecting regressions and ensure
# maintainability and extensibility as the Protect-LogEntry function evolves.



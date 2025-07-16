# Pester Test Suite for Get-LogEntries

$modulePath = (Resolve-Path "$PSScriptRoot\..\..\SmartLogAnalyzer.psm1").Path
Import-Module $modulePath -Force -ErrorAction Stop

Describe "Get-LogEntries" {

    $sampleLogPath = Join-Path (Split-Path $PSScriptRoot -Parent) "SampleLogs\sample.log"
    BeforeAll {
        # Sample log creation for test purposes
        if (-not (Test-Path $sampleLogPath)) {
            @'
2025-07-12 12:00:00 [INFO] Service started successfully.
2025-07-12 12:01:00 [ERROR] Failed to connect to database.
2025-07-12 12:02:00 [WARN] Low disk space.
2025-07-12 12:03:00 [INFO] Scheduled job executed.
'@ | Set-Content -Path $sampleLogPath -Encoding UTF8
        }
    }

    It "returns log entries with expected properties" {
        $entries = Get-LogEntries -Path $sampleLogPath -SortOrder Forward
        $entries.Count | Should -BeGreaterThan 0
        $entries[0] | Should -HaveProperty 'Timestamp'
        $entries[0] | Should -HaveProperty 'Level'
        $entries[0] | Should -HaveProperty 'Message'
    }

    It "filters ERROR entries correctly" {
        $entries = Get-LogEntries -Path $sampleLogPath -IncludeKeywords 'ERROR'
        $entries.Count | Should -Be 1
        $entries[0].Level | Should -Be 'ERROR'
    }

    It "excludes WARN entries correctly" {
        $entries = Get-LogEntries -Path $sampleLogPath -ExcludeKeywords 'WARN'
        $entries | Where-Object { $_.Level -eq 'WARN' } | Should -BeNullOrEmpty
    }

    It "returns only last N entries when Tail is used" {
        $entries = Get-LogEntries -Path $sampleLogPath -Tail 2 -SortOrder Forward
        $entries.Count | Should -Be 2
        $entries[0].Timestamp | Should -BeLessThan $entries[1].Timestamp
    }

    It "returns only first N entries when LineLimit is used" {
        $entries = Get-LogEntries -Path $sampleLogPath -LineLimit 2 -SortOrder Forward
        $entries.Count | Should -Be 2
    }

    It "respects the -Ascending switch" {
        $entries = Get-LogEntries -Path $sampleLogPath -Ascending
        $entries.Count | Should -BeGreaterThan 0
        $entries[0].Timestamp | Should -BeLessThan $entries[-1].Timestamp
    }

    It "sorts in reverse order when SortOrder is 'Reverse'" {
        $entries = Get-LogEntries -Path $sampleLogPath -SortOrder Reverse
        $entries.Count | Should -BeGreaterThan 0
        $entries[0].Timestamp | Should -BeGreaterThan $entries[-1].Timestamp
    }
}

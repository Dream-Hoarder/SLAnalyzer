# Pester test for Get-LogEntries

Describe "Get-LogEntries" {
    It "returns log entries with expected properties" {
        $result = Get-LogEntries -Path "C:\Users\WilliBonneJr\OneDrive\Desktop\PowershellProjects\Project.Modules\SmartLogAnalyzer\Pester Test Suite\Sample Logs\Sample.log"
        $result | Should -Not -BeNullOrEmpty
        $result[0] | Should -HaveProperty 'Timestamp'
        $result[0] | Should -HaveProperty 'Level'
        $result[0] | Should -HaveProperty 'Message'
    }

    It "filters ERROR entries correctly" {
        $result = Get-LogEntries -Path "C:\Users\WilliBonneJr\OneDrive\Desktop\PowershellProjects\Project.Modules\SmartLogAnalyzer\Pester Test Suite\Sample Logs\Sample.log" | Where-Object { $_.Level -eq "ERROR" }
        $result | Should -Not -BeNullOrEmpty
        $result | ForEach-Object { $_.Level | Should -Be "ERROR" }
    }
}
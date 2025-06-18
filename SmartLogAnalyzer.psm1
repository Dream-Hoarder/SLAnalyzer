# Private function files
. $PSScriptRoot\Private\Analyzers.Helper.ps1
. $PSScriptRoot\Private\Convert-Timestamp.ps1
. $PSScriptRoot\Private\Format-LogEntry.ps1

# Public function files
. $PSScriptRoot\Public\Get-LogEntries.ps1
. $PSScriptRoot\Public\Get-LogSummary.ps1
. $PSScriptRoot\Public\Invoke-SmartAnalyzer.ps1

# Conditionally load UI only on Windows
if ($IsWindows) {
    . $PSScriptRoot\Public\Show-LogAnalyzerUI.ps1
}

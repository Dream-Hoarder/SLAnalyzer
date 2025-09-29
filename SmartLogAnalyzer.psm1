# SmartLogAnalyzer.psm1

# --- Private function files ---
. "$PSScriptRoot\Private\Analyzers.Helper.ps1"
. "$PSScriptRoot\Private\Convert-Timestamp.ps1"
. "$PSScriptRoot\Private\Format-LogEntry.ps1"
. "$PSScriptRoot\Private\Export-LogReport.ps1"
. "$PSScriptRoot\Private\Protect-LogEntry.ps1"
. "$PSScriptRoot\Private\Get-HtmlTemplate.ps1"
. "$PSScriptRoot\Private\Format-HtmlString.ps1"

# --- Public function files ---
. "$PSScriptRoot\Public\Get-LogEntries.ps1"
. "$PSScriptRoot\Public\Get-LogSummary.ps1"
. "$PSScriptRoot\Public\Invoke-SmartAnalyzer.ps1"
. "$PSScriptRoot\Public\Get-SystemLogs.ps1"
. "$PSScriptRoot\Public\Convert-Timestamp.ps1"

# --- Conditionally load Windows UI ---
# Compatible with both PowerShell 5.1 and 7+
$isWindowsOS = if ($PSVersionTable.PSVersion.Major -ge 6) {
    $IsWindows
} else {
    $env:OS -eq 'Windows_NT'
}

if ($isWindowsOS) {
    . "$PSScriptRoot\Public\Show-LogAnalyzerUI.ps1"
}

# --- Exported functions ---
$exportedFunctions = @(
    'Get-LogEntries',
    'Get-LogSummary',
    'Invoke-SmartAnalyzer',
    'Get-SystemLogs',
    'Convert-Timestamp'
)

# Export Show-LogAnalyzerUI only on Windows
if ($isWindowsOS) {
    $exportedFunctions += 'Show-LogAnalyzerUI'
}

Export-ModuleMember -Function $exportedFunctions

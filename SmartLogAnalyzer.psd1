@{
    RootModule        = 'SmartLogAnalyzer.psm1'
    ModuleVersion     = '1.2.0'
    GUID              = '9f0f09d3-b15c-4a9c-b01d-3d19d06e6f21'
    Author            = 'Willie Bonner'
    CompanyName       = 'Independent'
    Description       = 'SmartLogAnalyzer helps sysadmins and developers parse and analyze logs intelligently across platforms with optional GUI.'
    PowerShellVersion = '7.0'
    CompatiblePSEditions = @('Core', 'Desktop')

    FunctionsToExport = @(
        'Get-LogEntries',
        'Get-LogSummary',
        'Invoke-SmartAnalyzer',
        'Get-SystemLogs',
        'Show-LogAnalyzerUI' # Loaded conditionally on Windows, but safe to export
    )

    FileList = @(
        'SmartLogAnalyzer.psm1',
        'Public\Get-LogEntries.ps1',
        'Public\Get-LogSummary.ps1',
        'Public\Invoke-SmartAnalyzer.ps1',
        'Public\Show-LogAnalyzerUI.ps1',
        'Public\Get-SystemLogs.ps1',
        'Private\Analyzers.Helper.ps1',
        'Private\Protect-LogEntry.ps1',
        'Private\Convert-Timestamp.ps1',
        'Private\Format-LogEntry.ps1',
        'Private\Export-LogReport.ps1',
        'Private\Get-HtmlTemplate.ps1',
        'Private\Format-HtmlString.ps1',
        'GUI\Assets\Slanalyzer.ico',
        'GUI\Assets\banner.png',
        'GUI\Assets\theme.config',
        'config.json'
    )

    PrivateData = @{
        PSData = @{
            Tags = @(
                'logs', 'parser', 'analyzer', 'monitoring',
                'cross-platform', 'PowerShell', 'ETL', 'journalctl',
                'GUI', 'colorize', 'attention', 'cybersecurity'
            )
            ProjectUri   = 'https://github.com/williebonnerjr/SLAnalyzer'
            LicenseUri   = 'https://opensource.org/licenses/MIT'
            IconUri      = 'https://raw.githubusercontent.com/williebonnerjr/SLAnalyzer/main/GUI/Assets/slanalyzer.ico'
            ReleaseNotes = @'
v1.1.0 - Major feature release:
- Added FetchLogs capability with LogType support (e.g., System)
- Introduced AttentionOnly flag to highlight critical logs
- Added Colorize for visual log emphasis
- Linux support now includes journalctl fallback
- RedactSensitiveData and metadata options for cybersecurity
- Extended Pester test suite with full coverage
'@
        }
    }
}

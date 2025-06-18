@{
    RootModule        = 'SmartLogAnalyzer.psm1'
    ModuleVersion     = '1.0.0'
    GUID              = '9f0f09d3-b15c-4a9c-b01d-3d19d06e6f21'
    Author            = 'Willie Bonner'
    CompanyName       = 'Independent'
    Description       = 'SmartLogAnalyzer helps sysadmins and developers parse and analyze logs intelligently.'
    PowerShellVersion = '7.0'
    CompatiblePSEditions = @('Core', 'Desktop')

    FunctionsToExport = @(
        'Get-LogEntries',
        'Get-LogSummary',
        'Invoke-SmartAnalyzer',
        'Show-LogAnalyzerUI'
    )

    FileList = @(
        'SmartLogAnalyzer.psm1',
        'Public\Get-LogEntries.ps1',
        'Public\Get-LogSummary.ps1',
        'Public\Invoke-SmartAnalyzer.ps1',
        'Public\Show-LogAnalyzerUI.ps1',
        'Private\Analyzers.Helpers.ps1',
        'Private\Convert-Timestamp.ps1',
        'Private\Format-LogEntry.ps1',
        'GUI\Assets\Slanalyzer.ico',
        'GUI\Assets\banner.png',
        'GUI\Assets\theme.config',
        'config.json'
    )

    PrivateData = @{
        PSData = @{
            Tags         = @('logs', 'parser', 'analyzer', 'monitoring', 'cross-platform', 'PowerShell')
            ProjectUri   = 'https://github.com/williebonnerjr/SLAnalyzer'
            LicenseUri   = 'https://opensource.org/licenses/MIT'
            ReleaseNotes = 'Initial release with Windows/Linux support, UI (Windows only), and export options.'
        }
    }
}

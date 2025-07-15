function Invoke-SmartAnalyzer {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [string]$Path,

        [switch]$FetchLogs,
        [ValidateSet("System", "Application", "Security", "All", "Custom")]
        [string]$LogType = "System",

        [datetime]$StartTime = (Get-Date).AddHours(-1),
        [datetime]$EndTime   = (Get-Date),

        [string]$CustomPath,

        [string[]]$IncludeKeywords = @(),
        [string[]]$ExcludeKeywords = @(),
        [ValidateSet("Forward", "Reverse")]
        [string]$SortOrder = "Forward",
        [int[]]$EventId,
        [string[]]$Level,
        [string[]]$ProviderName,

        [switch]$AttentionOnly,
        [switch]$Colorize,

        [string]$ExportPath,
        [ValidateSet("CSV", "JSON")]
        [string]$ExportFormat = "CSV",

        [string]$ReportPath,
        [ValidateSet("Text", "Json", "Csv", "Html")]
        [string]$ReportFormat = "Text",

        [switch]$RedactSensitiveData,
        [switch]$GenerateRedactionLog,
        [switch]$IncludeMetadata
    )

    try {
        $logEntries = @()
        $sourcePath = $Path

        if ($FetchLogs) {
            Write-Verbose "📥 Fetching logs via Get-SystemLogs..."

            $logParams = @{
                LogType        = $LogType
                StartTime      = $StartTime
                EndTime        = $EndTime
                AttentionOnly  = $AttentionOnly
                Colorize       = $Colorize
            }

            if ($CustomPath)  { $logParams.CustomPath = $CustomPath }
            if ($ExportPath)  { $logParams.OutputPath = $ExportPath }

            $logEntries = Get-SystemLogs @logParams
            $sourcePath = $ExportPath
        }
        else {
            if (-not (Test-Path $Path)) {
                throw "❌ File not found: $Path"
            }

            Write-Verbose "📂 Importing log entries from: $Path"
            $logEntries = Import-Csv -Path $Path -ErrorAction Stop
        }

        # Apply extra filtering if raw log source was loaded
        if (-not $FetchLogs) {
            Write-Verbose "🔍 Applying filters via Get-LogEntries..."

            $filterParams = @{
                Path           = $Path
                IncludeKeywords = $IncludeKeywords
                ExcludeKeywords = $ExcludeKeywords
                StartTime       = $StartTime
                EndTime         = $EndTime
                SortOrder       = $SortOrder
                EventId         = $EventId
                Level           = $Level
                ProviderName    = $ProviderName
                Redact          = $RedactSensitiveData
                ExportPath      = $ExportPath
                ExportFormat    = $ExportFormat
                Colorize        = $Colorize
            }

            $logEntries = Get-LogEntries @filterParams
        }

        Write-Verbose "📊 Generating summary..."
        $summary = Get-LogSummary -LogLines $logEntries

        if ($ReportPath -and $PSCmdlet.ShouldProcess($ReportPath, "Export Smart Analyzer Report")) {
            Write-Verbose "📝 Exporting report to $ReportPath..."

            Export-LogReport -Summary $summary `
                             -Entries $logEntries `
                             -SourcePath $sourcePath `
                             -OutputPath $ReportPath `
                             -Format $ReportFormat `
                             -Redact:$RedactSensitiveData `
                             -IncludeMetadata:$IncludeMetadata `
                             -GenerateRedactionLog:$GenerateRedactionLog

            Write-Host "✅ Report saved to $ReportPath" -ForegroundColor Green
        }

        return [pscustomobject]@{
            Entries = $logEntries
            Summary = $summary
        }
    }
    catch {
        Write-Error $_.Exception.Message
        throw "❌ Smart Analyzer failed. See error details above."
    }
}

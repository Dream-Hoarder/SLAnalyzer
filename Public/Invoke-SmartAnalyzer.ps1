function Invoke-SmartAnalyzer {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [string]$Path,

        [switch]$FetchLogs,
        [ValidateSet("System", "Application", "Security", "All", "Custom")]
        [string]$LogType = "System",

        [datetime]$StartTime = (Get-Date).AddHours(-1),
        [datetime]$EndTime = (Get-Date),

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
        if ($FetchLogs) {
            Write-Verbose "Fetching logs using Get-SystemLogs..."

            $logParams = @{
                LogType        = $LogType
                StartTime      = $StartTime
                EndTime        = $EndTime
                AttentionOnly  = $AttentionOnly
                Colorize       = $Colorize
            }

            if ($CustomPath) {
                $logParams['CustomPath'] = $CustomPath
            }

            if ($ExportPath) {
                $logParams['OutputPath'] = $ExportPath
            }

            $logEntries = Get-SystemLogs @logParams
            $Path = $ExportPath  # Fallback path for export/report generation
        } else {
            if (-not (Test-Path $Path)) {
                throw "File not found: $Path"
            }

            Write-Verbose "Reading logs from path: $Path"
            $logEntries = Import-Csv $Path
        }

        # Apply filters for Get-LogEntries if not already processed
        $params = @{ Path = $Path }
        if ($IncludeKeywords)    { $params.IncludeKeywords = $IncludeKeywords }
        if ($ExcludeKeywords)    { $params.ExcludeKeywords = $ExcludeKeywords }
        if ($StartTime)          { $params.StartTime = $StartTime }
        if ($EndTime)            { $params.EndTime = $EndTime }
        if ($SortOrder)          { $params.SortOrder = $SortOrder }
        if ($EventId)            { $params.EventId = $EventId }
        if ($Level)              { $params.Level = $Level }
        if ($ProviderName)       { $params.ProviderName = $ProviderName }
        if ($ExportPath)         { $params.ExportPath = $ExportPath }
        if ($ExportFormat)       { $params.ExportFormat = $ExportFormat }

        if (-not $FetchLogs) {
            $logEntries = Get-LogEntries @params
        }

        $summary = Get-LogSummary -LogLines $logEntries

        # Conditionally export report
        if ($ReportPath -and $PSCmdlet.ShouldProcess($ReportPath, "Export SmartLogAnalyzer Report")) {
            Export-LogReport -Summary $summary `
                             -Entries $logEntries `
                             -SourcePath $Path `
                             -OutputPath $ReportPath `
                             -Format $ReportFormat `
                             -Redact:$RedactSensitiveData `
                             -IncludeMetadata:$IncludeMetadata `
                             -GenerateRedactionLog:$GenerateRedactionLog
            Write-Information "📄 Report exported to: $ReportPath"
        }

        return [pscustomobject]@{
            Entries = $logEntries
            Summary = $summary
        }
    } catch {
        Write-Error $_.Exception.Message
        throw "❌ Smart Analyzer failed. See error details above."
    }
}

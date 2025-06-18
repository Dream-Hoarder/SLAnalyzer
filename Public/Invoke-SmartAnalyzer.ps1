function Invoke-SmartAnalyzer {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$Path,

        [string[]]$IncludeKeywords = @(),
        [string[]]$ExcludeKeywords = @(),
        [datetime]$StartTime,
        [datetime]$EndTime,

        [ValidateSet("Forward", "Reverse")]
        [string]$SortOrder = "Forward",

        [int[]]$EventId,
        [string[]]$Level,
        [string[]]$ProviderName,

        [string]$ExportPath,
        [ValidateSet("CSV", "JSON")]
        [string]$ExportFormat = "CSV"
    )

    try {
        $params = @{
            Path            = $Path
            IncludeKeywords = $IncludeKeywords
            ExcludeKeywords = $ExcludeKeywords
            SortOrder       = $SortOrder
            EventId         = $EventId
            Level           = $Level
            ProviderName    = $ProviderName
            ExportPath      = $ExportPath
            ExportFormat    = $ExportFormat
        }

        if ($StartTime) { $params.StartTime = $StartTime }
        if ($EndTime)   { $params.EndTime   = $EndTime }

        $logEntries = Get-LogEntries @params
        $summary = Get-LogSummary -LogLines $logEntries

        return [pscustomobject]@{
            Entries = $logEntries
            Summary = $summary
        }
    } catch {
        Write-Error $_.Exception.Message
        throw "❌ Smart Analyzer failed. See error details above."
    }
}

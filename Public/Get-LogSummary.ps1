function Get-LogSummary {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string[]]$LogLines
    )

    $summary = [ordered]@{
        TotalLines     = 0
        ErrorCount     = 0
        WarningCount   = 0
        InfoCount      = 0
        DebugCount     = 0
        FatalCount     = 0
        OtherCount     = 0
        FirstTimestamp = $null
        LastTimestamp  = $null
    }

    if (-not $LogLines) {
        return [pscustomobject]$summary
    }

    $timestamps = @()
    $datetimeFormats = @(
        'yyyy-MM-dd HH:mm:ss',
        'yyyy-MM-ddTHH:mm:ss',
        'yyyy-MM-ddTHH:mm:ssZ',
        'yyyy-MM-ddTHH:mm:ss.fffZ',
        'yyyy-MM-ddTHH:mm:sszzz',
        'MMM dd yyyy HH:mm:ss'
    )

    foreach ($line in $LogLines) {
        $summary.TotalLines++

        switch -Regex ($line) {
            'fatal' { $summary.FatalCount++ }
            'error' { $summary.ErrorCount++ }
            'warn'  { $summary.WarningCount++ }
            'info'  { $summary.InfoCount++ }
            'debug' { $summary.DebugCount++ }
            default { $summary.OtherCount++ }
        }

        if ($line -match '(\d{4}-\d{2}-\d{2}[ T]\d{2}:\d{2}:\d{2}(?:[\.,]\d+)?(?:Z|[\+\-]\d{2}:\d{2})?)') {
            $timestampCandidate = $matches[1]
            foreach ($fmt in $datetimeFormats) {
                try {
                    $parsed = [datetime]::ParseExact($timestampCandidate, $fmt, $null)
                    $timestamps += $parsed
                    break
                } catch {
                    # Continue trying formats
                }
            }
        }
    }

    if ($timestamps.Count -gt 0) {
        $sorted = $timestamps | Sort-Object
        $summary.FirstTimestamp = $sorted[0]
        $summary.LastTimestamp  = $sorted[-1]
    }

    return [pscustomobject]$summary
}

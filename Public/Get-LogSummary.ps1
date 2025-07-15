function Get-LogSummary {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string[]]$LogLines
    )

    begin {
        $summary = @{
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

        $datetimeFormats = @(
            'yyyy-MM-dd HH:mm:ss',
            'yyyy-MM-ddTHH:mm:ss',
            'yyyy-MM-ddTHH:mm:ssZ',
            'yyyy-MM-ddTHH:mm:ss.fffZ',
            'yyyy-MM-ddTHH:mm:sszzz',
            'MMM dd yyyy HH:mm:ss'
        )
    }

    process {
        foreach ($line in $LogLines) {
            if ([string]::IsNullOrWhiteSpace($line)) { continue }

            $summary.TotalLines++
            $lcLine = $line.ToLowerInvariant()

            if ($lcLine -match 'fatal') {
                $summary.FatalCount++
            } elseif ($lcLine -match 'error') {
                $summary.ErrorCount++
            } elseif ($lcLine -match 'warn') {
                $summary.WarningCount++
            } elseif ($lcLine -match 'info') {
                $summary.InfoCount++
            } elseif ($lcLine -match 'debug') {
                $summary.DebugCount++
            } else {
                $summary.OtherCount++
            }

            if ($line -match '(\d{4}-\d{2}-\d{2}[ T]\d{2}:\d{2}:\d{2}(?:[\.,]\d+)?(?:Z|[\+\-]\d{2}:\d{2})?)') {
                $timestampCandidate = $matches[1]

                foreach ($fmt in $datetimeFormats) {
                    try {
                        $parsed = [datetime]::ParseExact($timestampCandidate, $fmt, $null)
                        if (-not $summary.FirstTimestamp -or $parsed -lt $summary.FirstTimestamp) {
                            $summary.FirstTimestamp = $parsed
                        }
                        if (-not $summary.LastTimestamp -or $parsed -gt $summary.LastTimestamp) {
                            $summary.LastTimestamp = $parsed
                        }
                        break
                    } catch {
                        continue
                    }
                }
            }
        }
    }

    end {
        return [pscustomobject]$summary
    }
}

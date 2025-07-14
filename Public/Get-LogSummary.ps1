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
        }

        $timestamps = New-Object System.Collections.Generic.List[datetime]

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

            $matched = $false

            switch -Regex ($line.ToLower()) {
                'fatal'  { $summary.FatalCount++;  $matched = $true; break }
                'error'  { $summary.ErrorCount++;  $matched = $true; break }
                'warn'   { $summary.WarningCount++;$matched = $true; break }
                'info'   { $summary.InfoCount++;   $matched = $true; break }
                'debug'  { $summary.DebugCount++;  $matched = $true; break }
            }

            if (-not $matched) {
                $summary.OtherCount++
            }

            # Try to extract and parse a timestamp from the line
            if ($line -match '(\d{4}-\d{2}-\d{2}[ T]\d{2}:\d{2}:\d{2}(?:[\.,]\d+)?(?:Z|[\+\-]\d{2}:\d{2})?)') {
                $timestampCandidate = $matches[1]
                foreach ($fmt in $datetimeFormats) {
                    try {
                        $parsed = [datetime]::ParseExact($timestampCandidate, $fmt, $null)
                        $timestamps.Add($parsed)
                        break
                    } catch {
                        # Try next format
                    }
                }
            }
        }
    }

    end {
        $summary.FirstTimestamp = if ($timestamps.Count -gt 0) { $timestamps | Sort-Object | Select-Object -First 1 } else { $null }
        $summary.LastTimestamp  = if ($timestamps.Count -gt 0) { $timestamps | Sort-Object | Select-Object -Last 1 } else { $null }

        return [pscustomobject]$summary
    }
}

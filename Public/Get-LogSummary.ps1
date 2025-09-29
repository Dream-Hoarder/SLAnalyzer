function Get-LogSummary {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [AllowEmptyCollection()]
        [System.Object[]]$LogLines
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

        # Convert-Timestamp function handles all datetime format parsing
    }

    process {
        foreach ($entry in $LogLines) {
            # Handle both string lines and PSCustomObjects from Get-SystemLogs
            if ($entry -is [PSCustomObject] -and $entry.PSObject.Properties['LevelDisplayName']) {
                # This is a log entry object from Get-SystemLogs
                $summary.TotalLines++
                $level = $entry.LevelDisplayName
                
                # Count by level
                switch -Regex ($level) {
                    '(?i)fatal|emergency|panic'     { $summary.FatalCount++ }
                    '(?i)error|err'                 { $summary.ErrorCount++ }
                    '(?i)warn|warning'              { $summary.WarningCount++ }
                    '(?i)info|information|notice'   { $summary.InfoCount++ }
                    '(?i)debug|trace|verbose'       { $summary.DebugCount++ }
                    default                         { $summary.OtherCount++ }
                }
                
                # Handle timestamp from TimeCreated property
                if ($entry.PSObject.Properties['TimeCreated'] -and $entry.TimeCreated) {
                    $timestamp = $entry.TimeCreated
                    if ($timestamp -is [datetime]) {
                        if (-not $summary.FirstTimestamp -or $timestamp -lt $summary.FirstTimestamp) {
                            $summary.FirstTimestamp = $timestamp
                        }
                        if (-not $summary.LastTimestamp -or $timestamp -gt $summary.LastTimestamp) {
                            $summary.LastTimestamp = $timestamp
                        }
                    }
                }
            } elseif ($entry -is [string]) {
                # Handle string-based log lines
                if ([string]::IsNullOrWhiteSpace($entry)) { continue }

                $summary.TotalLines++
                $lcLine = $entry.ToLowerInvariant()

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

                if ($entry -match '(\d{4}-\d{2}-\d{2}[ T]\d{2}:\d{2}:\d{2}(?:[\.,]\d+)?(?:Z|[\+\-]\d{2}:\d{2})?)') {
                    $timestampCandidate = $matches[1]
                    
                    $parsed = Convert-Timestamp -TimestampString $timestampCandidate
                    if ($parsed) {
                        if (-not $summary.FirstTimestamp -or $parsed -lt $summary.FirstTimestamp) {
                            $summary.FirstTimestamp = $parsed
                        }
                        if (-not $summary.LastTimestamp -or $parsed -gt $summary.LastTimestamp) {
                            $summary.LastTimestamp = $parsed
                        }
                    }
                }
            }
        }
    }

    end {
        return [pscustomobject]$summary
    }
}

function Get-LogEntries {
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
        [string]$ExportFormat = "CSV",

        [int]$Tail,
        [int]$LineLimit
    )

    if (-not (Test-Path $Path) -and ($Path -ne 'journalctl')) {
        throw [System.IO.FileNotFoundException]::new("File not found: $Path", $Path)
    }

    $entries = @()

    # Windows Event Log Parsing
    if ($Path -match '\.(evtx|evt)$') {
        if (-not $IsWindows) {
            throw "❌ Windows event log parsing is only supported on Windows."
        }

        try {
            $events = Get-WinEvent -Path $Path -Oldest

            if ($StartTime) { $events = $events | Where-Object { $_.TimeCreated -ge $StartTime } }
            if ($EndTime)   { $events = $events | Where-Object { $_.TimeCreated -le $EndTime } }
            if ($EventId)   { $events = $events | Where-Object { $EventId -contains $_.Id } }
            if ($Level)     { $events = $events | Where-Object { $Level -contains $_.LevelDisplayName } }
            if ($ProviderName) { $events = $events | Where-Object { $ProviderName -contains $_.ProviderName } }

            if ($SortOrder -eq "Reverse") {
                $events = $events | Sort-Object TimeCreated -Descending
            }

            $entries = $events | ForEach-Object {
    "$($_.TimeCreated.ToString('yyyy-MM-dd HH:mm:ss')) [$($_.LevelDisplayName)] $($_.ProviderName): Event ID $($_.Id) - $($_.Message)"
}

        } catch {
            throw "❌ Failed to parse EVT/EVTX file: $_"
        }

    } elseif ($Path -eq 'journalctl' -and !$IsWindows) {
        # journalctl support (Linux only)
        try {
            $cmd = "journalctl --no-pager"
            if ($StartTime) { $cmd += " --since '$($StartTime.ToString("yyyy-MM-dd HH:mm:ss"))'" }
            if ($EndTime) { $cmd += " --until '$($EndTime.ToString("yyyy-MM-dd HH:mm:ss"))'" }
            $entries = bash -c $cmd
        } catch {
            throw "❌ Failed to retrieve journalctl entries: $_"
        }
    } else {
        try {
            $entries = Get-Content -Path $Path -Encoding UTF8 -ErrorAction Stop
        } catch {
            throw "❌ Failed to read text log: $_"
        }

        if ($SortOrder -eq "Reverse") {
            $entries = $entries | Sort-Object { [array]::IndexOf($entries, $_) } -Descending
        }

        if ($StartTime -or $EndTime) {
            $entries = $entries | Where-Object {
                if ($_ -match '^(?<Time>\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})') {
                    try {
                        $logTime = [datetime]::ParseExact($matches.Time, 'yyyy-MM-dd HH:mm:ss', $null)
                        (!($StartTime) -or $logTime -ge $StartTime) -and
                        (!($EndTime) -or $logTime -le $EndTime)
                    } catch { $false }
                } else { $false }
            }
        }
    }

    # Keyword filtering
    if ($IncludeKeywords.Count -gt 0) {
        $pattern = ($IncludeKeywords -join '|')
        $entries = $entries | Where-Object { $_ -match $pattern }
    }

    if ($ExcludeKeywords.Count -gt 0) {
        $pattern = ($ExcludeKeywords -join '|')
        $entries = $entries | Where-Object { $_ -notmatch $pattern }
    }

    if ($Tail) {
        $entries = $entries | Select-Object -Last $Tail
    } elseif ($LineLimit) {
        $entries = $entries | Select-Object -First $LineLimit
    }

    # Log Summary
    try {
        $summary = Get-LogSummary -LogLines $entries
        Write-Host "`n=== LOG SUMMARY ===" -ForegroundColor Cyan
        $summary | Format-List
    } catch {
        Write-Warning "⚠️ Get-LogSummary failed or not available."
    }

    # Export
    if ($ExportPath) {
        try {
            if ($ExportFormat -eq "CSV") {
                $entries | ForEach-Object { [PSCustomObject]@{ Entry = $_ } } |
                    Export-Csv -Path $ExportPath -NoTypeInformation -Force
            } elseif ($ExportFormat -eq "JSON") {
                $entries | ForEach-Object { [PSCustomObject]@{ Entry = $_ } } |
                    ConvertTo-Json -Depth 3 | Out-File -FilePath $ExportPath -Encoding UTF8
            }
            Write-Host "✅ Log entries exported to $ExportPath" -ForegroundColor Green
        } catch {
            Write-Warning "❌ Failed to export: $_"
        }
    }

    return $entries
}
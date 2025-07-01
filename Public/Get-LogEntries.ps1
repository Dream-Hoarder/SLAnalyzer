function Get-LogEntries {
    [CmdletBinding()]
    param (
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
        [int]$LineLimit,

        [switch]$Redact,
        [switch]$Colorize,

        [ValidateSet("System", "Application", "Security", "Custom")]
        [string]$LogType = "Custom"
    )

    # If LogType is set and not Custom, adjust $Path accordingly (Windows only)
    if ($LogType -ne "Custom") {
        if (-not $IsWindows) {
            throw "❌ LogType filtering is only supported on Windows event logs."
        }
        switch ($LogType) {
            "System" { $Path = "System" }
            "Application" { $Path = "Application" }
            "Security" { $Path = "Security" }
        }
    }

    # Validate path unless LogType is Windows Event Logs or journalctl
    if (($Path -ne 'journalctl') -and
        ($Path -notin @("System", "Application", "Security")) -and
        (-not (Test-Path $Path))) {
        throw [System.IO.FileNotFoundException]::new("File not found: $Path", $Path)
    }

    $entries = @()

    # Windows Event Logs (using Get-WinEvent) for System/Application/Security or .evtx files
    if ($Path -in @("System", "Application", "Security") -or ($Path -match '\.(evtx|evt)$')) {
        if (-not $IsWindows) {
            throw "❌ Windows event log parsing is only supported on Windows."
        }

        try {
            $queryParams = @{
                LogName = $null
                Path = $null
                Oldest = $true
            }

            if ($Path -in @("System", "Application", "Security")) {
                $queryParams.LogName = $Path
            } else {
                $queryParams.Path = $Path
            }

            $events = Get-WinEvent @queryParams

            if ($StartTime) { $events = $events | Where-Object { $_.TimeCreated -ge $StartTime } }
            if ($EndTime)   { $events = $events | Where-Object { $_.TimeCreated -le $EndTime } }
            if ($EventId)   { $events = $events | Where-Object { $EventId -contains $_.Id } }
            if ($Level)     { $events = $events | Where-Object { $Level -contains $_.LevelDisplayName } }
            if ($ProviderName) { $events = $events | Where-Object { $ProviderName -contains $_.ProviderName } }

            if ($SortOrder -eq "Reverse") {
                $events = $events | Sort-Object TimeCreated -Descending
            }

            $entries = $events | ForEach-Object {
                [PSCustomObject]@{
                    Timestamp = $_.TimeCreated
                    Level     = $_.LevelDisplayName
                    Provider  = $_.ProviderName
                    EventId   = $_.Id
                    Message   = $_.Message
                }
            }

        } catch {
            throw "❌ Failed to parse Windows event log: $_"
        }

    } elseif ($Path -eq 'journalctl' -and -not $IsWindows) {
        # Linux journalctl
        try {
            $cmd = "journalctl --no-pager"
            if ($StartTime) { $cmd += " --since '$($StartTime.ToString("yyyy-MM-dd HH:mm:ss"))'" }
            if ($EndTime) { $cmd += " --until '$($EndTime.ToString("yyyy-MM-dd HH:mm:ss"))'" }
            $rawEntries = bash -c $cmd

            # Convert raw entries to PSCustomObject with minimal fields (optional)
            $entries = $rawEntries | ForEach-Object {
                [PSCustomObject]@{
                    Timestamp = $_.Substring(0,19)
                    Message   = $_
                }
            }
        } catch {
            throw "❌ Failed to retrieve journalctl entries: $_"
        }
    } else {
        # Plain text log file
        try {
            $entries = Get-Content -Path $Path -Encoding UTF8 -ErrorAction Stop
        } catch {
            throw "❌ Failed to read text log: $_"
        }

        # Apply sort order for text logs
        if ($SortOrder -eq "Reverse") {
            $entries = $entries | Sort-Object { [array]::IndexOf($entries, $_) } -Descending
        }

        # Filter by datetime range (assumes format: yyyy-MM-dd HH:mm:ss)
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

    # Keyword filtering for string entries
    if ($IncludeKeywords.Count -gt 0) {
        $pattern = ($IncludeKeywords -join '|')
        $entries = $entries | Where-Object {
            if ($_ -is [string]) {
                $_ -match $pattern
            } else {
                # For objects with Message property
                $_.Message -match $pattern
            }
        }
    }

    if ($ExcludeKeywords.Count -gt 0) {
        $pattern = ($ExcludeKeywords -join '|')
        $entries = $entries | Where-Object {
            if ($_ -is [string]) {
                $_ -notmatch $pattern
            } else {
                $_.Message -notmatch $pattern
            }
        }
    }

    # Tail or LineLimit
    if ($Tail) {
        $entries = $entries | Select-Object -Last $Tail
    } elseif ($LineLimit) {
        $entries = $entries | Select-Object -First $LineLimit
    }

    # Redact sensitive info (simple example)
    if ($Redact) {
        $entries = $entries | ForEach-Object {
            if ($_ -is [string]) {
                $_ -replace '(password|token|secret)\s*[:=]?\s*\S+', '[REDACTED]'
            } else {
                if ($_.Message) {
                    $_.Message = $_.Message -replace '(password|token|secret)\s*[:=]?\s*\S+', '[REDACTED]'
                }
                $_
            }
        }
    }

    # Colorize output (simple console coloring of string entries)
    if ($Colorize) {
        $entries = $entries | ForEach-Object {
            if ($_ -is [string]) {
                if ($_ -match '\[ERROR\]') {
                    Write-Host $_ -ForegroundColor Red
                } elseif ($_ -match '\[WARN\]') {
                    Write-Host $_ -ForegroundColor Yellow
                } elseif ($_ -match '\[INFO\]') {
                    Write-Host $_ -ForegroundColor Green
                } else {
                    Write-Host $_
                }
                # Return original line so pipeline continues
                $_
            } else {
                # For objects, just return as-is (no colorization)
                $_
            }
        }
    }

    # Log Summary call (optional)
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
                $entries | Export-Csv -Path $ExportPath -NoTypeInformation -Force
            } elseif ($ExportFormat -eq "JSON") {
                $entries | ConvertTo-Json -Depth 3 | Out-File -FilePath $ExportPath -Encoding UTF8
            }
            Write-Host "✅ Log entries exported to $ExportPath" -ForegroundColor Green
        } catch {
            Write-Warning "❌ Failed to export: $_"
        }
    }

    return $entries
}
# Ensure the script exits with the correct exit code
$LASTEXITCODE = 0
# If you want to use this function in a script, you can call it like this:
# $logEntries = Get-LogEntries -Path "C:\path\to\your\logfile.log" -IncludeKeywords "ERROR" -StartTime (Get-Date).AddDays(-7) -EndTime (Get-Date) -ExportPath "C:\path\to\export.csv" -ExportFormat "CSV"
# This will retrieve log entries from the specified log file, filter them by keywords and date range,
# and export the results to a CSV file.
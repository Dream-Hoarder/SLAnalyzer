# Public\Get-LogEntries.ps1

function Get-LogEntries {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string[]]$Path,

        [string[]]$IncludeKeywords = @(),
        [string[]]$ExcludeKeywords = @(),
        [datetime]$StartTime,
        [datetime]$EndTime,

        [switch]$Ascending,

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

    if ($PSBoundParameters.ContainsKey('Ascending')) {
        if ($PSBoundParameters.ContainsKey('SortOrder')) {
            Write-Warning "⚠️ Both -Ascending and -SortOrder were passed. Prioritizing -Ascending (Forward sort)."
        }
        $SortOrder = 'Forward'
    }

    if ($LogType -ne "Custom") {
        if (-not $IsWindows) {
            throw "❌ LogType filtering is only supported on Windows event logs."
        }
        switch ($LogType) {
            "System"      { $Path = "System" }
            "Application" { $Path = "Application" }
            "Security"    { $Path = "Security" }
        }
    }

    if (($Path -ne 'journalctl') -and
        ($Path -notin @("System", "Application", "Security")) -and
        (-not (Test-Path $Path))) {
        throw [System.IO.FileNotFoundException]::new("File not found: $($Path -join ', ')", $Path)
    }

    $allParsedEntries = [System.Collections.Generic.List[PSObject]]::new()

    foreach ($currentPath in $Path) {
        if ($currentPath -in @("System", "Application", "Security") -or ($currentPath -match '\.(evtx|evt)$')) {
            if (-not $IsWindows) {
                throw "❌ Windows event log parsing is only supported on Windows."
            }

            try {
                $queryParams = @{
                    LogName = $null
                    Path    = $null
                    Oldest  = $true
                }

                if ($currentPath -in @("System", "Application", "Security")) {
                    $queryParams.LogName = $currentPath
                } else {
                    $queryParams.Path = $currentPath
                }

                $events = Get-WinEvent @queryParams

                if ($StartTime)     { $events = $events | Where-Object { $_.TimeCreated -ge $StartTime } }
                if ($EndTime)       { $events = $events | Where-Object { $_.TimeCreated -le $EndTime } }
                if ($EventId)       { $events = $events | Where-Object { $EventId -contains $_.Id } }
                if ($Level)         { $events = $events | Where-Object { $Level -contains $_.LevelDisplayName } }
                if ($ProviderName)  { $events = $events | Where-Object { $ProviderName -contains $_.ProviderName } }

                if ($SortOrder -eq "Reverse") {
                    $events = $events | Sort-Object TimeCreated -Descending
                }

                $events | ForEach-Object {
                    $message = $_.Message
                    if ($Redact) {
                        $message = Protect-Message -Message $message
                    }
                    $allParsedEntries.Add(
                        [PSCustomObject]@{
                            Timestamp = $_.TimeCreated
                            Level     = $_.LevelDisplayName
                            Provider  = $_.ProviderName
                            EventId   = $_.Id
                            Message   = $message
                        }
                    )
                }
            } catch {
                throw "❌ Failed to parse Windows event log from '$currentPath': $_"
            }

        } elseif ($currentPath -eq 'journalctl' -and -not $IsWindows) {
            try {
                $cmd = "journalctl --no-pager"
                if ($StartTime) { $cmd += " --since '$($StartTime.ToString("yyyy-MM-dd HH:mm:ss"))'" }
                if ($EndTime)   { $cmd += " --until '$($EndTime.ToString("yyyy-MM-dd HH:mm:ss"))'" }
                $rawEntries = bash -c $cmd

                $rawEntries | ForEach-Object {
                    $message = $_
                    if ($Redact) {
                        $message = Protect-Message -Message $message
                    }
                    $allParsedEntries.Add(
                        [PSCustomObject]@{
                            Timestamp = if ($_.Length -ge 19 -and $_.Substring(0,19) -match '\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}') { [datetime]$_.Substring(0,19) } else { $null }
                            Message   = $message
                        }
                    )
                }
            } catch {
                throw "❌ Failed to retrieve journalctl entries: $_"
            }

        } else {
            try {
                $lines = Get-Content -Path $currentPath -Encoding UTF8 -ErrorAction Stop
            } catch {
                throw "❌ Failed to read text log from '$currentPath': $_"
            }

            foreach ($line in $lines) {
                $parsedEntry = Format-LogEntry -Line $line -Redact:$Redact
                if ($parsedEntry) {
                    $allParsedEntries.Add($parsedEntry)
                }
            }
        }
    }

    $finalEntries = $allParsedEntries | Where-Object {
        $pass = $true
        if ($StartTime) { $pass = $pass -and ($_.Timestamp -ge $StartTime) }
        if ($EndTime)   { $pass = $pass -and ($_.Timestamp -le $EndTime) }

        if ($IncludeKeywords.Count -gt 0) {
            $includeMatch = $false
            foreach ($keyword in $IncludeKeywords) {
                if ($_.Level -eq $keyword -or $_.Message -match $keyword) {
                    $includeMatch = $true; break
                }
            }
            $pass = $pass -and $includeMatch
        }

        if ($ExcludeKeywords.Count -gt 0) {
            $excludeMatch = $false
            foreach ($keyword in $ExcludeKeywords) {
                if ($_.Level -eq $keyword -or $_.Message -match $keyword) {
                    $excludeMatch = $true; break
                }
            }
            $pass = $pass -and (-not $excludeMatch)
        }

        return $pass
    }

    if ($SortOrder -eq "Reverse") {
        $finalEntries = $finalEntries | Sort-Object Timestamp -Descending
    } else {
        $finalEntries = $finalEntries | Sort-Object Timestamp -Ascending
    }

    if ($Tail) {
        $finalEntries = $finalEntries | Select-Object -Last $Tail
    } elseif ($LineLimit) {
        $finalEntries = $finalEntries | Select-Object -First $LineLimit
    }

    if ($Colorize) {
        $coloredEntries = @()
        foreach ($entry in $finalEntries) {
            if ($entry.Level -match 'ERROR') {
                Write-Host ($entry | Format-LogEntry -Line $entry.RawLine -Redact:$Redact) -ForegroundColor Red
            } elseif ($entry.Level -match 'WARN') {
                Write-Host ($entry | Format-LogEntry -Line $entry.RawLine -Redact:$Redact) -ForegroundColor Yellow
            } elseif ($entry.Level -match 'INFO') {
                Write-Host ($entry | Format-LogEntry -Line $entry.RawLine -Redact:$Redact) -ForegroundColor Green
            } else {
                Write-Host ($entry | Format-LogEntry -Line $entry.RawLine -Redact:$Redact)
            }
            $coloredEntries += $entry
        }
        $finalEntries = $coloredEntries
    }

    try {
        # Optional summary output
        # $summary = Get-LogSummary -LogEntries $finalEntries
        # Write-Host "`n=== LOG SUMMARY ===" -ForegroundColor Cyan
        # $summary | Format-List
    } catch {
        Write-Warning "⚠️ Get-LogSummary failed or not available."
    }

    if ($ExportPath) {
        try {
            if ($ExportFormat -eq "CSV") {
                $finalEntries | Export-Csv -Path $ExportPath -NoTypeInformation -Force
            } elseif ($ExportFormat -eq "JSON") {
                $finalEntries | ConvertTo-Json -Depth 3 | Out-File -FilePath $ExportPath -Encoding UTF8
            }
            Write-Host "✅ Log entries exported to $ExportPath" -ForegroundColor Green
        } catch {
            Write-Warning "❌ Failed to export: $_"
        }
    }

    return $finalEntries
}

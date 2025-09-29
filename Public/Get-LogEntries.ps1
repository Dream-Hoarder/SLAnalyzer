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

    $SortOrder = if ($Ascending.IsPresent) { "Forward" } else { $SortOrder }

    if ($Ascending.IsPresent -and $PSBoundParameters.ContainsKey('SortOrder')) {
        Write-Warning "⚠️ Both -Ascending and -SortOrder were passed. Prioritizing -Ascending (Forward sort)."
    }

    if ($LogType -ne "Custom" -and -not $PSBoundParameters.ContainsKey('Path')) {
        if (-not $IsWindows) {
            throw "❌ LogType filtering is only supported on Windows event logs."
        }
        $Path = @($LogType)
    }

    foreach ($p in $Path) {
        if (($p -ne 'journalctl') -and
            ($p -notin @("System", "Application", "Security")) -and
            (-not (Test-Path $p))) {
            throw [System.IO.FileNotFoundException]::new("File not found: $($Path -join ', ')", $p)
        }
    }

    $allParsedEntries = [System.Collections.Generic.List[PSCustomObject]]::new()
    $includeRegex = if ($IncludeKeywords) { ($IncludeKeywords -join "|") } else { $null }
    $excludeRegex = if ($ExcludeKeywords) { ($ExcludeKeywords -join "|") } else { $null }

    foreach ($currentPath in $Path) {
        if ($currentPath -in @("System", "Application", "Security") -or $currentPath -match '\.(evtx|evt)$') {
            if (-not $IsWindows) {
                throw "❌ Windows event log parsing is only supported on Windows."
            }

            try {
                $queryParams = @{ Oldest = $true }
                if ($currentPath -in @("System", "Application", "Security")) {
                    $queryParams.LogName = $currentPath
                } else {
                    $queryParams.Path = $currentPath
                }

                $events = Get-WinEvent @queryParams | Where-Object {
                    (!($StartTime)     -or $_.TimeCreated -ge $StartTime) -and
                    (!($EndTime)       -or $_.TimeCreated -le $EndTime) -and
                    (!($EventId)       -or $EventId -contains $_.Id) -and
                    (!($Level)         -or $Level -contains $_.LevelDisplayName) -and
                    (!($ProviderName)  -or $ProviderName -contains $_.ProviderName)
                }

                foreach ($e in $events) {
                    $message = if ($Redact) { Protect-Message -Message $e.Message } else { $e.Message }
                    $parsedEntry = [PSCustomObject]@{
                        Timestamp = $e.TimeCreated
                        Level     = $e.LevelDisplayName
                        Provider  = $e.ProviderName
                        EventId   = $e.Id
                        Message   = $message
                        RawLine   = $e.ToXml()
                    }
                    $allParsedEntries.Add($parsedEntry)
                }
            } catch {
                throw "❌ Failed to parse Windows event log from '$currentPath': $_"
            }

        } elseif ($currentPath -eq 'journalctl' -and -not $IsWindows) {
            try {
                $cmd = @("journalctl", "--no-pager")
                if ($StartTime) { $cmd += "--since=$($StartTime.ToString("yyyy-MM-dd HH:mm:ss"))" }
                if ($EndTime)   { $cmd += "--until=$($EndTime.ToString("yyyy-MM-dd HH:mm:ss"))" }

                $rawEntries = & $cmd

                foreach ($line in $rawEntries) {
                    $tsMatch = if ($line -match '\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}') {
                        Convert-Timestamp -TimestampString $matches[0]
                    } else { $null }

                    $msg = if ($Redact) { Protect-Message -Message $line } else { $line }

                    $allParsedEntries.Add([PSCustomObject]@{
                        Timestamp = $tsMatch
                        Message   = $msg
                        RawLine   = $line
                    })
                }
            } catch {
                throw "❌ Failed to retrieve journalctl entries: $_"
            }

        } else {
            try {
                $lines = Get-Content -Path $currentPath -Encoding UTF8 -ErrorAction Stop
                foreach ($line in $lines) {
                    $parsedEntry = Format-LogEntry -Line $line -Redact:$Redact
                    if ($parsedEntry) {
                        $allParsedEntries.Add($parsedEntry)
                    }
                }
            } catch {
                throw "❌ Failed to read text log from '$currentPath': $_"
            }
        }
    }

    $finalEntries = $allParsedEntries | Where-Object {
        (!($StartTime)   -or $_.Timestamp -ge $StartTime) -and
        (!($EndTime)     -or $_.Timestamp -le $EndTime)   -and
        (!($includeRegex) -or ($_.Level -match $includeRegex -or $_.Message -match $includeRegex)) -and
        (!($excludeRegex) -or -not ($_.Level -match $excludeRegex -or $_.Message -match $excludeRegex))
    }

    $finalEntries = if ($SortOrder -eq "Reverse") {
        $finalEntries | Sort-Object Timestamp -Descending
    } else {
        $finalEntries | Sort-Object Timestamp
    }

    if ($Tail) {
        $finalEntries = $finalEntries | Select-Object -Last $Tail
    } elseif ($LineLimit) {
        $finalEntries = $finalEntries | Select-Object -First $LineLimit
    }

    if ($Colorize) {
        $coloredEntries = foreach ($entry in $finalEntries) {
            $color = switch -Regex ($entry.Level) {
                'ERROR' { 'Red' }
                'WARN'  { 'Yellow' }
                'INFO'  { 'Green' }
                default { $null }
            }

            $formatted = Format-LogEntry -Line $entry.RawLine -Redact:$Redact
            if ($color) {
                Write-Host $formatted -ForegroundColor $color
            } else {
                Write-Host $formatted
            }
            $entry
        }
        $finalEntries = $coloredEntries
    }

    if ($ExportPath) {
        try {
            if ($ExportFormat -eq "CSV") {
                $finalEntries | Export-Csv -Path $ExportPath -NoTypeInformation -Force
            } else {
                $finalEntries | ConvertTo-Json -Depth 3 | Out-File -FilePath $ExportPath -Encoding UTF8
            }
            Write-Host "✅ Log entries exported to $ExportPath" -ForegroundColor Green
        } catch {
            Write-Warning "❌ Failed to export: $_"
        }
    }

    return $finalEntries
}

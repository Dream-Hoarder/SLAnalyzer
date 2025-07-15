function Get-SystemLogs {
    [CmdletBinding()]
    param (
        [ValidateSet("System", "Application", "Security", "All", "Custom")]
        [string]$LogType = "System",

        [datetime]$StartTime = (Get-Date).AddHours(-1),
        [datetime]$EndTime   = (Get-Date),

        [string]$CustomPath,

        [switch]$Colorize,
        [switch]$AttentionOnly,

        [string]$OutputPath
    )

    $onWindows = $PSVersionTable.OS -match 'Windows'
    $onLinux   = $PSVersionTable.OS -match 'Linux'
    $logs = [System.Collections.Generic.List[object]]::new()

    if ($onWindows) {
        try {
            $logSources = switch ($LogType) {
                "All"    { @("System", "Application", "Security") }
                "Custom" { if ($CustomPath -and (Test-Path $CustomPath)) { @($CustomPath) } else { throw "❌ CustomPath invalid or missing." } }
                default  { @($LogType) }
            }

            foreach ($source in $logSources) {
                try {
                    $events = if ($LogType -eq "Custom") {
                        Get-WinEvent -Path $source -ErrorAction Stop
                    } else {
                        Get-WinEvent -FilterHashtable @{
                            LogName   = $source
                            StartTime = $StartTime
                            EndTime   = $EndTime
                        } -ErrorAction Stop
                    }

                    foreach ($evt in $events) {
                        $logs.Add([PSCustomObject]@{
                            TimeCreated      = $evt.TimeCreated
                            LevelDisplayName = $evt.LevelDisplayName
                            ProviderName     = $evt.ProviderName
                            EventId          = $evt.Id
                            Message          = $evt.Message
                        })
                    }
                } catch {
                    Write-Warning "⚠️ Get-WinEvent failed for $source, trying fallback..."

                    if ($source -in @("System", "Application", "Security")) {
                        $fallbackEvents = Get-EventLog -LogName $source -After $StartTime -Before $EndTime -ErrorAction Stop
                        foreach ($evt in $fallbackEvents) {
                            $logs.Add([PSCustomObject]@{
                                TimeCreated      = $evt.TimeGenerated
                                LevelDisplayName = $evt.EntryType.ToString()
                                ProviderName     = $evt.Source
                                EventId          = $evt.InstanceId
                                Message          = $evt.Message
                            })
                        }
                    } else {
                        throw "❌ Unsupported log source or fallback failed: $source"
                    }
                }
            }
        } catch {
            throw "❌ Failed to retrieve Windows logs: $_"
        }

    } elseif ($onLinux) {
        $journalOk = $false
        try {
            $cmd = @("journalctl", "--no-pager", "--output=json")
            if ($StartTime) { $cmd += "--since=$($StartTime.ToString("yyyy-MM-dd HH:mm:ss"))" }
            if ($EndTime)   { $cmd += "--until=$($EndTime.ToString("yyyy-MM-dd HH:mm:ss"))" }

            $journalOutput = & $cmd

            $epoch = Get-Date "1970-01-01T00:00:00Z"
            $priorityMap = @{
                0 = 'Emergency'; 1 = 'Alert'; 2 = 'Critical'; 3 = 'Error'
                4 = 'Warning';   5 = 'Notice'; 6 = 'Info';    7 = 'Debug'
            }

            foreach ($line in $journalOutput) {
                if ($line.Trim()) {
                    try {
                        $obj = $line | ConvertFrom-Json
                        $level = if ($priorityMap.ContainsKey($obj.PRIORITY)) { $priorityMap[$obj.PRIORITY] } else { "Unknown" }

                        $timestamp = $epoch.AddMilliseconds($obj.__REALTIME_TIMESTAMP / 1000)

                        $logs.Add([PSCustomObject]@{
                            TimeCreated      = $timestamp
                            LevelDisplayName = $level
                            ProviderName     = $obj.SYSLOG_IDENTIFIER
                            EventId          = $null
                            Message          = $obj.MESSAGE
                        })
                    } catch {
                        continue
                    }
                }
            }

            $journalOk = $true
        } catch {
            Write-Warning "⚠️ journalctl not available or failed: $_"
        }

        if (-not $journalOk) {
            $fallbackFiles = @("/var/log/syslog", "/var/log/messages", "/var/log/auth.log")
            foreach ($file in $fallbackFiles) {
                if (Test-Path $file) {
                    Get-Content -Path $file | ForEach-Object {
                        $line = $_
                        $regex = '^(?<month>\w{3})\s+(?<day>\d{1,2})\s+(?<time>\d{2}:\d{2}:\d{2})'
                        $timestamp = if ($line -match $regex) {
                            $month = $matches['month']
                            $day   = [int]$matches['day']
                            $time  = $matches['time']
                            $year  = (Get-Date).Year
                            [datetime]::ParseExact("$month $day $year $time", "MMM d yyyy HH:mm:ss", $null)
                        } else {
                            Get-Date
                        }

                        $level = if ($line -match "(?i)error") { "Error" }
                                 elseif ($line -match "(?i)warn") { "Warning" }
                                 elseif ($line -match "(?i)info") { "Information" }
                                 else { "Unknown" }

                        $logs.Add([PSCustomObject]@{
                            TimeCreated      = $timestamp
                            LevelDisplayName = $level
                            ProviderName     = "syslog"
                            EventId          = $null
                            Message          = $line
                        })
                    }
                }
            }
        }

    } else {
        throw "❌ Unsupported operating system."
    }

    if ($AttentionOnly) {
        $attentionPattern = '(?i)error|warn|critical|fail|denied|unauthorized|security'
        $logs = $logs | Where-Object {
            "$($_.LevelDisplayName) $($_.Message)" -match $attentionPattern
        }
    }

    if ($Colorize) {
        foreach ($log in $logs) {
            $color = switch -Regex ($log.LevelDisplayName) {
                'Error'      { 'Red' }
                'Warning'    { 'Yellow' }
                'Information' { 'Green' }
                default      { 'White' }
            }
            Write-Host ("[{0}] {1}: {2}" -f $log.TimeCreated, $log.LevelDisplayName, $log.Message) -ForegroundColor $color
        }
    }

    if ($OutputPath) {
        try {
            $logs | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8 -Force
            Write-Verbose "✅ Logs exported to $OutputPath"
        } catch {
            Write-Warning "❌ Failed to export logs: $_"
        }
    }

    return $logs
}

Export-ModuleMember -Function Get-SystemLogs

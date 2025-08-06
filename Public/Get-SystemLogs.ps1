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

    # Determine OS - compatible with both PowerShell 5.1 and 7+
    $onWindows = if ($PSVersionTable.PSVersion.Major -ge 6) {
        $IsWindows
    } else {
        $env:OS -eq 'Windows_NT'
    }
    $onLinux = if ($PSVersionTable.PSVersion.Major -ge 6) {
        $IsLinux
    } else {
        $false  # PowerShell 5.1 only runs on Windows
    }
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
                    # Special handling for Security log - requires elevated privileges
                    if ($source -eq "Security") {
                        $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
                        $isElevated = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
                        
                        if (-not $isElevated) {
                            Write-Warning "⚠️ Security log requires elevated privileges. Skipping Security log. Run PowerShell as Administrator to access Security logs."
                            continue
                        }
                    }

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
                        # Format the message to be more user-friendly
                        $formattedMessage = try {
                            Format-WindowsEventMessage -EventObject $evt
                        } catch {
                            # Fallback to original message with XML cleanup
                            if ($evt.Message) {
                                $evt.Message -replace '<[^>]+>', ''
                            } else {
                                "Event $($evt.Id) from $($evt.ProviderName)"
                            }
                        }
                        
                        $logs.Add([PSCustomObject]@{
                            TimeCreated      = $evt.TimeCreated
                            LevelDisplayName = $evt.LevelDisplayName
                            ProviderName     = $evt.ProviderName
                            EventId          = $evt.Id
                            Message          = $formattedMessage
                            RawMessage       = $evt.Message  # Keep original for debugging
                        })
                    }
                    
                    # Safe count handling to avoid "Count property not found" warnings
                    $eventCount = if ($events) { 
                        if ($events -is [array]) { $events.Count } 
                        elseif ($events.Count) { $events.Count }
                        else { 1 }
                    } else { 0 }
                    Write-Verbose "✅ Successfully retrieved $eventCount events from $source log"
                } catch {
                    Write-Warning "⚠️ Get-WinEvent failed for $source`: $($_.Exception.Message)"
                    Write-Verbose "Attempting fallback method for $source..."

                    try {
                        if ($source -in @("System", "Application", "Security")) {
                            # Additional check for Security log in fallback
                            if ($source -eq "Security") {
                                $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
                                $isElevated = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
                                
                                if (-not $isElevated) {
                                    Write-Warning "⚠️ Security log fallback also requires elevated privileges. Skipping Security log."
                                    continue
                                }
                            }
                            
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
                            Write-Verbose "[OK] Fallback successful for $source - retrieved $($fallbackEvents.Count) events"
                        } else {
                            Write-Warning "[WARN] No fallback available for log source: $source"
                        }
                    } catch {
                        Write-Warning "[WARN] Both primary and fallback methods failed for $source`: $($_.Exception.Message)"
                        # Continue processing other log sources instead of failing completely
                    }
                }
            }
        } catch {
            throw "[ERROR] Failed to retrieve Windows logs: $_"
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
        throw "[ERROR] Unsupported operating system."
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

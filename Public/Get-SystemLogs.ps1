function Get-SystemLogs {
    [CmdletBinding()]
    param (
        [ValidateSet("System", "Application", "Security", "All", "Custom")]
        [string]$LogType = "System",

        [datetime]$StartTime = (Get-Date).AddHours(-1),
        [datetime]$EndTime = (Get-Date),

        [string]$CustomPath,

        [switch]$Colorize,
        [switch]$AttentionOnly,

        [string]$OutputPath
    )

    # Detect OS
    $runningOnWindows = $PSVersionTable.OS -match 'Windows'
    $runningOnLinux = $PSVersionTable.OS -match 'Linux'

    $logs = @()

    if ($runningOnWindows) {
        try {
            if ($LogType -eq "Custom" -and $CustomPath -and (Test-Path $CustomPath)) {
                $events = Get-WinEvent -Path $CustomPath -ErrorAction Stop
            }
            else {
                $filter = @{
                    LogName   = if ($LogType -eq "All") { @("System", "Application", "Security") } else { $LogType }
                    StartTime = $StartTime
                    EndTime   = $EndTime
                }
                $events = Get-WinEvent -FilterHashtable $filter -ErrorAction Stop
            }

            foreach ($evt in $events) {
                $logs += [PSCustomObject]@{
                    TimeCreated      = $evt.TimeCreated
                    LevelDisplayName = $evt.LevelDisplayName
                    ProviderName     = $evt.ProviderName
                    Id               = $evt.Id
                    Message          = $evt.Message
                }
            }
        } catch {
            # Fallback to Get-EventLog
            if ($LogType -in @("System", "Application", "Security")) {
                $events = Get-EventLog -LogName $LogType -After $StartTime -Before $EndTime -ErrorAction Stop
                foreach ($evt in $events) {
                    $logs += [PSCustomObject]@{
                        TimeCreated      = $evt.TimeGenerated
                        LevelDisplayName = $evt.EntryType.ToString()
                        Source           = $evt.Source
                        InstanceId       = $evt.InstanceId
                        Message          = $evt.Message
                    }
                }
            }
            else {
                throw "Failed to retrieve logs: unsupported log type or path"
            }
        }
    }
    elseif ($runningOnLinux) {
        $logs = @()
        $journalOk = $false
        try {
            $journalCmd = "journalctl --no-pager --output=json"
            if ($StartTime) { $journalCmd += " --since='$($StartTime.ToString("yyyy-MM-dd HH:mm:ss"))'" }
            if ($EndTime)   { $journalCmd += " --until='$($EndTime.ToString("yyyy-MM-dd HH:mm:ss"))'" }

            $journalOutput = bash -c $journalCmd
            foreach ($line in $journalOutput) {
                if ($line.Trim()) {
                    $obj = $null
                    try {
                        $obj = $line | ConvertFrom-Json
                    } catch {
                        # ignore malformed lines
                    }
                    if ($obj) {
                        # Convert numeric priority to textual level if needed
                        $priorityMap = @{
                            0 = 'Emergency'; 1 = 'Alert'; 2 = 'Critical'; 3 = 'Error'; 4 = 'Warning';
                            5 = 'Notice'; 6 = 'Info'; 7 = 'Debug'
                        }
                        $level = if ($priorityMap.ContainsKey($obj.PRIORITY)) { $priorityMap[$obj.PRIORITY] } else { 'Unknown' }

                        # __REALTIME_TIMESTAMP is in microseconds since epoch; convert to datetime
                        $epoch = Get-Date "1970-01-01T00:00:00Z"
                        $timestamp = $epoch.AddMilliseconds($obj.__REALTIME_TIMESTAMP / 1000)

                        $logs += [PSCustomObject]@{
                            TimeCreated      = $timestamp
                            LevelDisplayName = $level
                            Message          = $obj.MESSAGE
                        }
                    }
                }
            }
            $journalOk = $true
        } catch {
            Write-Warning "journalctl failed or not available."
        }

        if (-not $journalOk) {
            $fallbackFiles = @("/var/log/syslog", "/var/log/messages", "/var/log/auth.log")
            foreach ($file in $fallbackFiles) {
                if (Test-Path $file) {
                    Get-Content $file | ForEach-Object {
                        $line = $_
                        $regex = '^(?<month>\w{3})\s+(?<day>\d{1,2})\s+(?<time>\d{2}:\d{2}:\d{2})'
                        if ($line -match $regex) {
                            $month = $matches['month']
                            $day   = [int]$matches['day']
                            $time  = $matches['time']
                            $year  = (Get-Date).Year
                            $timestamp = [datetime]::ParseExact("$month $day $year $time", "MMM d yyyy HH:mm:ss", $null)
                        } else {
                            $timestamp = (Get-Date)
                        }

                        $level = if ($line -match "(?i)error") { "Error" }
                                 elseif ($line -match "(?i)warn") { "Warning" }
                                 elseif ($line -match "(?i)info") { "Information" }
                                 else { "Unknown" }

                        $logs += [PSCustomObject]@{
                            TimeCreated      = $timestamp
                            LevelDisplayName = $level
                            Message          = $line
                        }
                    }
                }
            }
        }
    }
    else {
        throw "Unsupported operating system."
    }

    # Filter attention only if requested
    if ($AttentionOnly) {
        $logs = $logs | Where-Object {
            $_.LevelDisplayName -match 'Error|Warning|Critical' -or
            $_.Message -match '(fail|denied|unauthorized|critical|security)'
        }
    }

    # Export if requested
    if ($OutputPath) {
        try {
            $logs | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8 -Force
            Write-Verbose "Logs exported to $OutputPath"
        } catch {
            Write-Warning "Failed to export logs: $_"
        }
    }

    # Return raw objects for further processing or display
    return $logs
}

# Export the function for use in other scripts or modules
Export-ModuleMember -Function Get-SystemLogs
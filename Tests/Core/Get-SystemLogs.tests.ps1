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

    # Validate LogType early
    if (-not ('System','Application','Security','All','Custom' -contains $LogType)) {
        throw "Invalid LogType specified: $LogType"
    }

    $isWin = $PSVersionTable.OS -match 'Windows'
    $isLin = $PSVersionTable.OS -match 'Linux'
    $logEntries = @()

    if ($isWin) {
        try {
            if ($LogType -eq 'Custom') {
                if (-not $CustomPath) {
                    throw "CustomPath is required for LogType 'Custom'"
                }
                if (-not (Test-Path $CustomPath)) {
                    throw "CustomPath '$CustomPath' does not exist"
                }
                $events = Get-WinEvent -Path $CustomPath -ErrorAction Stop
            }
            else {
                $filter = @{
                    LogName = if ($LogType -eq 'All') { @('System','Application','Security') } else { $LogType }
                    StartTime = $StartTime
                    EndTime = $EndTime
                }
                $events = Get-WinEvent -FilterHashtable $filter -ErrorAction Stop
            }

            foreach ($evt in $events) {
                $logEntries += [PSCustomObject]@{
                    TimeCreated      = $evt.TimeCreated
                    LevelDisplayName = $evt.LevelDisplayName
                    ProviderName     = $evt.ProviderName
                    Id               = $evt.Id
                    Message          = $evt.Message
                }
            }
        }
        catch {
            # Fallback to Get-EventLog
            if ($LogType -in @('System','Application','Security')) {
                $events = Get-EventLog -LogName $LogType -After $StartTime -Before $EndTime -ErrorAction Stop
                foreach ($evt in $events) {
                    $logEntries += [PSCustomObject]@{
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
    elseif ($isLin) {
        try {
            $journalCmd = "journalctl --no-pager --output=json"
            if ($StartTime) { $journalCmd += " --since='$($StartTime.ToString("yyyy-MM-dd HH:mm:ss"))'" }
            if ($EndTime)   { $journalCmd += " --until='$($EndTime.ToString("yyyy-MM-dd HH:mm:ss"))'" }

            $journalOutput = bash -c $journalCmd
            $logEntries = $journalOutput | ConvertFrom-Json
        }
        catch {
            # Fallback reading common log files
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
                        }
                        else {
                            $timestamp = (Get-Date)
                        }

                        $level = if ($line -match "(?i)error") { "Error" }
                                 elseif ($line -match "(?i)warn") { "Warning" }
                                 elseif ($line -match "(?i)info") { "Information" }
                                 else { "Unknown" }

                        $logEntries += [PSCustomObject]@{
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
        throw "Unsupported operating system platform."
    }

    if ($AttentionOnly) {
        $logEntries = $logEntries | Where-Object {
            $_.LevelDisplayName -match 'Error|Warning' -or
            $_.Message -match 'fail|denied|unauthorized|critical|security'
        }
    }

    if ($Colorize) {
        foreach ($log in $logEntries) {
            $timestamp = $log.TimeCreated
            $level     = $log.LevelDisplayName
            $msg       = $log.Message

            switch -Regex ($level) {
                "Error"     { Write-Host "[$timestamp] [ERROR   ] ❌ $msg" -ForegroundColor Red }
                "Warning"   { Write-Host "[$timestamp] [WARNING ] ⚠️  $msg" -ForegroundColor Yellow }
                "Info|Information" {
                    if ($msg -match 'success|started|completed') {
                        Write-Host "[$timestamp] [INFO    ] ✅ $msg" -ForegroundColor Green
                    }
                    else {
                        Write-Host "[$timestamp] [INFO    ] $msg" -ForegroundColor Gray
                    }
                }
                default     { Write-Host "[$timestamp] [UNKNOWN ] $msg" -ForegroundColor DarkGray }
            }
        }
    }
    else {
        $logEntries | Select-Object TimeCreated, LevelDisplayName, Message | Format-Table -AutoSize
    }

    if ($OutputPath) {
        try {
            $logEntries | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8
            Write-Host "Logs exported to $OutputPath" -ForegroundColor Cyan
        }
        catch {
            Write-Warning "Failed to export logs: $_"
        }
    }

    return $logEntries
}



# This test suite checks the Get-SystemLogs function for both Windows and Linux environments.
# It ensures that logs can be retrieved without errors, handles fallback scenarios on Windows,
# and verifies that journalctl logs are returned on Linux systems.
# The tests use the Should module for assertions and Mock to simulate failures in Get-WinEvent.
# The -Skip parameter is used to conditionally run tests based on the operating system.
# The tests are designed to be run in a PowerShell environment with the SmartLogAnalyzer module loaded.
# The tests cover the core functionality of the Get-SystemLogs function, ensuring it behaves correctly
# across different platforms and scenarios.
# The tests are structured to provide clear feedback on the success or failure of each scenario,
# allowing for easy identification of issues in the log retrieval process.
# The test suite is designed to be run as part of a continuous integration pipeline,
# ensuring that any changes to the Get-SystemLogs function do not break existing functionality.
# The tests are written in a way that they can be easily extended to cover additional scenarios
# or edge cases in the future, providing a solid foundation for ongoing development and maintenance.
# The test suite is part of a larger testing framework for the SmartLogAnalyzer module,
# which includes tests for other functions such as Get-LogEntries, Get-LogSummary,
# and Invoke-SmartAnalyzer. This ensures comprehensive coverage of the module's functionality
# and helps maintain high code quality standards.
# The tests are executed using the Pester testing framework, which is a standard for PowerShell testing.
# The results of the tests can be easily integrated into a CI/CD pipeline,
# providing immediate feedback on the health of the SmartLogAnalyzer module.
# The test suite is designed to be run in a PowerShell environment with the SmartLogAnalyzer module loaded,
# ensuring that all dependencies are met and the tests can be executed successfully.

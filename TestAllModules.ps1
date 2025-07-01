# Path setup
$basePath = "C:\Users\willi\OneDrive\Desktop\PowershellProjects\Project.Modules\SmartLogAnalyzer"
$logPath = "$basePath\Tests\SmartLogAnalyzerTestResults.txt"
$sampleLog = "$basePath\Tests\Sample.Logs\sample.log"
$modulePath = "$basePath\SmartLogAnalyzer.psm1"

# Initialize error log
"Smart Log Analyzer Automated Test Report - $(Get-Date)" | Out-File $logPath

# Import module
try {
    Import-Module $modulePath -Force -ErrorAction Stop
    Add-Content -Path $logPath -Value "`n[OK] Module imported successfully."
} catch {
    Add-Content -Path $logPath -Value "`n[FAIL] Failed to import module: $_"
    exit 1
}

function Test-WithTimeout {
    param (
        [scriptblock]$Code,
        [int]$TimeoutSeconds = 60,
        [string]$Name
    )

    $startTime = Get-Date
    try {
        & $Code
        $duration = (Get-Date) - $startTime
        Add-Content -Path $logPath -Value "`n[OK] $Name completed in $($duration.TotalSeconds) sec"
    } catch {
        Add-Content -Path $logPath -Value "`n[ERROR] $Name failed: $_"
    }
}

# 1. Get-LogEntries
Test-WithTimeout -Name "Get-LogEntries" -Code {
    Get-LogEntries -Path $sampleLog | Out-Null
}

# 2. Get-LogSummary
Test-WithTimeout -Name "Get-LogSummary" -Code {
    Get-LogSummary -LogFile $sampleLog | Out-Null
}

# 3. Get-SystemLogs
Test-WithTimeout -Name "Get-SystemLogs" -Code {
    Get-SystemLogs -LogType System | Out-Null
}

# 4. Invoke-SmartAnalyzer (Fetch mode)
Test-WithTimeout -Name "Invoke-SmartAnalyzer" -Code {
    Invoke-SmartAnalyzer -FetchLogs -LogType System -AttentionOnly -ReportPath "$basePath\Tests\AnalyzerReport.txt"
}

# 5. Show-LogAnalyzerUI (30 sec test)
Test-WithTimeout -Name "Show-LogAnalyzerUI" -Code {
    Start-Job { Show-LogAnalyzerUI; Start-Sleep -Seconds 30 } | Out-Null
}

# Open final test report
notepad.exe $logPath

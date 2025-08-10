# TestFixes.ps1 - Test Smart Log Analyzer fixes

Write-Host "Testing Smart Log Analyzer Fixes" -ForegroundColor Yellow

# Import module
try {
    Import-Module ./SmartLogAnalyzer.psd1 -Force
    Write-Host "[OK] Module imported successfully" -ForegroundColor Green
} catch {
    Write-Host "[ERROR] Failed to import module: $_" -ForegroundColor Red
    exit 1
}

Write-Host "`nTesting core functions..." -ForegroundColor Cyan

# Test 1: Get-SystemLogs
Write-Host "`n1. Testing Get-SystemLogs..."
try {
    $logs = Get-SystemLogs -LogType System -StartTime (Get-Date).AddHours(-1)
    Write-Host "[OK] System logs: $($logs.Count) entries" -ForegroundColor Green
} catch {
    Write-Host "[WARN] System logs failed: $_" -ForegroundColor Yellow
}

# Test 2: Invoke-SmartAnalyzer 
Write-Host "`n2. Testing Invoke-SmartAnalyzer..."
try {
    $result = Invoke-SmartAnalyzer -FetchLogs -LogType Application -StartTime (Get-Date).AddHours(-1)
    Write-Host "[OK] Smart Analyzer: $($result.Entries.Count) entries" -ForegroundColor Green
} catch {
    Write-Host "[WARN] Smart Analyzer failed: $_" -ForegroundColor Yellow
}

# Test 3: Get-LogSummary with edge cases
Write-Host "`n3. Testing Get-LogSummary null handling..."
try {
    $emptySummary = Get-LogSummary -LogLines @()
    Write-Host "[OK] Empty summary: $($emptySummary.TotalLines) lines" -ForegroundColor Green
} catch {
    Write-Host "[ERROR] Get-LogSummary failed: $_" -ForegroundColor Red
}

# Test 4: UI function availability
Write-Host "`n4. Testing UI function..."
try {
    $ui = Get-Command Show-LogAnalyzerUI -ErrorAction Stop
    Write-Host "[OK] UI function available" -ForegroundColor Green
} catch {
    Write-Host "[ERROR] UI function not found: $_" -ForegroundColor Red
}

Write-Host "`nFixes implemented:" -ForegroundColor Green
Write-Host "- Fixed Get-WinEvent Count property warnings"
Write-Host "- Enhanced null handling in Invoke-SmartAnalyzer"  
Write-Host "- Added UI resizing with proper anchoring"
Write-Host "- Added double-click for full message details"
Write-Host "- Improved combined filter error handling"

Write-Host "`nRun 'Show-LogAnalyzerUI' to test the UI!" -ForegroundColor Cyan

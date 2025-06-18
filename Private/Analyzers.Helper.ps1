# Detect current OS platform
function Get-Platform {
    if ($IsWindows) {
        return "Windows"
    } else {
        return "Linux"
    }
}

# Load custom parsing rules from config file
function Get-CustomParsingRules {
    $configPath = Join-Path $PSScriptRoot '..\theme.config'
    if (-not (Test-Path $configPath)) {
        return @()
    }

    $lines = Get-Content $configPath | Where-Object { $_ -match '^ParseRegex\d+=' }
    $rules = @()

    foreach ($line in $lines) {
        if ($line -match '^ParseRegex\d+=(?<regex>.+)$') {
            $rules += $matches['regex']
        }
    }

    return $rules
}

# Try to match a line to a custom rule
function Test-CustomParse {
    param (
        [string]$Line,
        [string[]]$RegexPatterns
    )

    foreach ($pattern in $RegexPatterns) {
        if ($Line -match $pattern) {
            return [PSCustomObject]@{
                Timestamp = if ($matches['Time']) { $matches['Time'] } else { $null }
                Level     = if ($matches['Level']) { $matches['Level'] } else { 'Info' }
                Provider  = if ($matches['Source']) { $matches['Source'] } else { 'Unknown' }
                Message   = if ($matches['Message']) { $matches['Message'] } else { $Line }
            }
        }
    }

    return $null
}

# Convert raw log line to timestamp object
function Convert-ToTimestamp {
    param (
        [Parameter(Mandatory)]
        [string]$Line
    )

    if ($Line -match '^(?<Time>\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})') {
        return [datetime]::ParseExact($matches['Time'], 'yyyy-MM-dd HH:mm:ss', $null)
    } elseif ($Line -match '^(?<Month>\w{3}) +(?<Day>\d{1,2}) (?<Time>\d{2}:\d{2}:\d{2})') {
        $year = (Get-Date).Year
        $dateStr = "$($matches['Month']) $($matches['Day']) $year $($matches['Time'])"
        return [datetime]::ParseExact($dateStr, 'MMM dd yyyy HH:mm:ss', $null)
    }

    return $null
}

# Convert a log line to a structured object
function Convert-LogLine {
    param (
        [Parameter(Mandatory)]
        [string]$Line
    )

    $customRules = Get-CustomParsingRules
    $customResult = Test-CustomParse -Line $Line -RegexPatterns $customRules
    if ($customResult) { return $customResult }

    if ($Line -match '^(?<Time>[\d\-:\s]+) \[(?<Level>[^\]]+)\] (?<Provider>[^:]+): (?<Message>.+)$') {
        return [PSCustomObject]@{
            Timestamp = [datetime]::ParseExact($matches['Time'], 'yyyy-MM-dd HH:mm:ss', $null)
            Level     = $matches['Level']
            Provider  = $matches['Provider']
            Message   = $matches['Message']
        }
    }

    if ($Line -match '^(?<Month>\w{3}) +(?<Day>\d{1,2}) (?<Time>\d{2}:\d{2}:\d{2}) (?<Host>\S+) (?<Source>[^:]+): (?<Message>.+)$') {
        $year = (Get-Date).Year
        $datetime = "$($matches['Month']) $($matches['Day']) $year $($matches['Time'])"
        return [PSCustomObject]@{
            Timestamp = [datetime]::ParseExact($datetime, 'MMM dd yyyy HH:mm:ss', $null)
            Level     = 'Info'
            Provider  = $matches['Source']
            Message   = $matches['Message']
        }
    }

    return $null
}

# Select lines based on include/exclude keywords
function Select-LogLines {
    param (
        [string[]]$Lines,
        [string[]]$IncludeKeywords = @(),
        [string[]]$ExcludeKeywords = @()
    )

    $filtered = $Lines

    if ($IncludeKeywords.Count -gt 0) {
        $filtered = $filtered | Where-Object {
            $line = $_
            ($IncludeKeywords | Where-Object { $line -match $_ }).Count -gt 0
        }
    }

    if ($ExcludeKeywords.Count -gt 0) {
        $filtered = $filtered | Where-Object {
            $line = $_
            ($ExcludeKeywords | Where-Object { $line -match $_ }).Count -eq 0
        }
    }

    return $filtered
}

# Reverse array of lines (used for reverse sorting)
function Convert-LinesOrder {
    param (
        [string[]]$Lines
    )
    return [System.Linq.Enumerable]::Reverse($Lines)
}

# Utility messages
function Write-Info {
    param ([string]$Message)
    Write-Host "ℹ️  $Message" -ForegroundColor Cyan
}

function Write-WarningMessage {
    param ([string]$Message)
    Write-Warning "⚠️  $Message"
}

function Write-ErrorMessage {
    param ([string]$Message)
    Write-Host "❌  $Message" -ForegroundColor Red
}
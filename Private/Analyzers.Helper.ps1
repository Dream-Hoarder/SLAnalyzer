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
# SIG # Begin signature block
# MIIFsAYJKoZIhvcNAQcCoIIFoTCCBZ0CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCC7f67zEHMUE0Nr
# cFBMynHWKyTmQuZdo5WsU6f4PQg7xaCCAxwwggMYMIICAKADAgECAhAVMtqhUrdy
# mkjK9MI220b3MA0GCSqGSIb3DQEBCwUAMCQxIjAgBgNVBAMMGVNtYXJ0TG9nQW5h
# bHl6ZXIgRGV2IENlcnQwHhcNMjUwNjE4MjIxMTA3WhcNMjYwNjE4MjIzMTA3WjAk
# MSIwIAYDVQQDDBlTbWFydExvZ0FuYWx5emVyIERldiBDZXJ0MIIBIjANBgkqhkiG
# 9w0BAQEFAAOCAQ8AMIIBCgKCAQEAzLQdDt7qLciu6u2CtXOuwfSDoMKY73xMjh7l
# AcWWteWEvv9zLo6zQ02uHX5Xgz+dLyNhYs0kqQor4s8DkSRRQXzr90IENyL5LG5B
# sMyFhhmmUjA4QFQxgn5exm4DI56hNw/VrDKTkGUvHE2SAai7spZBSkU6hXe2+aEj
# Ld9vdbJc5gS0iGQ+XIF6oJUB3owuQE+30WFZaGpqtHfS8jtxkwUsfwxM1Y2AK+Zj
# Mv1P+njfhVDbfIsXS051dtXbeE5ClEu5XINZP7zVXy4XEsGo/br/cA3OubbEzEJW
# SnPVuuZGsw4SoM3RJx0MVPZG4vd2YLZDKiJYqv3uJBgQi4LYhQIDAQABo0YwRDAO
# BgNVHQ8BAf8EBAMCB4AwEwYDVR0lBAwwCgYIKwYBBQUHAwMwHQYDVR0OBBYEFEOg
# ZC7C7IdkMQsB+4Eti+0plKQ1MA0GCSqGSIb3DQEBCwUAA4IBAQDJ+i2wjjPtCzjF
# hrZw0IfpPcOOy/1fQXAryX52thXIA/Wcb+6qi5WmEpHZtZTxnZ3qyIkRpGa0NsuH
# BlYu0HlTN9Y6JA25gdiOQ9idDpUbpOz+gfD/t9vs0+cQC664l7mnFqHGXRrSsC4N
# zLYnde5ROU3NWfUkZyEsftBk0IghIi4qvJXAW3ic6dDQdq4rEpuUrI+pa2R2h1nE
# sjkv2ru5yL58u8zS7enQ4XGMJRfcow4yyS55a3tQYtnZzCyWS7AeYkbTTjzE4Oxg
# p31zzX01eYEundHvZAxoLg7QENvbqWiFwkbx7ssc/6ehiwOapNUhJTOB1glNAqX/
# rGRwMRitMYIB6jCCAeYCAQEwODAkMSIwIAYDVQQDDBlTbWFydExvZ0FuYWx5emVy
# IERldiBDZXJ0AhAVMtqhUrdymkjK9MI220b3MA0GCWCGSAFlAwQCAQUAoIGEMBgG
# CisGAQQBgjcCAQwxCjAIoAKAAKECgAAwGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcC
# AQQwHAYKKwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIE
# IGCbw0M9Zipn3kds3R60x3Vwaby6SQ9IY98zr4EOmk8NMA0GCSqGSIb3DQEBAQUA
# BIIBALudzBl5IizhkfJcRCFEm5qbFrCCc9Vj2Pf27ZSE5SlxY/IdkrH6ALaMgZKB
# sxiDH7/W0uHA6tostlxmit8MDTaI0t1joABGj28uiySt/oZqwnkP5WzlKwa+VK0m
# +rgzRPSKwNBJotVmOr6TLMUq5yL4ts5V3MGe6CSllHyw2obGnE35DzvA/CJgJ9TP
# B+sUvcLLTS9h5g7PZoKGOFfq61yUnCFtomCWhSPysto5x+cbMTUprFBzPbOuzgbD
# eFDt5ax4zoLQj3NFLwKrjCRZ2pS/P65O/ERAaHYyeI55miSXiO6sr0ESkOaNS23z
# hI2901exh1wpgTqh486cQQMNlmg=
# SIG # End signature block

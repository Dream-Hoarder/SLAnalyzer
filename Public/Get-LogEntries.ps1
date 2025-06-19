function Get-LogEntries {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$Path,

        [string[]]$IncludeKeywords = @(),
        [string[]]$ExcludeKeywords = @(),
        [datetime]$StartTime,
        [datetime]$EndTime,

        [ValidateSet("Forward", "Reverse")]
        [string]$SortOrder = "Forward",

        [int[]]$EventId,
        [string[]]$Level,
        [string[]]$ProviderName,

        [string]$ExportPath,

        [ValidateSet("CSV", "JSON")]
        [string]$ExportFormat = "CSV",

        [int]$Tail,
        [int]$LineLimit
    )

    if (-not (Test-Path $Path) -and ($Path -ne 'journalctl')) {
        throw [System.IO.FileNotFoundException]::new("File not found: $Path", $Path)
    }

    $entries = @()

    # Windows Event Log Parsing
    if ($Path -match '\.(evtx|evt)$') {
        if (-not $IsWindows) {
            throw "❌ Windows event log parsing is only supported on Windows."
        }

        try {
            $events = Get-WinEvent -Path $Path -Oldest

            if ($StartTime) { $events = $events | Where-Object { $_.TimeCreated -ge $StartTime } }
            if ($EndTime)   { $events = $events | Where-Object { $_.TimeCreated -le $EndTime } }
            if ($EventId)   { $events = $events | Where-Object { $EventId -contains $_.Id } }
            if ($Level)     { $events = $events | Where-Object { $Level -contains $_.LevelDisplayName } }
            if ($ProviderName) { $events = $events | Where-Object { $ProviderName -contains $_.ProviderName } }

            if ($SortOrder -eq "Reverse") {
                $events = $events | Sort-Object TimeCreated -Descending
            }

            $entries = $events | ForEach-Object {
    "$($_.TimeCreated.ToString('yyyy-MM-dd HH:mm:ss')) [$($_.LevelDisplayName)] $($_.ProviderName): Event ID $($_.Id) - $($_.Message)"
}

        } catch {
            throw "❌ Failed to parse EVT/EVTX file: $_"
        }

    } elseif ($Path -eq 'journalctl' -and !$IsWindows) {
        # journalctl support (Linux only)
        try {
            $cmd = "journalctl --no-pager"
            if ($StartTime) { $cmd += " --since '$($StartTime.ToString("yyyy-MM-dd HH:mm:ss"))'" }
            if ($EndTime) { $cmd += " --until '$($EndTime.ToString("yyyy-MM-dd HH:mm:ss"))'" }
            $entries = bash -c $cmd
        } catch {
            throw "❌ Failed to retrieve journalctl entries: $_"
        }
    } else {
        try {
            $entries = Get-Content -Path $Path -Encoding UTF8 -ErrorAction Stop
        } catch {
            throw "❌ Failed to read text log: $_"
        }

        if ($SortOrder -eq "Reverse") {
            $entries = $entries | Sort-Object { [array]::IndexOf($entries, $_) } -Descending
        }

        if ($StartTime -or $EndTime) {
            $entries = $entries | Where-Object {
                if ($_ -match '^(?<Time>\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})') {
                    try {
                        $logTime = [datetime]::ParseExact($matches.Time, 'yyyy-MM-dd HH:mm:ss', $null)
                        (!($StartTime) -or $logTime -ge $StartTime) -and
                        (!($EndTime) -or $logTime -le $EndTime)
                    } catch { $false }
                } else { $false }
            }
        }
    }

    # Keyword filtering
    if ($IncludeKeywords.Count -gt 0) {
        $pattern = ($IncludeKeywords -join '|')
        $entries = $entries | Where-Object { $_ -match $pattern }
    }

    if ($ExcludeKeywords.Count -gt 0) {
        $pattern = ($ExcludeKeywords -join '|')
        $entries = $entries | Where-Object { $_ -notmatch $pattern }
    }

    if ($Tail) {
        $entries = $entries | Select-Object -Last $Tail
    } elseif ($LineLimit) {
        $entries = $entries | Select-Object -First $LineLimit
    }

    # Log Summary
    try {
        $summary = Get-LogSummary -LogLines $entries
        Write-Host "`n=== LOG SUMMARY ===" -ForegroundColor Cyan
        $summary | Format-List
    } catch {
        Write-Warning "⚠️ Get-LogSummary failed or not available."
    }

    # Export
    if ($ExportPath) {
        try {
            if ($ExportFormat -eq "CSV") {
                $entries | ForEach-Object { [PSCustomObject]@{ Entry = $_ } } |
                    Export-Csv -Path $ExportPath -NoTypeInformation -Force
            } elseif ($ExportFormat -eq "JSON") {
                $entries | ForEach-Object { [PSCustomObject]@{ Entry = $_ } } |
                    ConvertTo-Json -Depth 3 | Out-File -FilePath $ExportPath -Encoding UTF8
            }
            Write-Host "✅ Log entries exported to $ExportPath" -ForegroundColor Green
        } catch {
            Write-Warning "❌ Failed to export: $_"
        }
    }

    return $entries
}
# SIG # Begin signature block
# MIIFsAYJKoZIhvcNAQcCoIIFoTCCBZ0CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCf933LatLoxQDQ
# xl0TOEmNiP19Egru37/vP+8Xyka0aKCCAxwwggMYMIICAKADAgECAhAVMtqhUrdy
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
# IA4ERPD5r8ILqc81HC+qxqR/tvgf8apx8wqcsvdFxrocMA0GCSqGSIb3DQEBAQUA
# BIIBAB79HhOZNdJ0QSKT/5S8E62XeWjDEyf64mQgdDZ+bY+CnpH7m2bVtJwGdOqu
# MJBJ77BQg91u7w/28lhGkEXbjQ7J+a0Ck5+20vGaeTGAqkPo5/KGYtaEtWScpGSD
# v72a85Wi6P3ogCRMqMIY5L9QGfAVyxxnfmvLLRKadvLx2Ve/HRERliBiiNyf9ftN
# g4qn0fz+tDJCVFLwSzQGgktAR4SIpq6ZarxZyaJLUUv56Gly7ikgQiXOCArpFYHM
# EkuUUlaC7/AYcNnKzaQ5gqV0Ae+jngdlriOS5XvHfa9sXOuF4MsHKwVDq0QR9QvK
# wrI22M9i+pbgHuP1qEz/0mVdcR4=
# SIG # End signature block

function Get-LogSummary {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string[]]$LogLines
    )

    $summary = [ordered]@{
        TotalLines     = 0
        ErrorCount     = 0
        WarningCount   = 0
        InfoCount      = 0
        DebugCount     = 0
        FatalCount     = 0
        OtherCount     = 0
        FirstTimestamp = $null
        LastTimestamp  = $null
    }

    if (-not $LogLines) {
        return [pscustomobject]$summary
    }

    $timestamps = @()
    $datetimeFormats = @(
        'yyyy-MM-dd HH:mm:ss',
        'yyyy-MM-ddTHH:mm:ss',
        'yyyy-MM-ddTHH:mm:ssZ',
        'yyyy-MM-ddTHH:mm:ss.fffZ',
        'yyyy-MM-ddTHH:mm:sszzz',
        'MMM dd yyyy HH:mm:ss'
    )

    foreach ($line in $LogLines) {
        $summary.TotalLines++

        switch -Regex ($line) {
            'fatal' { $summary.FatalCount++ }
            'error' { $summary.ErrorCount++ }
            'warn'  { $summary.WarningCount++ }
            'info'  { $summary.InfoCount++ }
            'debug' { $summary.DebugCount++ }
            default { $summary.OtherCount++ }
        }

        if ($line -match '(\d{4}-\d{2}-\d{2}[ T]\d{2}:\d{2}:\d{2}(?:[\.,]\d+)?(?:Z|[\+\-]\d{2}:\d{2})?)') {
            $timestampCandidate = $matches[1]
            foreach ($fmt in $datetimeFormats) {
                try {
                    $parsed = [datetime]::ParseExact($timestampCandidate, $fmt, $null)
                    $timestamps += $parsed
                    break
                } catch {
                    # Continue trying formats
                }
            }
        }
    }

    if ($timestamps.Count -gt 0) {
        $sorted = $timestamps | Sort-Object
        $summary.FirstTimestamp = $sorted[0]
        $summary.LastTimestamp  = $sorted[-1]
    }

    return [pscustomobject]$summary
}

# SIG # Begin signature block
# MIIFsAYJKoZIhvcNAQcCoIIFoTCCBZ0CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCAlDCM4AbqiIsiI
# 1YKz/IkZHx/t7EI3be0CwwEMrc4rOqCCAxwwggMYMIICAKADAgECAhAVMtqhUrdy
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
# IJBiCH1z/sDOA5HKH1xo2yEVz9AI2xXJdJwd58CjgVl5MA0GCSqGSIb3DQEBAQUA
# BIIBAFUbEaccIVj8MujSiwg/nSawbqkOnOhclxUv+dU8I3qYK1972QznUECpFCie
# EQdK9aukxyUO59LrXcKB2Vt5UsLOXmhuvGso0pVJO8Gl6ztmFdeCnqYLeRdo5eEK
# qG/0HLcFjnrcYlZbGNYZr33ZbPMnerokVrMACj4/NrAKvM1/ozTJKVIsZqie5JZj
# rI2DA7jKCVNu2EajLno9xbu3/FSBNA6NEXnxqZM8KhiYbGVny86x1FIDElEr8f5A
# 2poy7VoLb7lqf6ZLyJoZ82nUcAUtpzOjyXHRnc+gagyywFEG2VKF4XJ5lDipUl7V
# GB0qs0oaWB2Dc+3IZXjV+vhb150=
# SIG # End signature block

function Convert-Timestamp {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$Line
    )

    # Try matching a timestamp first
    if ($Line -match '(\d{4}-\d{2}-\d{2}[ T]\d{2}:\d{2}:\d{2}(?:Z|[\+\-]\d{2}:\d{2})?)') {
        $rawTimestamp = $matches[1]

        $formats = @(
            'yyyy-MM-dd HH:mm:ss',
            'yyyy-MM-ddTHH:mm:ss',
            'yyyy-MM-ddTHH:mm:ssZ',
            'yyyy-MM-ddTHH:mm:sszzz'
        )

        foreach ($fmt in $formats) {
            $parsed = $null
            if ([datetime]::TryParseExact($rawTimestamp, $fmt, $null, [System.Globalization.DateTimeStyles]::None, [ref]$parsed)) {
                return $parsed
            }
        }
    }

    # Syslog format: "Jun 12 14:35:00"
    if ($Line -match '^(?<Month>\w{3}) +(?<Day>\d{1,2}) (?<Time>\d{2}:\d{2}:\d{2})') {
        $year = (Get-Date).Year
        $dateStr = "$($matches['Month']) $($matches['Day']) $year $($matches['Time'])"
        return [datetime]::ParseExact($dateStr, 'MMM dd yyyy HH:mm:ss', $null)
    }

    return $null
}

# SIG # Begin signature block
# MIIFsAYJKoZIhvcNAQcCoIIFoTCCBZ0CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCAzoA6BUNfyCIF3
# tRbZCSbrDNvyoP0aefsUZ1y3vLm4MKCCAxwwggMYMIICAKADAgECAhAVMtqhUrdy
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
# IPoKHiCPkQk27vnOzEAHsVxssInQUhsCI6vfc+rU+rmAMA0GCSqGSIb3DQEBAQUA
# BIIBAJLhdhzj8Qi2cWjt5rP26NlL7VPRq62NTPth60j8hxs27oUnGKUGFX/dmYOo
# WS/sSxDuDWe9iAb7bQdgSgVq/1utfpNSwn/3bdfkml01ioOeX8bv1Fz2/X79ktjK
# pNJl/LchvZscS4dOCxQCuIgfWjKZNW7zP4UvyYytOISTwNXWMV99J9ny4dDq2/yZ
# xleFJ6k+zYDpZX7gzIONN2oUkC+d1UlFiNkhH1aGMZEM9l1C/T9ZMUG7CpBQdXot
# X+nxaUYRc2tA1rqvwCgTSb/cGj+V4kQ34zkTqobjxUcxFFG/ECCAyDChPzgDeZcd
# vH7UfANzNFjaQd8HQjDzRXtlcNw=
# SIG # End signature block

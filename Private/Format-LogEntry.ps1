function Format-LogEntry {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$Line,

        [string[]]$CustomPatterns = @()
    )

    # Try custom regex rules from config or input
    foreach ($pattern in $CustomPatterns) {
        if ($Line -match $pattern) {
            return [PSCustomObject]@{
                Timestamp = if ($matches['Time']) { $matches['Time'] } else { $null }
                Level     = if ($matches['Level']) { $matches['Level'] } else { 'Info' }
                Provider  = if ($matches['Source']) { $matches['Source'] } else { 'Unknown' }
                Message   = if ($matches['Message']) { $matches['Message'] } else { $Line }
            }
        }
    }

    # Fallback 1: SmartLogAnalyzer default format
    if ($Line -match '^(?<Time>[\d\-\s:]+) \[(?<Level>[^\]]+)\] (?<Provider>[^:]+): (?<Message>.+)$') {
        return [PSCustomObject]@{
            Timestamp = [datetime]::ParseExact($matches['Time'], 'yyyy-MM-dd HH:mm:ss', $null)
            Level     = $matches['Level']
            Provider  = $matches['Provider']
            Message   = $matches['Message']
        }
    }

    # Fallback 2: Syslog-like format
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

    # No match fallback
    return $null
}

# SIG # Begin signature block
# MIIFsAYJKoZIhvcNAQcCoIIFoTCCBZ0CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCruci4RLwVGVD+
# aWQXLjVUlv97G0Mfad3OEYHmlH49rqCCAxwwggMYMIICAKADAgECAhAVMtqhUrdy
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
# IATUb9jNcFC2THaUqFvV5xKBrRSZnVVyD0yKQitkQsbvMA0GCSqGSIb3DQEBAQUA
# BIIBAB1smV9yPOC88cXQs6aDy1j25EJW26JgxJiCwCfocCD/tCR0R/+UPXFY6Lpt
# 98LjzppJpF3MBQcfa645SrjeVIFvH22cWKdb+1B7n2GUmM/+978dOur/MmXJ9Kh4
# Xltm84KLJ/pAQ3fr+IM5TkF1Gx33YP9KXHetMa/gpyBl0exfN/rY72M+1RCPnAKN
# 0Duxr294f+Ddl21kML17FoR4lrJGEKsWCQuAGvQxYzL9YpbKQ02DmQnRtYrMc6HV
# x37cavtp6GrmpNtr7aj8G6KuJcsuVilylbjL3umu/Ye/VUCG+28nAf4INVGyu26E
# yD92GOSX+zEvAcVjdMfYHFxwCSI=
# SIG # End signature block

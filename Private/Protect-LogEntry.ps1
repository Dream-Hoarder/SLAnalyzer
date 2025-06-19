function Protect-LogEntry {
    [CmdletBinding()]
    param (
        [pscustomobject]$Entry,
        [ref]$RedactionLog
    )

    $copy = $Entry.PSObject.Copy()

    # Redact username
    if ($copy.UserName -match '\S') {
        $RedactionLog.Value.Add("UserName: $($copy.UserName)")
        $copy.UserName = '[REDACTED]'
    }

    # Redact IP addresses
    if ($copy.Message -match '\b\d{1,3}(\.\d{1,3}){3}\b') {
        $ipMatch = [regex]::Match($copy.Message, '\b\d{1,3}(\.\d{1,3}){3}\b')
        if ($ipMatch.Success) {
            $RedactionLog.Value.Add("IP Address: $($ipMatch.Value)")
            $copy.Message = $copy.Message -replace $ipMatch.Value, '[REDACTED]'
        }
    }

    # Redact email
    if ($copy.Email -match '\b\S+@\S+\.\S+\b') {
        $RedactionLog.Value.Add("Email: $($copy.Email)")
        $copy.Email = '[REDACTED]'
    }

    return $copy
}

# SIG # Begin signature block
# MIIFsAYJKoZIhvcNAQcCoIIFoTCCBZ0CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCAbMMOgAq/Bj4Sm
# 1SM/3EKqkm0nwoq45r4IeYYzs/5ooaCCAxwwggMYMIICAKADAgECAhAVMtqhUrdy
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
# IFalnt4sliN5g5UetbtPW1ncH/UKFLY4zTD1dSsv3OCJMA0GCSqGSIb3DQEBAQUA
# BIIBALAu0cbuFCwiSFCn7/aVvwV9Mbx+mgqWmTX/Vw9PYMVrd/Tf7xaIKfUD8Jfj
# AuDuNFXA/iCXBJCC3htVE6He5Q+nyXqJOj9dsAB90bEkjzANIugsRAkuOFiBGy/e
# yVUda+SxWvYdSAK6TCEJOVByPOUSrRJETmALQndTe0prFu7dSpJFqnz1aa1LQDY8
# 9tAo4eyD4JtP0SAa9V6gd102O6ZmcY+c6+lUVXFhD5J5WQOF/syL5jRmFGYvCIbh
# h5F9PCmthfeNLmR71qbWBXro1Lt+B6eStIysWXEYMI4wJ0J0bcjKkgvcZi6kvGy7
# W/q38nkqzB5zClGdPOZ+9CjvmTo=
# SIG # End signature block

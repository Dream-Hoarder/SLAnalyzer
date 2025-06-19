function Export-LogReport {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [hashtable]$Summary,

        [Parameter(Mandatory)]
        [array]$Entries,

        [Parameter(Mandatory)]
        [string]$SourcePath,

        [Parameter(Mandatory)]
        [string]$OutputPath,

        [ValidateSet("Text", "Json", "Csv", "Html")]
        [string]$Format = "Text",

        [switch]$Redact,
        [switch]$IncludeMetadata,
        [switch]$GenerateRedactionLog
    )

    $moduleVersion = '1.0.0'
    $timestamp = Get-Date -Format 'yyyy-MM-ddTHH:mm:ssZ'
    $metadata = @{
        GeneratedAt   = $timestamp
        ModuleVersion = $moduleVersion
        SourceFile    = $SourcePath
        EntryCount    = $Entries.Count
    }

    # Prepare redaction log (by reference)
    $redactionLogRef = [ref](New-Object System.Collections.Generic.List[string])

    if ($Redact) {
        $Entries = $Entries | ForEach-Object { Protect-LogEntry -Entry $_ -RedactionLog $redactionLogRef }
    }

    if ($GenerateRedactionLog -and $Redact -and $redactionLogRef.Value.Count -gt 0) {
        $logPath = [System.IO.Path]::Combine((Split-Path -Path $OutputPath), 'redaction-log.txt')
        $logContent = @(
            "SmartLogAnalyzer Redaction Log - $timestamp",
            "Source File: $SourcePath",
            "Redacted Fields:",
            ""
        ) + $redactionLogRef.Value
        $logContent | Out-File -FilePath $logPath -Encoding UTF8
        Write-Host "🛡️ Redaction log saved to: $logPath" -ForegroundColor DarkYellow
    }

    switch ($Format) {
        "Json" {
            $report = @{
                Metadata = $IncludeMetadata ? $metadata : $null
                Summary  = $Summary
                Entries  = $Entries
            } | ConvertTo-Json -Depth 5
            $report | Out-File -FilePath $OutputPath -Encoding UTF8
        }

        "Csv" {
            $Entries | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8
        }

        "Text" {
            $lines = @()
            if ($IncludeMetadata) {
                $lines += "# SmartLogAnalyzer Report"
                $lines += "Generated At: $timestamp"
                $lines += "Source: $SourcePath"
                $lines += "Entries: $($Entries.Count)"
                $lines += "Version: $moduleVersion"
                $lines += ""
            }

            $lines += "=== Summary ==="
            foreach ($key in $Summary.Keys) {
                $lines += "$key : $($Summary[$key])"
            }

            $lines += ""
            $lines += "=== Log Entries ==="
            foreach ($entry in $Entries) {
                $lines += ($entry | Out-String).Trim()
                $lines += "-" * 40
            }

            $lines | Out-File -FilePath $OutputPath -Encoding UTF8
        }

        "Html" {
            $html = @"
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>SmartLogAnalyzer Report</title>
    <style>
        body { font-family: Consolas, monospace; padding: 1em; background: #f4f4f4; }
        h1 { color: #333; }
        table { border-collapse: collapse; width: 100%; }
        th, td { border: 1px solid #999; padding: 5px; text-align: left; }
        th { background-color: #eee; }
    </style>
</head>
<body>
<h1>SmartLogAnalyzer Report</h1>
<p><strong>Generated:</strong> $timestamp<br>
<strong>Source:</strong> $SourcePath<br>
<strong>Entries:</strong> $($Entries.Count)<br>
<strong>Version:</strong> $moduleVersion</p>

<h2>Summary</h2>
<ul>
"@
            foreach ($key in $Summary.Keys) {
                $value = $Summary[$key]
                $html += "<li><strong>$key</strong>: $value</li>"
            }

            $html += "</ul><h2>Entries</h2><table><thead><tr>"
            $props = $Entries[0].PSObject.Properties.Name
            foreach ($p in $props) { $html += "<th>$p</th>" }

            $html += "</tr></thead><tbody>"

            foreach ($entry in $Entries) {
                $html += "<tr>"
                foreach ($p in $props) {
                    $v = $entry.$p -replace '<', '&lt;' -replace '>', '&gt;'
                    $html += "<td>$v</td>"
                }
                $html += "</tr>"
            }

            $html += "</tbody></table></body></html>"

            $html | Out-File -FilePath $OutputPath -Encoding UTF8
        }

        default {
            throw "Unsupported format: $Format"
        }
    }

    Write-Verbose "Report exported: $OutputPath"
}

# SIG # Begin signature block
# MIIFsAYJKoZIhvcNAQcCoIIFoTCCBZ0CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCC1iz1swtZS+la
# KXUmonNqs450PZXXN0S3xa/rQVtGAKCCAxwwggMYMIICAKADAgECAhAVMtqhUrdy
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
# ID8yOFQXW0a1Zf6YbZ1MYT8crQUbynU8aR3aXjT+Y1MSMA0GCSqGSIb3DQEBAQUA
# BIIBAHz1uo4Vz8AauRe4iLurlbNX4dZjSTDw/zX+NCkFDmia0md7Qn2RXcfRqH8d
# kZR+Gi7CBR3Stj+QgxcJkFAJuCL+54tl/7rQLJgjlrmAabzIQh0amJZBblW8HSbG
# 3njDrOPFKwuB4ZNiIUHSSUy0YSBNdMCLP+2QnL4J/mENJiOgxsPCCiu7swhnewv3
# Hiw6bxs/VUiTMVWcpNYc3jbPxMtb814JZ1OssbM6e6I4+58hb+eF6ivrZNu4i5ZG
# WFFE4HjZHLE8c1raXKBuieYx9lU1KXRdCDulk1wdjSH9GpGs6jpvv/XKBTVu6HFt
# LMcC+S9mxqUc7P4YUjT9Vp2SOfA=
# SIG # End signature block

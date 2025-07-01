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


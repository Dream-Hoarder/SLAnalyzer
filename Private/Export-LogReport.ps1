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

    try {
        $moduleVersion = '1.0.0'
        $timestamp = Get-Date -Format 'yyyy-MM-ddTHH:mm:ssZ'
        $metadata = @{
            GeneratedAt   = $timestamp
            ModuleVersion = $moduleVersion
            SourceFile    = $SourcePath
            EntryCount    = $Entries.Count
        }

        # Validate and create output directory if needed
        $outputDir = Split-Path -Path $OutputPath -Parent
        if ($outputDir -and !(Test-Path -Path $outputDir)) {
            Write-Verbose "Creating output directory: $outputDir"
            New-Item -Path $outputDir -ItemType Directory -Force | Out-Null
        }

        # Prepare redaction log (by reference)
        $redactionLogRef = [ref](New-Object System.Collections.Generic.List[string])

        if ($Redact) {
            Write-Progress -Activity "Exporting log report" -Status "Applying redaction" -PercentComplete 25
            $Entries = $Entries | ForEach-Object { Protect-LogEntry -Entry $_ -RedactionLog $redactionLogRef }
        }

        if ($GenerateRedactionLog -and $Redact -and $redactionLogRef.Value.Count -gt 0) {
            try {
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
            catch {
                Write-Warning "Failed to create redaction log: $_"
            }
        }

        Write-Progress -Activity "Exporting log report" -Status "Generating $Format report" -PercentComplete 50

        switch ($Format) {
            "Json" {
                try {
                    $report = @{
                        Metadata = if ($IncludeMetadata) { $metadata } else { $null }
                        Summary  = $Summary
                        Entries  = $Entries
                    } | ConvertTo-Json -Depth 5
                    $report | Out-File -FilePath $OutputPath -Encoding UTF8
                }
                catch {
                    throw "Failed to export JSON report: $_"
                }
            }

            "Csv" {
                try {
                    if ($Entries.Count -eq 0) {
                        Write-Warning "No entries to export to CSV"
                        "# No log entries found" | Out-File -FilePath $OutputPath -Encoding UTF8
                    }
                    else {
                        $Entries | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8
                    }
                }
                catch {
                    throw "Failed to export CSV report: $_"
                }
            }

            "Text" {
                try {
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
                    
                    if ($Entries.Count -eq 0) {
                        $lines += "No log entries found"
                    }
                    else {
                        foreach ($entry in $Entries) {
                            $lines += ($entry | Out-String).Trim()
                            $lines += "-" * 40
                        }
                    }

                    $lines | Out-File -FilePath $OutputPath -Encoding UTF8
                }
                catch {
                    throw "Failed to export text report: $_"
                }
            }

            "Html" {
                try {
                    $html = Get-HtmlTemplate -Timestamp $timestamp -SourcePath $SourcePath -EntryCount $Entries.Count -ModuleVersion $moduleVersion

                    # Add summary section
                    foreach ($key in $Summary.Keys) {
                        $value = Format-HtmlString -InputString $Summary[$key]
                        $html += "<li><strong>$(Format-HtmlString -InputString $key)</strong>: $value</li>"
                    }

                    $html += "</ul><h2>Entries</h2>"

                    if ($Entries.Count -eq 0) {
                        $html += "<p>No entries to display</p></body></html>"
                    }
                    else {
                        $html += "<table><thead><tr>"
                        $props = $Entries[0].PSObject.Properties.Name
                        foreach ($p in $props) { 
                            $html += "<th>$(Format-HtmlString -InputString $p)</th>" 
                        }

                        $html += "</tr></thead><tbody>"

                        foreach ($entry in $Entries) {
                            $html += "<tr>"
                            foreach ($p in $props) {
                                $v = if ($null -eq $entry.$p) { '' } else { $entry.$p.ToString() }
                                $v = Format-HtmlString -InputString $v
                                $html += "<td>$v</td>"
                            }
                            $html += "</tr>"
                        }

                        $html += "</tbody></table>"
                    }

                    $html += "</body></html>"
                    $html | Out-File -FilePath $OutputPath -Encoding UTF8
                }
                catch {
                    throw "Failed to export HTML report: $_"
                }
            }

            default {
                throw "Unsupported format: $Format"
            }
        }

        Write-Progress -Activity "Exporting log report" -Status "Complete" -PercentComplete 100 -Completed
        Write-Verbose "Report exported successfully: $OutputPath"
        Write-Host "✅ Report exported to: $OutputPath" -ForegroundColor Green
    }
    catch {
        Write-Progress -Activity "Exporting log report" -Completed
        Write-Error "Export failed: $_"
        throw
    }
}

# Helper function for HTML template
function Get-HtmlTemplate {
    param(
        [string]$Timestamp,
        [string]$SourcePath,
        [int]$EntryCount,
        [string]$ModuleVersion
    )
    
    $escapedSourcePath = Format-HtmlString -InputString $SourcePath
    
    return @"
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>SmartLogAnalyzer Report</title>
    <style>
        body { 
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; 
            padding: 2em; 
            background: #f8f9fa; 
            color: #333;
            line-height: 1.6;
        }
        .header { 
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 2em;
            border-radius: 8px;
            margin-bottom: 2em;
        }
        h1 { 
            margin: 0;
            font-size: 2.5em;
            font-weight: 300;
        }
        .metadata {
            background: rgba(255,255,255,0.1);
            padding: 1em;
            border-radius: 4px;
            margin-top: 1em;
        }
        h2 { 
            color: #495057;
            border-bottom: 2px solid #dee2e6;
            padding-bottom: 0.5em;
        }
        table { 
            border-collapse: collapse; 
            width: 100%; 
            background: white;
            border-radius: 8px;
            overflow: hidden;
            box-shadow: 0 4px 6px rgba(0,0,0,0.1);
        }
        th, td { 
            border: 1px solid #dee2e6; 
            padding: 12px; 
            text-align: left; 
        }
        th { 
            background: #f8f9fa;
            font-weight: 600;
            color: #495057;
        }
        tr:nth-child(even) {
            background-color: #f8f9fa;
        }
        ul {
            background: white;
            padding: 1.5em;
            border-radius: 8px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        li {
            margin-bottom: 0.5em;
        }
    </style>
</head>
<body>
<div class="header">
    <h1>SmartLogAnalyzer Report</h1>
    <div class="metadata">
        <strong>Generated:</strong> $Timestamp<br>
        <strong>Source:</strong> $escapedSourcePath<br>
        <strong>Entries:</strong> $EntryCount<br>
        <strong>Version:</strong> $ModuleVersion
    </div>
</div>

<h2>Summary</h2>
<ul>
"@
}

# Helper function for HTML string escaping
function Format-HtmlString {
    param(
        [string]$InputString
    )
    
    if ([string]::IsNullOrEmpty($InputString)) {
        return ''
    }
    
    return $InputString -replace '&', '&amp;' -replace '<', '&lt;' -replace '>', '&gt;' -replace '"', '&quot;' -replace "'", '&#39;'
}
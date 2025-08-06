function Export-LogReport {
    [CmdletBinding()]
    param (
        [Parameter()]
        [hashtable]$Summary,

        [Parameter()]
        [System.Object[]]$Entries,

        [Parameter()]
        [System.Object[]]$LogLines,  # Alternative parameter name for compatibility

        [Parameter()]
        [string]$SourcePath = "Unknown",

        [Parameter(Mandatory)]
        [string]$OutputPath,

        [ValidateSet("Text", "Json", "Csv", "Html")]
        [string]$Format = "Text",

        [switch]$Redact,
        [switch]$IncludeMetadata,
        [switch]$GenerateRedactionLog
    )

# Handle both Entries and LogLines parameter names for compatibility
if (-not $Entries -and $LogLines) {
    $Entries = $LogLines
}

# Validate that we have data to work with
if (-not $Entries -or $Entries.Count -eq 0) {
    throw "Either Entries or LogLines parameter must contain a non-empty array."
}

# Generate summary if not provided
if (-not $Summary) {
    try {
        Write-Verbose "Generating summary from provided entries..."
        $Summary = @{}
        $summaryObj = Get-LogSummary -LogLines $Entries
        if ($summaryObj) {
            $Summary = @{
                TotalLines = $summaryObj.TotalLines
                ErrorCount = $summaryObj.ErrorCount
                WarningCount = $summaryObj.WarningCount
                InfoCount = $summaryObj.InfoCount
                DebugCount = $summaryObj.DebugCount
                FatalCount = $summaryObj.FatalCount
                OtherCount = $summaryObj.OtherCount
                FirstTimestamp = $summaryObj.FirstTimestamp
                LastTimestamp = $summaryObj.LastTimestamp
            }
        }
    } catch {
        Write-Warning "Failed to generate summary: $($_.Exception.Message)"
        $Summary = @{ Note = "Summary generation failed" }
    }
}


    try {
        $moduleVersion = '1.0.0'
        $timestamp = Get-Date -Format 'yyyy-MM-ddTHH:mm:ssZ'

        $entryCount = if ($Entries) { $Entries.Count } else { 0 }
        $metadata = @{
            GeneratedAt   = $timestamp
            ModuleVersion = $moduleVersion
            SourceFile    = $SourcePath
            EntryCount    = $entryCount
        }

        # Validate and create output directory
        $outputDir = Split-Path -Path $OutputPath -Parent
        if ($outputDir -and !(Test-Path -Path $outputDir)) {
            Write-Verbose "Creating output directory: $outputDir"
            New-Item -Path $outputDir -ItemType Directory -Force | Out-Null
        }

        # Warn if file extension doesn't match format
        $expectedExt = ".$($Format.ToLower())"
        if (-not $OutputPath.ToLower().EndsWith($expectedExt)) {
            Write-Warning "⚠️ Output path extension does not match selected format '$Format'. Expected file extension: '$expectedExt'"
        }

        $redactionLogRef = [ref](New-Object System.Collections.Generic.List[string])
        $entriesToUse = $Entries

        if ($Redact) {
            Write-Progress -Activity "Exporting log report" -Status "Applying redaction" -PercentComplete 25
            $entriesToUse = foreach ($entry in $Entries) {
                Protect-LogEntry -Entry $entry -RedactionLog $redactionLogRef
            }
        }

        if ($GenerateRedactionLog -and $Redact -and $redactionLogRef.Value.Count -gt 0) {
            try {
                $logPath = Join-Path -Path $outputDir -ChildPath 'redaction-log.txt'
                $logContent = @(
                    "SmartLogAnalyzer Redaction Log - $timestamp",
                    "Source File: $SourcePath",
                    "Redacted Fields:",
                    ""
                ) + $redactionLogRef.Value
                $logContent | Out-File -FilePath $logPath -Encoding UTF8
                Write-Host "🛡️ Redaction log saved to: $logPath" -ForegroundColor DarkYellow
            } catch {
                Write-Warning "Failed to create redaction log: $_"
            }
        }

        Write-Progress -Activity "Exporting log report" -Status "Generating $Format report" -PercentComplete 50

        $hasEntries = ($entriesToUse -and $entriesToUse.Count -gt 0)

        switch ($Format) {
            "Json" {
                try {
                    $report = @{
                        Metadata = if ($IncludeMetadata) { $metadata } else { $null }
                        Summary  = $Summary
                        Entries  = $entriesToUse
                    } | ConvertTo-Json -Depth 5
                    $report | Out-File -FilePath $OutputPath -Encoding UTF8
                } catch {
                    throw "Failed to export JSON report: $_"
                }
            }

            "Csv" {
                try {
                    if (-not $hasEntries) {
                        Write-Warning "No entries to export to CSV"
                        "# No log entries found" | Out-File -FilePath $OutputPath -Encoding UTF8
                    } else {
                        $entriesToUse | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8
                    }
                } catch {
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
                        $lines += "Entries: $entryCount"
                        $lines += "Version: $moduleVersion"
                        $lines += ""
                    }

                    $lines += "=== Summary ==="
                    foreach ($key in $Summary.Keys) {
                        $lines += "$key : $($Summary[$key])"
                    }

                    $lines += ""
                    $lines += "=== Log Entries ==="

                    if (-not $hasEntries) {
                        $lines += "No log entries found"
                    } else {
                        foreach ($entry in $entriesToUse) {
                            $lines += ($entry | Out-String).Trim()
                            $lines += "-" * 40
                        }
                    }

                    $lines | Out-File -FilePath $OutputPath -Encoding UTF8
                } catch {
                    throw "Failed to export text report: $_"
                }
            }

            "Html" {
                try {
                    $sb = [System.Text.StringBuilder]::new()
                    $sb.AppendLine((Get-HtmlTemplate -Timestamp $timestamp -SourcePath $SourcePath -EntryCount $entryCount -ModuleVersion $moduleVersion)) | Out-Null

                    foreach ($key in $Summary.Keys) {
                        $value = Format-HtmlString -InputString $Summary[$key]
                        $sb.AppendLine("<li><strong>$(Format-HtmlString -InputString $key)</strong>: $value</li>") | Out-Null
                    }

                    $sb.AppendLine("</ul><h2>Entries</h2>") | Out-Null

                    if (-not $hasEntries) {
                        $sb.AppendLine("<p>No entries to display</p></body></html>") | Out-Null
                    } else {
                        $props = $entriesToUse[0].PSObject.Properties.Name
                        $sb.AppendLine("<table><thead><tr>") | Out-Null
                        foreach ($p in $props) {
                            $sb.AppendLine("<th>$(Format-HtmlString -InputString $p)</th>") | Out-Null
                        }
                        $sb.AppendLine("</tr></thead><tbody>") | Out-Null

                        foreach ($entry in $entriesToUse) {
                            $sb.AppendLine("<tr>") | Out-Null
                            foreach ($p in $props) {
                                $v = if ($null -eq $entry.$p) { '' } else { $entry.$p.ToString() }
                                $sb.AppendLine("<td>$(Format-HtmlString -InputString $v)</td>") | Out-Null
                            }
                            $sb.AppendLine("</tr>") | Out-Null
                        }

                        $sb.AppendLine("</tbody></table></body></html>") | Out-Null
                    }

                    $sb.ToString() | Out-File -FilePath $OutputPath -Encoding UTF8
                } catch {
                    throw "Failed to export HTML report: $_"
                }
            }

            default {
                throw "Unsupported format: $Format"
            }
        }

        Write-Progress -Activity "Exporting log report" -Status "Complete" -PercentComplete 100 -Completed

        if (Test-Path $OutputPath) {
            $file = Get-Item $OutputPath
            $size = [Math]::Round($file.Length / 1KB, 2)
            Write-Host "✅ Report exported to: $($file.FullName) ($size KB)" -ForegroundColor Green
        } else {
            Write-Host "✅ Report exported to: $OutputPath" -ForegroundColor Green
        }
    }
    catch {
        Write-Progress -Activity "Exporting log report" -Completed
        Write-Error "❌ Export failed: $_"
        throw
    }
}

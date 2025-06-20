function Show-LogAnalyzerUI {
    Write-Host "[DEBUG] Starting Show-LogAnalyzerUI"

    if (-not $IsWindows) {
        throw "❌ The Smart Log Analyzer UI is only supported on Windows."
    }

    try {
        Write-Host "[DEBUG] Loading Windows Forms assemblies"
        Add-Type -AssemblyName System.Windows.Forms
        Add-Type -AssemblyName System.Drawing
    } catch {
        throw "❌ Failed to load Windows Forms. This feature requires .NET and Windows."
    }

    Write-Host "[DEBUG] Creating main form"
    $form = New-Object Windows.Forms.Form
    $form.Text = "Smart Log Analyzer"
    $form.Size = New-Object Drawing.Size(1000, 780)
    $form.StartPosition = "CenterScreen"

    $lblLogType = New-Object Windows.Forms.Label
    $lblLogType.Text = "Log Type:"
    $lblLogType.Location = New-Object Drawing.Point(10, 10)
    $lblLogType.Size = New-Object Drawing.Size(60, 20)

    $cmbLogType = New-Object Windows.Forms.ComboBox
    $cmbLogType.Location = New-Object Drawing.Point(75, 10)
    $cmbLogType.Size = New-Object Drawing.Size(120, 20)
    $cmbLogType.DropDownStyle = 'DropDownList'
    $cmbLogType.Items.AddRange(@("System", "Application", "Security", "All"))
    $cmbLogType.SelectedIndex = 0

    $lblStartTime = New-Object Windows.Forms.Label
    $lblStartTime.Text = "Start Time:"
    $lblStartTime.Location = New-Object Drawing.Point(210, 10)
    $lblStartTime.Size = New-Object Drawing.Size(70, 20)

    $dtStart = New-Object Windows.Forms.DateTimePicker
    $dtStart.Format = 'Custom'
    $dtStart.CustomFormat = "yyyy-MM-dd HH:mm"
    $dtStart.Location = New-Object Drawing.Point(280, 10)
    $dtStart.Size = New-Object Drawing.Size(140, 20)
    $dtStart.Value = (Get-Date).AddHours(-1)

    $lblEndTime = New-Object Windows.Forms.Label
    $lblEndTime.Text = "End Time:"
    $lblEndTime.Location = New-Object Drawing.Point(430, 10)
    $lblEndTime.Size = New-Object Drawing.Size(65, 20)

    $dtEnd = New-Object Windows.Forms.DateTimePicker
    $dtEnd.Format = 'Custom'
    $dtEnd.CustomFormat = "yyyy-MM-dd HH:mm"
    $dtEnd.Location = New-Object Drawing.Point(500, 10)
    $dtEnd.Size = New-Object Drawing.Size(140, 20)
    $dtEnd.Value = Get-Date

    $chkRedact = New-Object Windows.Forms.CheckBox
    $chkRedact.Text = "Redact Sensitive Data"
    $chkRedact.Location = New-Object Drawing.Point(10, 40)
    $chkRedact.Size = New-Object Drawing.Size(180, 20)

    $chkRedactLog = New-Object Windows.Forms.CheckBox
    $chkRedactLog.Text = "Generate Redaction Log"
    $chkRedactLog.Location = New-Object Drawing.Point(200, 40)
    $chkRedactLog.Size = New-Object Drawing.Size(180, 20)

    $btnFetch = New-Object Windows.Forms.Button
    $btnFetch.Text = "Fetch & Analyze Logs"
    $btnFetch.Location = New-Object Drawing.Point(400, 40)
    $btnFetch.Size = New-Object Drawing.Size(150, 30)

    $btnExportCSV = New-Object Windows.Forms.Button
    $btnExportCSV.Text = "Export to CSV"
    $btnExportCSV.Location = New-Object Drawing.Point(560, 40)
    $btnExportCSV.Size = New-Object Drawing.Size(80, 30)

    $btnExportJSON = New-Object Windows.Forms.Button
    $btnExportJSON.Text = "Export to JSON"
    $btnExportJSON.Location = New-Object Drawing.Point(650, 40)
    $btnExportJSON.Size = New-Object Drawing.Size(80, 30)

    $grid = New-Object Windows.Forms.DataGridView
    $grid.Location = New-Object Drawing.Point(10, 80)
    $grid.Size = New-Object Drawing.Size(960, 580)
    $grid.AutoSizeColumnsMode = 'Fill'
    $grid.ReadOnly = $true
    $grid.AutoGenerateColumns = $false

    $lblSummary = New-Object Windows.Forms.Label
    $lblSummary.Location = New-Object Drawing.Point(10, 670)
    $lblSummary.Size = New-Object Drawing.Size(960, 60)
    $lblSummary.Text = "Summary will appear here..."

    $form.Controls.AddRange(@(
        $lblLogType, $cmbLogType,
        $lblStartTime, $dtStart,
        $lblEndTime, $dtEnd,
        $chkRedact, $chkRedactLog,
        $btnFetch, $btnExportCSV, $btnExportJSON,
        $grid, $lblSummary
    ))

    $logData = @()

    $btnFetch.Add_Click({
        try {
            Write-Host "[DEBUG] Fetch button clicked"
            $logType = $cmbLogType.SelectedItem.ToString()
            $start = $dtStart.Value
            $end = $dtEnd.Value
            $useRedact = $chkRedact.Checked
            $useRedactLog = $chkRedactLog.Checked

            Write-Host "[DEBUG] Params: LogType=$logType Start=$start End=$end Redact=$useRedact RedactLog=$useRedactLog"

            $params = @{ 
                FetchLogs = $true
                LogType = $logType
                StartTime = $start
                EndTime = $end
                AttentionOnly = $true
                Colorize = $true
            }

            if ($useRedact) { $params.RedactSensitiveData = $true }
            if ($useRedactLog) { $params.GenerateRedactionLog = $true }

            Write-Host "[DEBUG] Invoking SmartAnalyzer"
            $result = Invoke-SmartAnalyzer @params
            $entries = $result.Entries
            Write-Host "[DEBUG] Entries retrieved: $($entries.Count)"

            $logData = $entries | ForEach-Object {
                [pscustomobject]@{
                    Timestamp = $_.TimeCreated
                    Level     = $_.LevelDisplayName
                    Message   = $_.Message
                }
            }

            $grid.Columns.Clear()
            if ($logData.Count -gt 0) {
                foreach ($col in $logData[0].PSObject.Properties.Name) {
                    $colObj = New-Object Windows.Forms.DataGridViewTextBoxColumn
                    $colObj.Name = $col
                    $colObj.DataPropertyName = $col
                    $colObj.HeaderText = $col
                    $grid.Columns.Add($colObj)
                }
            }

            $grid.DataSource = $logData

            try {
                Write-Host "[DEBUG] Generating summary"
                $summary = Get-LogSummary -LogLines $entries
                $lblSummary.Text = "Total: $($summary.TotalLines)  |  Errors: $($summary.ErrorCount)  |  Warnings: $($summary.WarningCount)  |  Info: $($summary.InfoCount)`nFrom: $($summary.FirstTimestamp)  To: $($summary.LastTimestamp)"
            } catch {
                Write-Host "[ERROR] Summary generation failed: $($_.Exception.Message)"
                $lblSummary.Text = "Could not generate summary."
            }
        } catch {
            Write-Host "[ERROR] Failed to fetch logs: $($_.Exception.Message)"
            [System.Windows.Forms.MessageBox]::Show("Failed to fetch logs. `n$($_.Exception.Message)", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        }
    })

    $btnExportCSV.Add_Click({
        Write-Host "[DEBUG] Export to CSV clicked"
        if (-not $logData) { return }
        $save = New-Object System.Windows.Forms.SaveFileDialog
        $save.Filter = "CSV Files (*.csv)|*.csv"
        $save.FileName = "LogExport.csv"
        if ($save.ShowDialog() -eq "OK") {
            $logData | Export-Csv -Path $save.FileName -NoTypeInformation
            [System.Windows.Forms.MessageBox]::Show("Exported to CSV.", "Export", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
        }
    })

    $btnExportJSON.Add_Click({
        Write-Host "[DEBUG] Export to JSON clicked"
        if (-not $logData) { return }
        $save = New-Object System.Windows.Forms.SaveFileDialog
        $save.Filter = "JSON Files (*.json)|*.json"
        $save.FileName = "LogExport.json"
        if ($save.ShowDialog() -eq "OK") {
            $logData | ConvertTo-Json -Depth 5 | Set-Content -Path $save.FileName
            [System.Windows.Forms.MessageBox]::Show("Exported to JSON.", "Export", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
        }
    })

    Write-Host "[DEBUG] Displaying form"
    $form.Topmost = $true
    $form.Add_Shown({ $form.Activate() })
    [void]$form.ShowDialog()
}




# SIG # Begin signature block
# MIIcFAYJKoZIhvcNAQcCoIIcBTCCHAECAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCDEo1cqF7briENe
# d2czwN3jGAUT8+P5/KAVIohUiyy2EaCCFlYwggMYMIICAKADAgECAhAVMtqhUrdy
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
# rGRwMRitMIIFjTCCBHWgAwIBAgIQDpsYjvnQLefv21DiCEAYWjANBgkqhkiG9w0B
# AQwFADBlMQswCQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYD
# VQQLExB3d3cuZGlnaWNlcnQuY29tMSQwIgYDVQQDExtEaWdpQ2VydCBBc3N1cmVk
# IElEIFJvb3QgQ0EwHhcNMjIwODAxMDAwMDAwWhcNMzExMTA5MjM1OTU5WjBiMQsw
# CQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3d3cu
# ZGlnaWNlcnQuY29tMSEwHwYDVQQDExhEaWdpQ2VydCBUcnVzdGVkIFJvb3QgRzQw
# ggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQC/5pBzaN675F1KPDAiMGkz
# 7MKnJS7JIT3yithZwuEppz1Yq3aaza57G4QNxDAf8xukOBbrVsaXbR2rsnnyyhHS
# 5F/WBTxSD1Ifxp4VpX6+n6lXFllVcq9ok3DCsrp1mWpzMpTREEQQLt+C8weE5nQ7
# bXHiLQwb7iDVySAdYyktzuxeTsiT+CFhmzTrBcZe7FsavOvJz82sNEBfsXpm7nfI
# SKhmV1efVFiODCu3T6cw2Vbuyntd463JT17lNecxy9qTXtyOj4DatpGYQJB5w3jH
# trHEtWoYOAMQjdjUN6QuBX2I9YI+EJFwq1WCQTLX2wRzKm6RAXwhTNS8rhsDdV14
# Ztk6MUSaM0C/CNdaSaTC5qmgZ92kJ7yhTzm1EVgX9yRcRo9k98FpiHaYdj1ZXUJ2
# h4mXaXpI8OCiEhtmmnTK3kse5w5jrubU75KSOp493ADkRSWJtppEGSt+wJS00mFt
# 6zPZxd9LBADMfRyVw4/3IbKyEbe7f/LVjHAsQWCqsWMYRJUadmJ+9oCw++hkpjPR
# iQfhvbfmQ6QYuKZ3AeEPlAwhHbJUKSWJbOUOUlFHdL4mrLZBdd56rF+NP8m800ER
# ElvlEFDrMcXKchYiCd98THU/Y+whX8QgUWtvsauGi0/C1kVfnSD8oR7FwI+isX4K
# Jpn15GkvmB0t9dmpsh3lGwIDAQABo4IBOjCCATYwDwYDVR0TAQH/BAUwAwEB/zAd
# BgNVHQ4EFgQU7NfjgtJxXWRM3y5nP+e6mK4cD08wHwYDVR0jBBgwFoAUReuir/SS
# y4IxLVGLp6chnfNtyA8wDgYDVR0PAQH/BAQDAgGGMHkGCCsGAQUFBwEBBG0wazAk
# BggrBgEFBQcwAYYYaHR0cDovL29jc3AuZGlnaWNlcnQuY29tMEMGCCsGAQUFBzAC
# hjdodHRwOi8vY2FjZXJ0cy5kaWdpY2VydC5jb20vRGlnaUNlcnRBc3N1cmVkSURS
# b290Q0EuY3J0MEUGA1UdHwQ+MDwwOqA4oDaGNGh0dHA6Ly9jcmwzLmRpZ2ljZXJ0
# LmNvbS9EaWdpQ2VydEFzc3VyZWRJRFJvb3RDQS5jcmwwEQYDVR0gBAowCDAGBgRV
# HSAAMA0GCSqGSIb3DQEBDAUAA4IBAQBwoL9DXFXnOF+go3QbPbYW1/e/Vwe9mqyh
# hyzshV6pGrsi+IcaaVQi7aSId229GhT0E0p6Ly23OO/0/4C5+KH38nLeJLxSA8hO
# 0Cre+i1Wz/n096wwepqLsl7Uz9FDRJtDIeuWcqFItJnLnU+nBgMTdydE1Od/6Fmo
# 8L8vC6bp8jQ87PcDx4eo0kxAGTVGamlUsLihVo7spNU96LHc/RzY9HdaXFSMb++h
# UD38dglohJ9vytsgjTVgHAIDyyCwrFigDkBjxZgiwbJZ9VVrzyerbHbObyMt9H5x
# aiNrIv8SuFQtJ37YOtnwtoeW/VvRXKwYw02fc7cBqZ9Xql4o4rmUMIIGtDCCBJyg
# AwIBAgIQDcesVwX/IZkuQEMiDDpJhjANBgkqhkiG9w0BAQsFADBiMQswCQYDVQQG
# EwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3d3cuZGlnaWNl
# cnQuY29tMSEwHwYDVQQDExhEaWdpQ2VydCBUcnVzdGVkIFJvb3QgRzQwHhcNMjUw
# NTA3MDAwMDAwWhcNMzgwMTE0MjM1OTU5WjBpMQswCQYDVQQGEwJVUzEXMBUGA1UE
# ChMORGlnaUNlcnQsIEluYy4xQTA/BgNVBAMTOERpZ2lDZXJ0IFRydXN0ZWQgRzQg
# VGltZVN0YW1waW5nIFJTQTQwOTYgU0hBMjU2IDIwMjUgQ0ExMIICIjANBgkqhkiG
# 9w0BAQEFAAOCAg8AMIICCgKCAgEAtHgx0wqYQXK+PEbAHKx126NGaHS0URedTa2N
# DZS1mZaDLFTtQ2oRjzUXMmxCqvkbsDpz4aH+qbxeLho8I6jY3xL1IusLopuW2qft
# JYJaDNs1+JH7Z+QdSKWM06qchUP+AbdJgMQB3h2DZ0Mal5kYp77jYMVQXSZH++0t
# rj6Ao+xh/AS7sQRuQL37QXbDhAktVJMQbzIBHYJBYgzWIjk8eDrYhXDEpKk7RdoX
# 0M980EpLtlrNyHw0Xm+nt5pnYJU3Gmq6bNMI1I7Gb5IBZK4ivbVCiZv7PNBYqHEp
# NVWC2ZQ8BbfnFRQVESYOszFI2Wv82wnJRfN20VRS3hpLgIR4hjzL0hpoYGk81coW
# J+KdPvMvaB0WkE/2qHxJ0ucS638ZxqU14lDnki7CcoKCz6eum5A19WZQHkqUJfdk
# DjHkccpL6uoG8pbF0LJAQQZxst7VvwDDjAmSFTUms+wV/FbWBqi7fTJnjq3hj0Xb
# Qcd8hjj/q8d6ylgxCZSKi17yVp2NL+cnT6Toy+rN+nM8M7LnLqCrO2JP3oW//1sf
# uZDKiDEb1AQ8es9Xr/u6bDTnYCTKIsDq1BtmXUqEG1NqzJKS4kOmxkYp2WyODi7v
# QTCBZtVFJfVZ3j7OgWmnhFr4yUozZtqgPrHRVHhGNKlYzyjlroPxul+bgIspzOwb
# tmsgY1MCAwEAAaOCAV0wggFZMBIGA1UdEwEB/wQIMAYBAf8CAQAwHQYDVR0OBBYE
# FO9vU0rp5AZ8esrikFb2L9RJ7MtOMB8GA1UdIwQYMBaAFOzX44LScV1kTN8uZz/n
# upiuHA9PMA4GA1UdDwEB/wQEAwIBhjATBgNVHSUEDDAKBggrBgEFBQcDCDB3Bggr
# BgEFBQcBAQRrMGkwJAYIKwYBBQUHMAGGGGh0dHA6Ly9vY3NwLmRpZ2ljZXJ0LmNv
# bTBBBggrBgEFBQcwAoY1aHR0cDovL2NhY2VydHMuZGlnaWNlcnQuY29tL0RpZ2lD
# ZXJ0VHJ1c3RlZFJvb3RHNC5jcnQwQwYDVR0fBDwwOjA4oDagNIYyaHR0cDovL2Ny
# bDMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0VHJ1c3RlZFJvb3RHNC5jcmwwIAYDVR0g
# BBkwFzAIBgZngQwBBAIwCwYJYIZIAYb9bAcBMA0GCSqGSIb3DQEBCwUAA4ICAQAX
# zvsWgBz+Bz0RdnEwvb4LyLU0pn/N0IfFiBowf0/Dm1wGc/Do7oVMY2mhXZXjDNJQ
# a8j00DNqhCT3t+s8G0iP5kvN2n7Jd2E4/iEIUBO41P5F448rSYJ59Ib61eoalhnd
# 6ywFLerycvZTAz40y8S4F3/a+Z1jEMK/DMm/axFSgoR8n6c3nuZB9BfBwAQYK9FH
# aoq2e26MHvVY9gCDA/JYsq7pGdogP8HRtrYfctSLANEBfHU16r3J05qX3kId+ZOc
# zgj5kjatVB+NdADVZKON/gnZruMvNYY2o1f4MXRJDMdTSlOLh0HCn2cQLwQCqjFb
# qrXuvTPSegOOzr4EWj7PtspIHBldNE2K9i697cvaiIo2p61Ed2p8xMJb82Yosn0z
# 4y25xUbI7GIN/TpVfHIqQ6Ku/qjTY6hc3hsXMrS+U0yy+GWqAXam4ToWd2UQ1KYT
# 70kZjE4YtL8Pbzg0c1ugMZyZZd/BdHLiRu7hAWE6bTEm4XYRkA6Tl4KSFLFk43es
# aUeqGkH/wyW4N7OigizwJWeukcyIPbAvjSabnf7+Pu0VrFgoiovRDiyx3zEdmcif
# /sYQsfch28bZeUz2rtY/9TCA6TD8dC3JE3rYkrhLULy7Dc90G6e8BlqmyIjlgp2+
# VqsS9/wQD7yFylIz0scmbKvFoW2jNrbM1pD2T7m3XDCCBu0wggTVoAMCAQICEAqA
# 7xhLjfEFgtHEdqeVdGgwDQYJKoZIhvcNAQELBQAwaTELMAkGA1UEBhMCVVMxFzAV
# BgNVBAoTDkRpZ2lDZXJ0LCBJbmMuMUEwPwYDVQQDEzhEaWdpQ2VydCBUcnVzdGVk
# IEc0IFRpbWVTdGFtcGluZyBSU0E0MDk2IFNIQTI1NiAyMDI1IENBMTAeFw0yNTA2
# MDQwMDAwMDBaFw0zNjA5MDMyMzU5NTlaMGMxCzAJBgNVBAYTAlVTMRcwFQYDVQQK
# Ew5EaWdpQ2VydCwgSW5jLjE7MDkGA1UEAxMyRGlnaUNlcnQgU0hBMjU2IFJTQTQw
# OTYgVGltZXN0YW1wIFJlc3BvbmRlciAyMDI1IDEwggIiMA0GCSqGSIb3DQEBAQUA
# A4ICDwAwggIKAoICAQDQRqwtEsae0OquYFazK1e6b1H/hnAKAd/KN8wZQjBjMqiZ
# 3xTWcfsLwOvRxUwXcGx8AUjni6bz52fGTfr6PHRNv6T7zsf1Y/E3IU8kgNkeECqV
# Q+3bzWYesFtkepErvUSbf+EIYLkrLKd6qJnuzK8Vcn0DvbDMemQFoxQ2Dsw4vEjo
# T1FpS54dNApZfKY61HAldytxNM89PZXUP/5wWWURK+IfxiOg8W9lKMqzdIo7VA1R
# 0V3Zp3DjjANwqAf4lEkTlCDQ0/fKJLKLkzGBTpx6EYevvOi7XOc4zyh1uSqgr6Un
# bksIcFJqLbkIXIPbcNmA98Oskkkrvt6lPAw/p4oDSRZreiwB7x9ykrjS6GS3NR39
# iTTFS+ENTqW8m6THuOmHHjQNC3zbJ6nJ6SXiLSvw4Smz8U07hqF+8CTXaETkVWz0
# dVVZw7knh1WZXOLHgDvundrAtuvz0D3T+dYaNcwafsVCGZKUhQPL1naFKBy1p6ll
# N3QgshRta6Eq4B40h5avMcpi54wm0i2ePZD5pPIssoszQyF4//3DoK2O65Uck5Wg
# gn8O2klETsJ7u8xEehGifgJYi+6I03UuT1j7FnrqVrOzaQoVJOeeStPeldYRNMmS
# F3voIgMFtNGh86w3ISHNm0IaadCKCkUe2LnwJKa8TIlwCUNVwppwn4D3/Pt5pwID
# AQABo4IBlTCCAZEwDAYDVR0TAQH/BAIwADAdBgNVHQ4EFgQU5Dv88jHt/f3X85Fx
# YxlQQ89hjOgwHwYDVR0jBBgwFoAU729TSunkBnx6yuKQVvYv1Ensy04wDgYDVR0P
# AQH/BAQDAgeAMBYGA1UdJQEB/wQMMAoGCCsGAQUFBwMIMIGVBggrBgEFBQcBAQSB
# iDCBhTAkBggrBgEFBQcwAYYYaHR0cDovL29jc3AuZGlnaWNlcnQuY29tMF0GCCsG
# AQUFBzAChlFodHRwOi8vY2FjZXJ0cy5kaWdpY2VydC5jb20vRGlnaUNlcnRUcnVz
# dGVkRzRUaW1lU3RhbXBpbmdSU0E0MDk2U0hBMjU2MjAyNUNBMS5jcnQwXwYDVR0f
# BFgwVjBUoFKgUIZOaHR0cDovL2NybDMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0VHJ1
# c3RlZEc0VGltZVN0YW1waW5nUlNBNDA5NlNIQTI1NjIwMjVDQTEuY3JsMCAGA1Ud
# IAQZMBcwCAYGZ4EMAQQCMAsGCWCGSAGG/WwHATANBgkqhkiG9w0BAQsFAAOCAgEA
# ZSqt8RwnBLmuYEHs0QhEnmNAciH45PYiT9s1i6UKtW+FERp8FgXRGQ/YAavXzWjZ
# hY+hIfP2JkQ38U+wtJPBVBajYfrbIYG+Dui4I4PCvHpQuPqFgqp1PzC/ZRX4pvP/
# ciZmUnthfAEP1HShTrY+2DE5qjzvZs7JIIgt0GCFD9ktx0LxxtRQ7vllKluHWiKk
# 6FxRPyUPxAAYH2Vy1lNM4kzekd8oEARzFAWgeW3az2xejEWLNN4eKGxDJ8WDl/FQ
# USntbjZ80FU3i54tpx5F/0Kr15zW/mJAxZMVBrTE2oi0fcI8VMbtoRAmaaslNXdC
# G1+lqvP4FbrQ6IwSBXkZagHLhFU9HCrG/syTRLLhAezu/3Lr00GrJzPQFnCEH1Y5
# 8678IgmfORBPC1JKkYaEt2OdDh4GmO0/5cHelAK2/gTlQJINqDr6JfwyYHXSd+V0
# 8X1JUPvB4ILfJdmL+66Gp3CSBXG6IwXMZUXBhtCyIaehr0XkBoDIGMUG1dUtwq1q
# mcwbdUfcSYCn+OwncVUXf53VJUNOaMWMts0VlRYxe5nK+At+DI96HAlXHAL5SlfY
# xJ7La54i71McVWRP66bW+yERNpbJCjyCYG2j+bdpxo/1Cy4uPcU3AWVPGrbn5PhD
# Bf3Froguzzhk++ami+r3Qrx5bIbY3TVzgiFI7Gq3zWcxggUUMIIFEAIBATA4MCQx
# IjAgBgNVBAMMGVNtYXJ0TG9nQW5hbHl6ZXIgRGV2IENlcnQCEBUy2qFSt3KaSMr0
# wjbbRvcwDQYJYIZIAWUDBAIBBQCggYQwGAYKKwYBBAGCNwIBDDEKMAigAoAAoQKA
# ADAZBgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAcBgorBgEEAYI3AgELMQ4wDAYK
# KwYBBAGCNwIBFTAvBgkqhkiG9w0BCQQxIgQgVXdkmCu5zLlqZloKmdmdRE1hc3Q3
# 7ZWJaU60ue8WMoAwDQYJKoZIhvcNAQEBBQAEggEAeHqBPAOnWIkzC72fpOP0w25N
# AHWtHy5c9hRNpvd1s3fjIvgdEEUfckSUJu4YheUaEpngV1I9DSJEw5Wxb23S54BQ
# FyWpqFrrTw7wGIr6ve8eq2lnJUW4EmoPRIFugkaVDBUmEQRfpXQcebsEKgwCMCwV
# Altk4SHn4+ZopbN0T91c8jKZtNEsOPhltS6grqP6Y4bn0Oi7LyAum+b8julCI5x+
# daf82Fbicjlsghf4xaVuPiDmd10KNEdbzzmfwx6LfG8ZYclze1x4oBMDORFICODW
# tzgi7toB0/ziUKVPK/gTFxkTqMjgiRvuOWk/uwNTF53ip1dqIbB4uEf6d4xX2aGC
# AyYwggMiBgkqhkiG9w0BCQYxggMTMIIDDwIBATB9MGkxCzAJBgNVBAYTAlVTMRcw
# FQYDVQQKEw5EaWdpQ2VydCwgSW5jLjFBMD8GA1UEAxM4RGlnaUNlcnQgVHJ1c3Rl
# ZCBHNCBUaW1lU3RhbXBpbmcgUlNBNDA5NiBTSEEyNTYgMjAyNSBDQTECEAqA7xhL
# jfEFgtHEdqeVdGgwDQYJYIZIAWUDBAIBBQCgaTAYBgkqhkiG9w0BCQMxCwYJKoZI
# hvcNAQcBMBwGCSqGSIb3DQEJBTEPFw0yNTA2MjAwODUzMTBaMC8GCSqGSIb3DQEJ
# BDEiBCBj4c9KaQcT9eDE+x3dP6Vbud6txo8bMJ9SkPnUqLe+1jANBgkqhkiG9w0B
# AQEFAASCAgBtM4Ixaq60l6g3y6f4NNTB6cKr+Pl3vncI48LK31iQ3oZS8BU0+GXM
# j1ovQofCJfqF8zhH6En07If5Dj0caevxHH+r+dsO5+ColVf0Om4V4OBF++amXGzF
# leVYGOZYbVA0SWQGd+B155aVnOM7PVyZBk/93qnEhbsp/hAktwwUe6X0GGFo6Snx
# ucruVqhOhtDdHcPexa3rSHIzrL5BcAdugWMtLMc+sDTIttUyR0fN0Kc9se3pIp/m
# Km0v2LaRKzVMJrZhsqxoG+cSoP7ef8lMBGvVmhgYBMCZ31KCP5xBwcsUFY/4AVr9
# /khy8bO42HlcGtr1ySE347xaKxYDKb3LoyLGFEA43vRdalYJMkx+2G07eBipyrWy
# VK35bPNj7PWPv5p8fnLYFyIfYDVVJadgOkiK/WYcI8wjiy2BeuOLj9/uIkyBWfNa
# lBsq9AGcZ+1Iff06dQOGbPHET4eh3fy5rBYxD3LbMlSeRdmbFo97wF+lBqgxG/Pp
# yOnX8xQG0YSUpA65fKuVQAWUdAOYGdqCD4b80PvWfQ2vDozlUGD73wl/7E5Ee/8L
# EtlXYKTwKPTCszUblFg/iAvLTXE00JTn/V/pIIwJ6LjBkzLT9jh/RrgLYicIwQHx
# 2FTCF0SF/f5ucCZhlG4YnafElHjPtwfJS19u5Oht8BkBGKdqkcEX5w==
# SIG # End signature block

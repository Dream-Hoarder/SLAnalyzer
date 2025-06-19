function Show-LogAnalyzerUI {
    if (-not $IsWindows) {
        throw "❌ The Smart Log Analyzer UI is only supported on Windows."
    }

    try {
        Add-Type -AssemblyName System.Windows.Forms
        Add-Type -AssemblyName System.Drawing
    } catch {
        throw "❌ Failed to load Windows Forms. This feature requires .NET and Windows."
    }

    # Form
    $form = New-Object Windows.Forms.Form
    $form.Text = "Smart Log Analyzer"
    $form.Size = New-Object Drawing.Size(1000, 700)
    $form.StartPosition = "CenterScreen"

    # File Select Button
    $btnSelect = New-Object Windows.Forms.Button
    $btnSelect.Text = "Select Log Files"
    $btnSelect.Location = New-Object Drawing.Point(10, 10)
    $btnSelect.Size = New-Object Drawing.Size(150, 30)

    # Export Buttons
    $btnExportCSV = New-Object Windows.Forms.Button
    $btnExportCSV.Text = "Export to CSV"
    $btnExportCSV.Location = New-Object Drawing.Point(170, 10)
    $btnExportCSV.Size = New-Object Drawing.Size(120, 30)

    $btnExportJSON = New-Object Windows.Forms.Button
    $btnExportJSON.Text = "Export to JSON"
    $btnExportJSON.Location = New-Object Drawing.Point(300, 10)
    $btnExportJSON.Size = New-Object Drawing.Size(120, 30)

    # Data Grid
    $grid = New-Object Windows.Forms.DataGridView
    $grid.Location = New-Object Drawing.Point(10, 50)
    $grid.Size = New-Object Drawing.Size(960, 540)
    $grid.AutoSizeColumnsMode = 'Fill'
    $grid.ReadOnly = $true
    $grid.AutoGenerateColumns = $false

    # Summary Label
    $lblSummary = New-Object Windows.Forms.Label
    $lblSummary.Location = New-Object Drawing.Point(10, 600)
    $lblSummary.Size = New-Object Drawing.Size(960, 60)
    $lblSummary.Text = "Summary will appear here..."

    # Add controls to form
    $form.Controls.AddRange(@($btnSelect, $btnExportCSV, $btnExportJSON, $grid, $lblSummary))

    # Global variable for current log data
    $logData = @()

    # File Select Action
    $btnSelect.Add_Click({
        $dialog = New-Object System.Windows.Forms.OpenFileDialog
        $dialog.Multiselect = $true
        $dialog.Filter = "Log Files (*.etl;*.log;*.txt)|*.etl;*.log;*.txt|All Files (*.*)|*.*"

        if ($dialog.ShowDialog() -eq "OK") {
            $entries = @()
            foreach ($file in $dialog.FileNames) {
                try {
                    $entries += Get-LogEntries -Path $file
                } catch {
                    [System.Windows.Forms.MessageBox]::Show("Failed to read $file`n$($_.Exception.Message)", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
                }
            }

            $logData = $entries | ForEach-Object {
                if ($_ -match '^(?<Time>[\d\-:\s]+) \[(?<Level>[^\]]+)\] (?<Provider>[^:]+): (?<Message>.+)$') {
                    [pscustomobject]@{
                        Timestamp = $matches.Time
                        Level     = $matches.Level
                        Provider  = $matches.Provider
                        Message   = $matches.Message
                    }
                } else {
                    [pscustomobject]@{ RawEntry = $_ }
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
                $summary = Get-LogSummary -LogLines $entries
                $lblSummary.Text = "Total: $($summary.TotalLines)  |  Errors: $($summary.ErrorCount)  |  Warnings: $($summary.WarningCount)  |  Info: $($summary.InfoCount)`nFrom: $($summary.FirstTimestamp)  To: $($summary.LastTimestamp)"
            } catch {
                $lblSummary.Text = "Could not generate summary."
            }
        }
    })

    # Export to CSV
    $btnExportCSV.Add_Click({
        if (-not $logData) { return }
        $save = New-Object System.Windows.Forms.SaveFileDialog
        $save.Filter = "CSV Files (*.csv)|*.csv"
        $save.FileName = "LogExport.csv"
        if ($save.ShowDialog() -eq "OK") {
            $logData | Export-Csv -Path $save.FileName -NoTypeInformation
            [System.Windows.Forms.MessageBox]::Show("Exported to CSV.", "Export", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
        }
    })

    # Export to JSON
    $btnExportJSON.Add_Click({
        if (-not $logData) { return }
        $save = New-Object System.Windows.Forms.SaveFileDialog
        $save.Filter = "JSON Files (*.json)|*.json"
        $save.FileName = "LogExport.json"
        if ($save.ShowDialog() -eq "OK") {
            $logData | ConvertTo-Json -Depth 5 | Set-Content -Path $save.FileName
            [System.Windows.Forms.MessageBox]::Show("Exported to JSON.", "Export", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
        }
    })

    # Show form
    $form.Topmost = $true
    $form.Add_Shown({ $form.Activate() })
    [void]$form.ShowDialog()
}

# SIG # Begin signature block
# MIIFsAYJKoZIhvcNAQcCoIIFoTCCBZ0CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCAI7BrdnHx6nF/N
# xim/J2+h8C08sYDvuo9AlAlYaHTh5KCCAxwwggMYMIICAKADAgECAhAVMtqhUrdy
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
# IOLk02e/9RNopm1Dndj4NR9fsuy6Wrxj+MFiq/2gjryqMA0GCSqGSIb3DQEBAQUA
# BIIBAHvIEUAukYfPUH32xeo9GtOTrz8/B1dkZAGh4KaxHE64U6XNWSGYMKvtRsmo
# 8vVVOT9pKsCbbidyVsWT/5CMbKpSL7yQJ59Ds9+s5gUMmvOiqK0CE/B8sLRsLfim
# KyjbCe7BcXzKPZOB/J1D35Y7lTzSPmDIeTXt2Nga8t+n1+rCUYP156aY9WEA7NZc
# d2wIJWGIy8Zpq+RF+1c7YWTm10HmbDsoJCGzZ0+BUFWzl2KyUrT4xvNj61qJw/xP
# R/On/nwbFzUVLxeGF49x/ITRKrNbAsc3lU7XB1DdEBmGZNGIHo7wrNfdxQKmmyAA
# lMj9sroTn61l/mxpSckf3pB2KYc=
# SIG # End signature block

function Show-LogAnalyzerUI {
    Set-StrictMode -Version Latest
    Write-Host "[DEBUG] Starting Show-LogAnalyzerUI"

    if (-not $IsWindows) {
        throw "❌ The Smart Log Analyzer UI is only supported on Windows."
    }

    try {
        Add-Type -AssemblyName System.Windows.Forms
        Add-Type -AssemblyName System.Drawing
    } catch {
        throw "❌ Failed to load Windows Forms: $($_.Exception.Message)"
    }

    try {
        Import-Module -Name SmartLogAnalyzer -ErrorAction Stop -Verbose:$false
    } catch {
        throw "❌ Failed to import SmartLogAnalyzer module: $($_.Exception.Message)"
    }

    # --- Helper UI Creator Functions ---
    function New-Label ($text, $x, $y, $width = 100, $height = 20) {
        $lbl = New-Object Windows.Forms.Label
        $lbl.Text = $text
        $lbl.Location = New-Object Drawing.Point($x, $y)
        $lbl.Size = New-Object Drawing.Size($width, $height)
        return $lbl
    }

    function New-Button ($text, $x, $y, $width = 100, $height = 30) {
        $btn = New-Object Windows.Forms.Button
        $btn.Text = $text
        $btn.Location = New-Object Drawing.Point($x, $y)
        $btn.Size = New-Object Drawing.Size($width, $height)
        return $btn
    }

    function Export-LogDataToFile {
        param (
            [string]$Format,
            [scriptblock]$ExportBlock,
            [string]$Filter,
            [string]$Extension
        )
        if (-not $script:logData -or $script:logData.Count -eq 0) {
            [Windows.Forms.MessageBox]::Show("No log data to export.", "Information", 'OK', 'Information')
            return
        }
        $save = New-Object Windows.Forms.SaveFileDialog
        $save.Filter = $Filter
        $save.FileName = "LogExport_$(Get-Date -Format 'yyyyMMdd_HHmmss').$Extension"
        if ($save.ShowDialog() -eq [Windows.Forms.DialogResult]::OK) {
            try {
                & $ExportBlock $save.FileName
                [Windows.Forms.MessageBox]::Show("Exported to $Format successfully.", "Export Complete", 'OK', 'Information')
            } catch {
                [Windows.Forms.MessageBox]::Show("Export failed: $($_.Exception.Message)", "Export Error", 'OK', 'Error')
            }
        }
    }

    # --- Initialize Script Variables ---
    $script:logData = @()
    $script:rawLogEntries = @()

    # --- Form Setup ---
    $form = New-Object Windows.Forms.Form
    $form.Text = "Smart Log Analyzer"
    $form.Size = New-Object Drawing.Size(1000, 820)
    $form.StartPosition = "CenterScreen"

    # --- Controls ---
    $lblLogType = New-Label "Log Type:" 10 10 60
    $cmbLogType = New-Object Windows.Forms.ComboBox
    $cmbLogType.Location = New-Object Drawing.Point(75, 10)
    $cmbLogType.Size = New-Object Drawing.Size(120, 20)
    $cmbLogType.DropDownStyle = 'DropDownList'
    $cmbLogType.Items.AddRange(@("System", "Application", "Security", "All"))
    $cmbLogType.SelectedIndex = 0

    $lblStartTime = New-Label "Start Time:" 210 10 70
    $dtStart = New-Object Windows.Forms.DateTimePicker
    $dtStart.Format = 'Custom'
    $dtStart.CustomFormat = "yyyy-MM-dd HH:mm"
    $dtStart.Location = New-Object Drawing.Point(280, 10)
    $dtStart.Size = New-Object Drawing.Size(140, 20)
    $dtStart.Value = (Get-Date).AddHours(-1)

    $lblEndTime = New-Label "End Time:" 430 10 65
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

    $btnFetch = New-Button "Fetch & Analyze Logs" 400 40 150
    $btnExportCSV = New-Button "Export to CSV" 560 40 80
    $btnExportJSON = New-Button "Export to JSON" 650 40 80
    $btnExportReport = New-Button "Export Log Report" 740 40 110

    $grid = New-Object Windows.Forms.DataGridView
    $grid.Location = New-Object Drawing.Point(10, 80)
    $grid.Size = New-Object Drawing.Size(960, 600)
    $grid.ReadOnly = $true
    $grid.AutoGenerateColumns = $false
    $grid.AutoSizeColumnsMode = 'Fill'

    $lblSummary = New-Label "Summary will appear here..." 10 690 960 60
    $lblSummary.AutoSize = $false

    # --- Event Handlers ---
    $cellFormatEvent = Register-ObjectEvent -InputObject $grid -EventName CellFormatting -Action {
        try {
            if ($eventArgs.RowIndex -ge 0 -and $eventArgs.ColumnIndex -ge 0) {
                $level = $this.Rows[$eventArgs.RowIndex].Cells['Level'].Value
                $eventArgs.CellStyle.BackColor = switch ($level) {
                    'Error'   { [Drawing.Color]::LightCoral }
                    'Warning' { [Drawing.Color]::Khaki }
                    'Info'    { [Drawing.Color]::LightGreen }
                    default   { [Drawing.Color]::White }
                }
            }
        } catch {
            Write-Host "[DEBUG] CellFormatting error: $($_.Exception.Message)"
        }
    }

    $btnFetch.Add_Click({
        try {
            $params = @{
                FetchLogs = $true
                LogType = $cmbLogType.SelectedItem.ToString()
                StartTime = $dtStart.Value
                EndTime = $dtEnd.Value
                AttentionOnly = $true
            }
            if ($chkRedact.Checked) { $params.RedactSensitiveData = $true }
            if ($chkRedactLog.Checked) { $params.GenerateRedactionLog = $true }

            $result = Invoke-SmartAnalyzer @params -ErrorAction Stop
            $script:rawLogEntries = $result.Entries

            $script:logData = $result.Entries | ForEach-Object {
                [pscustomobject]@{
                    Timestamp = $_.TimeCreated
                    Level     = $_.LevelDisplayName
                    Message   = $_.Message
                }
            }

            $grid.Columns.Clear()
            if ($script:logData.Count -gt 0) {
                foreach ($col in $script:logData[0].PSObject.Properties.Name) {
                    $colObj = New-Object Windows.Forms.DataGridViewTextBoxColumn
                    $colObj.Name = $col
                    $colObj.DataPropertyName = $col
                    $colObj.HeaderText = $col
                    $colObj.AutoSizeMode = if ($col -eq "Message") {
                        [System.Windows.Forms.DataGridViewAutoSizeColumnMode]::Fill
                    } else {
                        [System.Windows.Forms.DataGridViewAutoSizeColumnMode]::AllCellsExceptHeader
                    }
                    $grid.Columns.Add($colObj)
                }
            }
            $grid.DataSource = $script:logData

            $summary = Get-LogSummary -LogLines $result.Entries -ErrorAction Stop
            $lblSummary.Text = "Total: $($summary.TotalLines)  |  Errors: $($summary.ErrorCount)  |  Warnings: $($summary.WarningCount)  |  Info: $($summary.InfoCount)`nFrom: $($summary.FirstTimestamp)  To: $($summary.LastTimestamp)"
        } catch {
            [Windows.Forms.MessageBox]::Show("Failed to fetch logs: $($_.Exception.Message)", "Error", 'OK', 'Error')
        }
    })

    $btnExportCSV.Add_Click({
        Export-LogDataToFile -Format "CSV" -Filter "CSV Files (*.csv)|*.csv" -Extension "csv" -ExportBlock {
            param($file) $script:logData | Export-Csv $file -NoTypeInformation -ErrorAction Stop
        }
    })

    $btnExportJSON.Add_Click({
        Export-LogDataToFile -Format "JSON" -Filter "JSON Files (*.json)|*.json" -Extension "json" -ExportBlock {
            param($file) $script:logData | ConvertTo-Json -Depth 5 | Set-Content $file -ErrorAction Stop
        }
    })

    $btnExportReport.Add_Click({
        if (-not $script:rawLogEntries -or $script:rawLogEntries.Count -eq 0) {
            [Windows.Forms.MessageBox]::Show("No log data to export as report.", "Information", 'OK', 'Information')
            return
        }
        $save = New-Object Windows.Forms.SaveFileDialog
        $save.Filter = "Text Files (*.txt)|*.txt|All Files (*.*)|*.*"
        $save.FileName = "LogReport_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
        if ($save.ShowDialog() -eq [Windows.Forms.DialogResult]::OK) {
            try {
                Export-LogReport -LogLines $script:rawLogEntries -OutputPath $save.FileName -ErrorAction Stop
                [Windows.Forms.MessageBox]::Show("Log Report exported successfully.", "Export Complete", 'OK', 'Information')
            } catch {
                [Windows.Forms.MessageBox]::Show("Failed to export log report.`nError: $($_.Exception.Message)", "Export Error", 'OK', 'Error')
            }
        }
    })

    $form.Controls.AddRange(@(
        $lblLogType, $cmbLogType,
        $lblStartTime, $dtStart,
        $lblEndTime, $dtEnd,
        $chkRedact, $chkRedactLog,
        $btnFetch, $btnExportCSV, $btnExportJSON, $btnExportReport,
        $grid, $lblSummary
    ))

    Write-Host "[DEBUG] Displaying form"
    [void]$form.ShowDialog()
    $form.Dispose()

    Unregister-Event -SourceIdentifier $cellFormatEvent.Name
    Remove-Job -Id $cellFormatEvent.Id -Force

    Write-Host "[DEBUG] Show-LogAnalyzerUI finished"
    exit $LASTEXITCODE
}

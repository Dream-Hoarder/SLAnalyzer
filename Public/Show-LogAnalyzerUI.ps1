function Show-LogAnalyzerUI {
    # Ensure strict mode for robust scripting
    Set-StrictMode -Version Latest

    Write-Host "[DEBUG] Starting Show-LogAnalyzerUI"

    # --- Pre-requisite Checks ---
    if (-not $IsWindows) {
        throw "❌ The Smart Log Analyzer UI is only supported on Windows."
    }

    try {
        Write-Host "[DEBUG] Loading Windows Forms assemblies"
        Add-Type -AssemblyName System.Windows.Forms
        Add-Type -AssemblyName System.Drawing
    } catch {
        throw "❌ Failed to load Windows Forms. This feature requires .NET and Windows. Error: $($_.Exception.Message)"
    }

    # Ensure the SmartLogAnalyzer module is imported to access its functions
    try {
        Write-Host "[DEBUG] Importing SmartLogAnalyzer module"
        Import-Module -Name SmartLogAnalyzer -ErrorAction Stop
    } catch {
        throw "❌ Failed to import SmartLogAnalyzer module. Please ensure it is installed. Error: $($_.Exception.Message)"
    }


    # --- Form Initialization ---
    Write-Host "[DEBUG] Creating main form"
    $form = New-Object Windows.Forms.Form
    $form.Text = "Smart Log Analyzer"
    $form.Size = New-Object Drawing.Size(1000, 820)
    $form.StartPosition = "CenterScreen"

    # --- UI Controls ---
    # Log Type Selection
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

    # Start Time Selection
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

    # End Time Selection
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

    # Checkboxes for Redaction
    $chkRedact = New-Object Windows.Forms.CheckBox
    $chkRedact.Text = "Redact Sensitive Data"
    $chkRedact.Location = New-Object Drawing.Point(10, 40)
    $chkRedact.Size = New-Object Drawing.Size(180, 20)

    $chkRedactLog = New-Object Windows.Forms.CheckBox
    $chkRedactLog.Text = "Generate Redaction Log"
    $chkRedactLog.Location = New-Object Drawing.Point(200, 40)
    $chkRedactLog.Size = New-Object Drawing.Size(180, 20)

    # Action Buttons
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

    $btnExportReport = New-Object Windows.Forms.Button
    $btnExportReport.Text = "Export Log Report"
    $btnExportReport.Location = New-Object Drawing.Point(740, 40)
    $btnExportReport.Size = New-Object Drawing.Size(110, 30)

    # Data Grid View
    $grid = New-Object Windows.Forms.DataGridView
    $grid.Location = New-Object Drawing.Point(10, 80)
    $grid.Size = New-Object Drawing.Size(960, 600)
    $grid.AutoSizeColumnsMode = 'Fill' # Initial auto-size mode for all columns
    $grid.ReadOnly = $true
    $grid.AutoGenerateColumns = $false # We'll generate columns manually for better control

    # Summary Label
    $lblSummary = New-Object Windows.Forms.Label
    $lblSummary.Location = New-Object Drawing.Point(10, 690)
    $lblSummary.Size = New-Object Drawing.Size(960, 60)
    $lblSummary.Text = "Summary will appear here..."
    $lblSummary.AutoSize = $false # Prevent AutoSize from interfering with fixed height

    # Add controls to the form
    $form.Controls.AddRange(@(
        $lblLogType, $cmbLogType,
        $lblStartTime, $dtStart,
        $lblEndTime, $dtEnd,
        $chkRedact, $chkRedactLog,
        $btnFetch, $btnExportCSV, $btnExportJSON, $btnExportReport,
        $grid, $lblSummary
    ))

    # Declare these variables at script scope to be accessible inside event handlers
    Set-Variable -Name logData -Value @() -Scope Script
    Set-Variable -Name rawLogEntries -Value @() -Scope Script

    # --- Event Handlers ---

    # Register CellFormatting event for colorizing rows based on Level
    Register-ObjectEvent -InputObject $grid -EventName CellFormatting -Action {
        try {
            if ($eventArgs.RowIndex -ge 0 -and $eventArgs.ColumnIndex -ge 0) {
                $rowIndex = $eventArgs.RowIndex
                if ($this.Columns.Contains('Level')) {
                    $levelCell = $this.Rows[$rowIndex].Cells['Level']
                    $level = $levelCell.Value

                    $color = switch ($level) {
                        'Error'   { [System.Drawing.Color]::LightCoral }
                        'Warning' { [System.Drawing.Color]::Khaki }
                        'Info'    { [System.Drawing.Color]::LightGreen }
                        default   { [System.Drawing.Color]::White }
                    }

                    $eventArgs.CellStyle.BackColor = $color
                }
            }
        } catch {
            Write-Host "[DEBUG] CellFormatting error: $($_.Exception.Message)"
        }
    }

    # Fetch & Analyze Logs Button Click
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
                AttentionOnly = $true # Assumed default for UI
            }

            if ($useRedact) { $params.RedactSensitiveData = $true }
            if ($useRedactLog) { $params.GenerateRedactionLog = $true }

            Write-Host "[DEBUG] Invoking Invoke-SmartAnalyzer with parameters: $($params | ConvertTo-Json -Compress)"
            $result = Invoke-SmartAnalyzer @params -ErrorAction Stop
            Set-Variable -Name rawLogEntries -Value $result.Entries -Scope Script
            Write-Host "[DEBUG] Entries retrieved: $($result.Entries.Count)"

            # Prepare data for DataGridView (simplified properties for display)
            $logDataLocal = $result.Entries | ForEach-Object {
                [pscustomobject]@{
                    Timestamp = $_.TimeCreated
                    Level     = $_.LevelDisplayName
                    Message   = $_.Message
                }
            }
            Set-Variable -Name logData -Value $logDataLocal -Scope Script

            # Clear existing columns and add new ones based on $logData structure
            $grid.Columns.Clear()
            if ($logDataLocal.Count -gt 0) {
                foreach ($colName in $logDataLocal[0].PSObject.Properties.Name) {
                    $colObj = New-Object Windows.Forms.DataGridViewTextBoxColumn
                    $colObj.Name = $colName
                    $colObj.DataPropertyName = $colName
                    $colObj.HeaderText = $colName
                    if ($colName -eq "Message") {
                        $colObj.AutoSizeMode = [System.Windows.Forms.DataGridViewAutoSizeColumnMode]::Fill
                    } else {
                        $colObj.AutoSizeMode = [System.Windows.Forms.DataGridViewAutoSizeColumnMode]::AllCellsExceptHeader
                    }
                    $grid.Columns.Add($colObj)
                }
            }

            $grid.DataSource = $logDataLocal

            # Generate and display summary
            try {
                Write-Host "[DEBUG] Generating summary"
                $summary = Get-LogSummary -LogLines $result.Entries -ErrorAction Stop
                $lblSummary.Text = "Total: $($summary.TotalLines)  |  Errors: $($summary.ErrorCount)  |  Warnings: $($summary.WarningCount)  |  Info: $($summary.InfoCount)`nFrom: $($summary.FirstTimestamp)  To: $($summary.LastTimestamp)"
            } catch {
                Write-Host "[ERROR] Summary generation failed: $($_.Exception.Message)"
                $lblSummary.Text = "Could not generate summary: $($_.Exception.Message)"
            }
        } catch {
            Write-Host "[ERROR] Failed to fetch logs: $($_.Exception.Message)"
            [System.Windows.Forms.MessageBox]::Show("Failed to fetch and analyze logs. `n`nError: $($_.Exception.Message)", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        }
    })

    # Export to CSV Button Click
    $btnExportCSV.Add_Click({
        Write-Host "[DEBUG] Export to CSV clicked"
        if (-not $script:logData -or $script:logData.Count -eq 0) {
            [System.Windows.Forms.MessageBox]::Show("No log data to export.", "Information", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
            return
        }
        $save = New-Object System.Windows.Forms.SaveFileDialog
        $save.Filter = "CSV Files (*.csv)|*.csv"
        $save.FileName = "LogExport_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
        if ($save.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            try {
                $script:logData | Export-Csv -Path $save.FileName -NoTypeInformation -ErrorAction Stop
                [System.Windows.Forms.MessageBox]::Show("Log data exported to CSV successfully.", "Export Complete", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
            } catch {
                [System.Windows.Forms.MessageBox]::Show("Failed to export to CSV.`n`nError: $($_.Exception.Message)", "Export Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
            }
        }
    })

    # Export to JSON Button Click
    $btnExportJSON.Add_Click({
        Write-Host "[DEBUG] Export to JSON clicked"
        if (-not $script:logData -or $script:logData.Count -eq 0) {
            [System.Windows.Forms.MessageBox]::Show("No log data to export.", "Information", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
            return
        }
        $save = New-Object System.Windows.Forms.SaveFileDialog
        $save.Filter = "JSON Files (*.json)|*.json"
        $save.FileName = "LogExport_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
        if ($save.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            try {
                $script:logData | ConvertTo-Json -Depth 5 | Set-Content -Path $save.FileName -ErrorAction Stop
                [System.Windows.Forms.MessageBox]::Show("Log data exported to JSON successfully.", "Export Complete", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
            } catch {
                [System.Windows.Forms.MessageBox]::Show("Failed to export to JSON.`n`nError: $($_.Exception.Message)", "Export Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
            }
        }
    })

    # Export Log Report Button Click
    $btnExportReport.Add_Click({
        Write-Host "[DEBUG] Export Log Report clicked"
        if (-not $script:rawLogEntries -or $script:rawLogEntries.Count -eq 0) {
            [System.Windows.Forms.MessageBox]::Show("No log data to export as report. Please fetch logs first.", "Information", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
            return
        }

        $save = New-Object System.Windows.Forms.SaveFileDialog
        $save.Filter = "Text Files (*.txt)|*.txt|All Files (*.*)|*.*"
        $save.FileName = "LogReport_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
        if ($save.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            try {
                Export-LogReport -LogLines $script:rawLogEntries -OutputPath $save.FileName -ErrorAction Stop
                [System.Windows.Forms.MessageBox]::Show("Log Report exported successfully.", "Export Complete", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
            } catch {
                [System.Windows.Forms.MessageBox]::Show("Failed to export log report.`n`nError: $($_.Exception.Message)", "Export Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
            }
        }
    })

    Write-Host "[DEBUG] Displaying form"
    [void]$form.ShowDialog()

    Write-Host "[DEBUG] Show-LogAnalyzerUI finished"
}
# Ensure the script exits with the correct exit code
$LASTEXITCODE = 0
# Exit with the last exit code
exit $LASTEXITCODE

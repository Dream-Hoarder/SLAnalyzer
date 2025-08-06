function Show-LogAnalyzerUI {
    Set-StrictMode -Version Latest
    Write-Host "[DEBUG] Starting Show-LogAnalyzerUI"

    # Check if running on Windows - compatible with both PowerShell 5.1 and 7+
    $isWindowsOS = if ($PSVersionTable.PSVersion.Major -ge 6) {
        $IsWindows
    } else {
        $env:OS -eq 'Windows_NT'
    }
    
    if (-not $isWindowsOS) {
        throw "[ERROR] The Smart Log Analyzer UI is only supported on Windows."
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
    $form.MinimumSize = New-Object Drawing.Size(800, 600)
    $form.FormBorderStyle = [Windows.Forms.FormBorderStyle]::Sizable

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
    
    $chkAttentionOnly = New-Object Windows.Forms.CheckBox
    $chkAttentionOnly.Text = "Show Critical Events Only"
    $chkAttentionOnly.Location = New-Object Drawing.Point(10, 65)
    $chkAttentionOnly.Size = New-Object Drawing.Size(180, 20)
    $chkAttentionOnly.Checked = $false  # Default to showing all events

    $btnFetch = New-Button "Fetch & Analyze Logs" 400 65 150
    $btnExportCSV = New-Button "Export to CSV" 560 40 80
    $btnExportJSON = New-Button "Export to JSON" 650 40 80
    $btnExportReport = New-Button "Export Log Report" 740 40 110

    $grid = New-Object Windows.Forms.DataGridView
    $grid.Location = New-Object Drawing.Point(10, 100)
    $grid.Size = New-Object Drawing.Size(960, 580)
    $grid.Anchor = 'Top,Left,Right,Bottom'
    $grid.ReadOnly = $true
    $grid.AutoGenerateColumns = $true  # Let it auto-generate initially
    $grid.AutoSizeColumnsMode = 'Fill'
    $grid.AllowUserToAddRows = $false
    $grid.AllowUserToDeleteRows = $false
    $grid.SelectionMode = 'FullRowSelect'
    $grid.MultiSelect = $false

    $lblSummary = New-Label "Summary will appear here..." 10 690 960 60
    $lblSummary.AutoSize = $false
    $lblSummary.Anchor = 'Left,Right,Bottom'

    # --- Event Handlers ---
    $cellFormatEvent = Register-ObjectEvent -InputObject $grid -EventName CellFormatting -Action {
        try {
            if ($eventArgs.RowIndex -ge 0 -and $eventArgs.ColumnIndex -ge 0 -and $this.Rows -and $this.Rows.Count -gt $eventArgs.RowIndex) {
                $row = $this.Rows[$eventArgs.RowIndex]
                # Check if we have the Level column (our transformed column name)
                if ($row.Cells -and $row.Cells.Count -gt 1) {
                    $levelCell = $null
                    # Try to find the level cell by column name
                    foreach ($column in $this.Columns) {
                        if ($column.Name -eq 'Level' -and $row.Cells[$column.Index]) {
                            $levelCell = $row.Cells[$column.Index]
                            break
                        }
                    }
                    
                    if ($levelCell -and $levelCell.Value) {
                        $level = $levelCell.Value.ToString()
                        $eventArgs.CellStyle.BackColor = switch ($level) {
                            'Error'       { [Drawing.Color]::LightCoral }
                            'Warning'     { [Drawing.Color]::Khaki }
                            'Information' { [Drawing.Color]::LightGreen }
                            'Info'        { [Drawing.Color]::LightGreen }
                            default       { [Drawing.Color]::White }
                        }
                    }
                }
            }
        } catch {
            # Suppress CellFormatting errors to avoid spam
        }
    }

    # Double-click event to show full message details
    $grid.Add_CellDoubleClick({
        param($sender, $e)
        try {
            if ($e.RowIndex -ge 0 -and $e.RowIndex -lt $script:rawLogEntries.Count) {
                $selectedEntry = $script:rawLogEntries[$e.RowIndex]
                
                # Create a detail dialog
                $detailForm = New-Object Windows.Forms.Form
                $detailForm.Text = "Log Entry Details"
                $detailForm.Size = New-Object Drawing.Size(800, 500)
                $detailForm.StartPosition = "CenterParent"
                $detailForm.FormBorderStyle = [Windows.Forms.FormBorderStyle]::Sizable
                $detailForm.MinimumSize = New-Object Drawing.Size(600, 400)
                
                # Create a textbox for the full message
                $txtDetails = New-Object Windows.Forms.TextBox
                $txtDetails.Location = New-Object Drawing.Point(10, 10)
                $txtDetails.Size = New-Object Drawing.Size(760, 420)
                $txtDetails.Anchor = 'Top,Left,Right,Bottom'
                $txtDetails.Multiline = $true
                $txtDetails.ReadOnly = $true
                $txtDetails.ScrollBars = 'Both'
                $txtDetails.WordWrap = $true
                $txtDetails.Font = New-Object Drawing.Font("Consolas", 10)
                
                # Format the details
                $detailText = @"
Timestamp: $($selectedEntry.TimeCreated)
Level: $($selectedEntry.LevelDisplayName)
Provider: $($selectedEntry.ProviderName)
Event ID: $($selectedEntry.EventId)

=== Full Message ===
$($selectedEntry.Message)

"@
                
                # Add raw message if available and different
                if ($selectedEntry.PSObject.Properties['RawMessage'] -and $selectedEntry.RawMessage -and $selectedEntry.RawMessage -ne $selectedEntry.Message) {
                    $detailText += "`n=== Raw XML Message ===`n$($selectedEntry.RawMessage)"
                }
                
                $txtDetails.Text = $detailText
                
                # Add close button
                $btnClose = New-Object Windows.Forms.Button
                $btnClose.Text = "Close"
                $btnClose.Location = New-Object Drawing.Point(695, 440)
                $btnClose.Size = New-Object Drawing.Size(75, 25)
                $btnClose.Anchor = 'Bottom,Right'
                $btnClose.Add_Click({ $detailForm.Close() })
                
                $detailForm.Controls.AddRange(@($txtDetails, $btnClose))
                $detailForm.Add_KeyDown({
                    if ($_.KeyCode -eq 'Escape') {
                        $detailForm.Close()
                    }
                })
                
                [void]$detailForm.ShowDialog($form)
                $detailForm.Dispose()
            }
        } catch {
            [Windows.Forms.MessageBox]::Show("Error showing details: $($_.Exception.Message)", "Error", 'OK', 'Error')
        }
    })

    $btnFetch.Add_Click({
        try {
            Write-Host "[DEBUG] Starting log fetch with LogType: $($cmbLogType.SelectedItem)"
            
            # Clear previous data
            $script:logData = @()
            $script:rawLogEntries = @()
            $grid.DataSource = $null
            $grid.Columns.Clear()
            $lblSummary.Text = "Fetching logs..."
            
            $params = @{
                FetchLogs = $true
                LogType = $cmbLogType.SelectedItem.ToString()
                StartTime = $dtStart.Value
                EndTime = $dtEnd.Value
                AttentionOnly = $chkAttentionOnly.Checked
                Verbose = $true
            }
            if ($chkRedact.Checked) { $params.RedactSensitiveData = $true }
            if ($chkRedactLog.Checked) { $params.GenerateRedactionLog = $true }

            Write-Host "[DEBUG] Calling Invoke-SmartAnalyzer with params: $($params | ConvertTo-Json -Compress)"
            $result = Invoke-SmartAnalyzer @params -ErrorAction Stop
            
            if (-not $result -or -not $result.Entries) {
                Write-Warning "[DEBUG] No result or entries returned from Invoke-SmartAnalyzer"
                $lblSummary.Text = "No log entries found for the specified criteria."
                [Windows.Forms.MessageBox]::Show("No log entries found for the specified criteria. This could be due to:`n`n- Time range with no matching events`n- Security log access denied (requires Administrator)`n- Empty log files`n`nTry adjusting the time range or running as Administrator.", "No Data Found", 'OK', 'Information')
                return
            }

            $script:rawLogEntries = $result.Entries
            Write-Host "[DEBUG] Retrieved $($script:rawLogEntries.Count) raw log entries"

            if ($script:rawLogEntries.Count -eq 0) {
                $lblSummary.Text = "No log entries found for the specified criteria."
                [Windows.Forms.MessageBox]::Show("No log entries found for the specified criteria. This could be due to:`n`n- Time range with no matching events`n- Security log access denied (requires Administrator)`n- No matching events with AttentionOnly filter`n`nTry adjusting the time range, unchecking filters, or running as Administrator.", "No Data Found", 'OK', 'Information')
                return
            }

            # Transform data for the grid, handling potential null values
            $script:logData = $script:rawLogEntries | ForEach-Object {
                [pscustomobject]@{
                    Timestamp = if ($_.TimeCreated) { $_.TimeCreated.ToString("yyyy-MM-dd HH:mm:ss") } else { "Unknown" }
                    Level     = if ($_.LevelDisplayName) { $_.LevelDisplayName } else { "Unknown" }
                    Provider  = if ($_.ProviderName) { $_.ProviderName } else { "Unknown" }
                    EventId   = if ($_.EventId) { $_.EventId } else { "N/A" }
                    Message   = if ($_.Message) { $_.Message.Substring(0, [Math]::Min($_.Message.Length, 500)) } else { "No message" }
                }
            }
            
            Write-Host "[DEBUG] Transformed $($script:logData.Count) entries for display"

            # Convert to DataTable for proper DataGridView binding
            Write-Host "[DEBUG] Sample data for binding:" ($script:logData | Select-Object -First 1 | ConvertTo-Json -Compress)
            
            # Create DataTable
            $dataTable = New-Object System.Data.DataTable
            $dataTable.Columns.Add("Timestamp", [string]) | Out-Null
            $dataTable.Columns.Add("Level", [string]) | Out-Null
            $dataTable.Columns.Add("Provider", [string]) | Out-Null
            $dataTable.Columns.Add("EventId", [string]) | Out-Null
            $dataTable.Columns.Add("Message", [string]) | Out-Null
            
            # Populate DataTable
            foreach ($entry in $script:logData) {
                $row = $dataTable.NewRow()
                $row["Timestamp"] = $entry.Timestamp
                $row["Level"] = $entry.Level
                $row["Provider"] = $entry.Provider
                $row["EventId"] = $entry.EventId
                $row["Message"] = $entry.Message
                $dataTable.Rows.Add($row)
            }
            
            # Bind DataTable to grid
            $grid.AutoGenerateColumns = $true
            $grid.DataSource = $dataTable
            
            # Adjust column widths
            if ($grid.ColumnCount -gt 0) {
                $grid.Columns["Timestamp"].Width = 130
                $grid.Columns["Level"].Width = 90
                $grid.Columns["Provider"].Width = 200
                $grid.Columns["EventId"].Width = 80
                $grid.Columns["Message"].AutoSizeMode = 'Fill'
            }
            
            Write-Host "[DEBUG] Grid now has $($grid.RowCount) rows and $($grid.ColumnCount) columns"

            # Generate summary
            Write-Host "[DEBUG] Generating summary for $($result.Entries.Count) entries"
            $summary = Get-LogSummary -LogLines $result.Entries -ErrorAction Stop
            
            if ($summary) {
                $firstTs = if ($summary.FirstTimestamp) { $summary.FirstTimestamp.ToString("yyyy-MM-dd HH:mm:ss") } else { "Unknown" }
                $lastTs = if ($summary.LastTimestamp) { $summary.LastTimestamp.ToString("yyyy-MM-dd HH:mm:ss") } else { "Unknown" }
                $lblSummary.Text = "Total: $($summary.TotalLines)  |  Errors: $($summary.ErrorCount)  |  Warnings: $($summary.WarningCount)  |  Info: $($summary.InfoCount)  |  Other: $($summary.OtherCount)`nFrom: $firstTs  To: $lastTs"
            } else {
                $lblSummary.Text = "Summary generation failed"
            }
            
            Write-Host "[DEBUG] Log fetch completed successfully"
        } catch {
            Write-Host "[DEBUG] Error in btnFetch.Add_Click: $($_.Exception.Message)"
            Write-Host "[DEBUG] Stack trace: $($_.ScriptStackTrace)"
            $lblSummary.Text = "Error occurred while fetching logs."
            [Windows.Forms.MessageBox]::Show("Failed to fetch logs:`n`n$($_.Exception.Message)`n`nIf accessing Security logs, try running PowerShell as Administrator.", "Error", 'OK', 'Error')
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

    # Form resize handler for proper control positioning
    $form.Add_Resize({
        try {
            $formWidth = $form.ClientSize.Width
            $formHeight = $form.ClientSize.Height
            
            # Adjust grid size and summary position
            $grid.Size = New-Object Drawing.Size(($formWidth - 20), ($formHeight - 170))
            $lblSummary.Location = New-Object Drawing.Point(10, ($formHeight - 80))
            $lblSummary.Size = New-Object Drawing.Size(($formWidth - 20), 60)
        } catch {
            # Suppress resize errors
        }
    })

    $form.Controls.AddRange(@(
        $lblLogType, $cmbLogType,
        $lblStartTime, $dtStart,
        $lblEndTime, $dtEnd,
        $chkRedact, $chkRedactLog, $chkAttentionOnly,
        $btnFetch, $btnExportCSV, $btnExportJSON, $btnExportReport,
        $grid, $lblSummary
    ))

    Write-Host "[DEBUG] Displaying form"
    [void]$form.ShowDialog()
    $form.Dispose()

    Unregister-Event -SourceIdentifier $cellFormatEvent.Name
    Remove-Job -Id $cellFormatEvent.Id -Force

    Write-Host "[DEBUG] Show-LogAnalyzerUI finished"
    # exit gracefully without relying on $LASTEXITCODE
}

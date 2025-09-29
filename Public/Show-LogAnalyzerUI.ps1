
function Show-LogAnalyzerUI {
    [CmdletBinding()]
    param()

    begin {
        Write-Verbose "Initializing Show-LogAnalyzerUI..."

        # Check if running on Windows
        $isWindowsOS = if ($PSVersionTable.PSVersion.Major -ge 6) {
            $IsWindows
        } else {
            $env:OS -eq 'Windows_NT'
        }

        if (-not $isWindowsOS) {
            throw "The Smart Log Analyzer UI is only supported on Windows."
        }

        # Load required assemblies with proper error handling
        try {
            Write-Verbose "Loading required assemblies..."
            if (-not ('System.Windows.Forms.Form' -as [Type])) {
                Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
            }
            if (-not ('System.Drawing.Bitmap' -as [Type])) {
                Add-Type -AssemblyName System.Drawing -ErrorAction Stop
            }
        }
        catch {
            throw "Failed to load Windows Forms assemblies. Error: $($_.Exception.Message)"
        }

        # Verify assemblies are loaded
        $requiredTypes = @(
            'System.Windows.Forms.Form',
            'System.Windows.Forms.Button',
            'System.Windows.Forms.Label',
            'System.Windows.Forms.TextBox',
            'System.Windows.Forms.Timer',
            'System.Drawing.Point',
            'System.Drawing.Size'
        )

        foreach ($type in $requiredTypes) {
            if (-not ($type -as [Type])) {
                throw "Required type [$type] could not be loaded. Please ensure .NET Framework is properly installed."
            }
        }
    }

    # Load required assemblies
    try {
        Add-Type -AssemblyName System.Windows.Forms
        Add-Type -AssemblyName System.Drawing
        Add-Type -AssemblyName System.Data
    } catch {
        throw "Failed to load required assemblies: $($_.Exception.Message)"
    }

    # Initialize global variables
    $script:logData = New-Object System.Data.DataTable
    $script:rawLogEntries = @()
    $script:allLogs = @()
    $script:allEvents = @()
    $script:fetchJob = $null
    $script:fetchJobResult = $null
    $script:fetchJobError = $null
    $script:fetching = $false
    $script:ErrorLog = @()
    $script:UserSettings = @{}
    $script:Presets = @()

    # Load configuration
    $presetPath = Join-Path $env:APPDATA 'SmartLogAnalyzerPresets.json'
    if (Test-Path $presetPath) {
        try {
            $script:Presets = Get-Content $presetPath | ConvertFrom-Json
        } catch {
            Write-Warning "Failed to load presets: $($_.Exception.Message)"
        }
    }

    # Initialize UI strings
    $script:uiStrings = @{
        Help = "Show help and about information"
        ErrorLog = "View application error log"
        SavePreset = "Save current time range as preset"
        LoadPreset = "Load a saved time range preset"
    }

    process {
        Write-Verbose "Creating UI controls..."

        # Initialize UI strings
        $script:uiStrings = @{
            Help = "Show help and about information"
            ErrorLog = "View error log"
            SavePreset = "Save current time range as preset"
            LoadPreset = "Load a saved time range preset"
        }

        # Create main form first
        $script:form = New-Object -TypeName System.Windows.Forms.Form -Property @{
            Text = "Smart Log Analyzer - Enhanced Multi-Function UI"
            Size = New-Object System.Drawing.Size(1200, 850)
            StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
            MinimumSize = New-Object System.Drawing.Size(1000, 700)
            FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::Sizable
        }

        # Initialize core controls
        $script:autoRefreshTimer = New-Object System.Windows.Forms.Timer
        $script:toolTip = New-Object System.Windows.Forms.ToolTip

    function New-EventLogsTab {
        param(
            [ref]$dtStart,
            [ref]$dtEnd,
            [ref]$grid,
            [ref]$tabEventLogs
        )
        # ...existing code for event logs tab controls and handlers...
    }

    function New-FileAnalysisTab {
        param(
            [ref]$gridFile,
            [ref]$tabFileAnalysis
        )
        # ...existing code for file analysis tab controls and handlers...

        # Drag & Drop file support
        $txtFilePath.AllowDrop = $true
        $txtFilePath.add_DragEnter({
            if ($_.Data.GetDataPresent([Windows.Forms.DataFormats]::FileDrop)) {
                $_.Effect = [Windows.Forms.DragDropEffects]::Copy
            }
        })
        $txtFilePath.add_DragDrop({
            $files = $_.Data.GetData([Windows.Forms.DataFormats]::FileDrop)
            if ($files -and $files.Length -gt 0) { $txtFilePath.Text = $files[0] }
        })
    }

    function New-UtilitiesTab {
        param(
            [ref]$tabUtilities
        )
        # ...existing code for utilities tab controls and handlers...
    }

    function Set-TimeRange {
        param([int]$hours, [ref]$dtStart, [ref]$dtEnd)
        $dtStart.Value = (Get-Date).AddHours(-$hours)
        $dtEnd.Value = Get-Date
    }

    # ...existing code for Show-LogAnalyzerUI...

    # ...existing code for Show-LogAnalyzerUI...
        $preset = @{ Start = $dtStart.Value; End = $dtEnd.Value }
        $script:Presets = @($preset) + ($script:Presets | Where-Object { $_.Start -ne $preset.Start -or $_.End -ne $preset.End })
        $script:Presets = $script:Presets | Select-Object -First 10
        $script:Presets | ConvertTo-Json | Set-Content $presetPath
    }
    $btnLoadPreset.Add_Click({
        if ($script:Presets.Count -eq 0) { return }
        $dlg = New-Object Windows.Forms.Form; $dlg.Text = 'Load Preset'; $dlg.Size = New-Object Drawing.Size(300,200)
        $lb = New-Object Windows.Forms.ListBox; $lb.Location = New-Object Drawing.Point(10,10); $lb.Size = New-Object Drawing.Size(260,100)
        foreach ($p in $script:Presets) { $lb.Items.Add("$($p.Start) - $($p.End)") | Out-Null }
        $btnOK = New-Object Windows.Forms.Button; $btnOK.Text = 'OK'; $btnOK.Location = New-Object Drawing.Point(100,120)
        $btnOK.Add_Click({
            if ($lb.SelectedIndex -ge 0) {
                $dtStart.Value = $script:Presets[$lb.SelectedIndex].Start
                $dtEnd.Value = $script:Presets[$lb.SelectedIndex].End
            }
            $dlg.Close()
        })
        $dlg.Controls.AddRange(@($lb,$btnOK)); [void]$dlg.ShowDialog($form)
    })
    # --- Integrated help/about dialog ---
    $btnHelp = New-Object System.Windows.Forms.Button
    $btnHelp.Text = 'Help/About'
    $btnHelp.Location = New-Object System.Drawing.Point(400, 10)
    $btnHelp.Size = New-Object System.Drawing.Size(90, 30)
    $toolTip.SetToolTip($btnHelp, $uiStrings.Help)
    $btnHelp.Add_Click({
        $dlg = New-Object Windows.Forms.Form; $dlg.Text = 'Help/About'; $dlg.Size = New-Object Drawing.Size(500,400)
        $txt = New-Object Windows.Forms.TextBox; $txt.Multiline = $true; $txt.ReadOnly = $true; $txt.Dock = 'Fill';
        $txt.Text = "Smart Log Analyzer`r`n`r`n- Use the Fetch button to load logs.`r`n- Use the search/filter controls to refine results.`r`n- Right-click a row for more options.`r`n- Keyboard shortcuts: Ctrl+F (search), F5 (refresh), Esc (close details).`r`n- Visit https://github.com/Dream-Hoarder/SLAnalyzer for docs.";
        $dlg.Controls.Add($txt); [void]$dlg.ShowDialog($form)
    })
    # --- Error reporting UI ---
    $btnErrorLog = New-Object System.Windows.Forms.Button
    $btnErrorLog.Text = 'Error Log'
    $btnErrorLog.Location = New-Object System.Drawing.Point(300, 10)
    $btnErrorLog.Size = New-Object System.Drawing.Size(90, 30)
    $toolTip.SetToolTip($btnErrorLog, $uiStrings.ErrorLog)
    $btnErrorLog.Add_Click({
        $dlg = New-Object Windows.Forms.Form; $dlg.Text = 'Error Log'; $dlg.Size = New-Object Drawing.Size(600,400)
        $txt = New-Object Windows.Forms.TextBox; $txt.Multiline = $true; $txt.ReadOnly = $true; $txt.Dock = 'Fill'; $txt.Text = ($script:ErrorLog -join "`r`n")
        $dlg.Controls.Add($txt); [void]$dlg.ShowDialog($form)
    })
    # --- Initialize all UI controls ---
    # Main form
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Smart Log Analyzer - Enhanced Multi-Function UI"
    $form.Size = New-Object System.Drawing.Size(1200, 850)
    $form.StartPosition = "CenterScreen"
    $form.MinimumSize = New-Object System.Drawing.Size(1000, 700)
    $form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::Sizable

    # Initialize common controls
    $toolTip = New-Object System.Windows.Forms.ToolTip
    $autoRefreshTimer = New-Object System.Windows.Forms.Timer

        # Initialize buttons using Property parameter for atomic initialization
        $script:btnSavePreset = New-Object System.Windows.Forms.Button -Property @{
            Text = "Save Preset"
            Location = New-Object System.Drawing.Point(860, 45)
            Size = New-Object System.Drawing.Size(90, 25)
        }

        $script:btnLoadPreset = New-Object System.Windows.Forms.Button -Property @{
            Text = "Load Preset"
            Location = New-Object System.Drawing.Point(955, 45)
            Size = New-Object System.Drawing.Size(90, 25)
        }

        $script:btnHelp = New-Object System.Windows.Forms.Button -Property @{
            Text = "Help/About"
            Location = New-Object System.Drawing.Point(400, 10)
            Size = New-Object System.Drawing.Size(90, 30)
        }

        $script:btnErrorLog = New-Object System.Windows.Forms.Button -Property @{
            Text = "Error Log"
            Location = New-Object System.Drawing.Point(300, 10)
            Size = New-Object System.Drawing.Size(90, 30)
        }

        # Add buttons to form
        $form.Controls.AddRange(@(
            $script:btnSavePreset,
            $script:btnLoadPreset,
            $script:btnHelp,
            $script:btnErrorLog
        ))

    $btnLoadPreset = New-Object System.Windows.Forms.Button
    $btnLoadPreset.Text = "Load Preset"
    $btnLoadPreset.Location = New-Object System.Drawing.Point(955, 45)
    $btnLoadPreset.Size = New-Object System.Drawing.Size(90, 25)

    $btnHelp = New-Object System.Windows.Forms.Button
    $btnHelp.Text = "Help/About"
    $btnHelp.Location = New-Object System.Drawing.Point(400, 10)
    $btnHelp.Size = New-Object System.Drawing.Size(90, 30)

    $btnErrorLog = New-Object System.Windows.Forms.Button
    $btnErrorLog.Text = "Error Log"
    $btnErrorLog.Location = New-Object System.Drawing.Point(300, 10)
    $btnErrorLog.Size = New-Object System.Drawing.Size(90, 30)

    # --- Performance metrics in status bar ---
    $lblPerf = New-Object System.Windows.Forms.Label
    $lblPerf.Text = ''
    $lblPerf.Location = New-Object System.Drawing.Point(10, 830)
    $lblPerf.Size = New-Object System.Drawing.Size(800, 20)
    $form.Controls.Add($lblPerf)
    function Update-Perf {
        $mem = [math]::Round(([System.Diagnostics.Process]::GetCurrentProcess().WorkingSet64/1MB),1)
        $rows = if ($grid) { $grid.RowCount } else { 0 }
        $lblPerf.Text = "Rows: $rows | Memory: $mem MB | $(Get-Date -Format 'HH:mm:ss')"
    }
    if ($btnFetch) { $btnFetch.Add_Click({ Update-Perf }) }
    $autoRefreshTimer.Add_Tick({ Update-Perf })
    # --- Tooltips for UI controls ---
    if ($btnTheme) { $toolTip.SetToolTip($btnTheme, 'Toggle between light and dark mode') }
    if ($btnFetch) { $toolTip.SetToolTip($btnFetch, 'Fetch and analyze logs') }
    if ($btnExportCSV) { $toolTip.SetToolTip($btnExportCSV, 'Export visible logs to CSV') }
    if ($btnExportJSON) { $toolTip.SetToolTip($btnExportJSON, 'Export visible logs to JSON') }
    if ($btnExportReport) { $toolTip.SetToolTip($btnExportReport, 'Export a detailed log report') }
    if ($chkRedact) { $toolTip.SetToolTip($chkRedact, 'Redact sensitive data from logs') }
    if ($chkRedactLog) { $toolTip.SetToolTip($chkRedactLog, 'Generate a redaction log file') }
    if ($chkAttentionOnly) { $toolTip.SetToolTip($chkAttentionOnly, 'Show only critical events') }
    if ($txtSearch) { $toolTip.SetToolTip($txtSearch, 'Type to filter log messages') }
    if ($cmbLevelFilter) { $toolTip.SetToolTip($cmbLevelFilter, 'Filter logs by level') }
    if ($txtProviderFilter) { $toolTip.SetToolTip($txtProviderFilter, 'Filter logs by provider name') }
    if ($txtFilePath) { $toolTip.SetToolTip($txtFilePath, 'Enter or drop a log file path') }
    # --- Recent Files / Presets ---
    $configPath = Join-Path $env:APPDATA 'SmartLogAnalyzerConfig.json'
    $script:RecentFiles = @()
    if (Test-Path $configPath) {
        try { $cfg = Get-Content $configPath | ConvertFrom-Json; $script:RecentFiles = $cfg.RecentFiles } catch {}
    }
    function Save-RecentFile($file) {
        if ($file -and -not ($script:RecentFiles -contains $file)) {
            $script:RecentFiles = @($file) + ($script:RecentFiles | Where-Object { $_ -ne $file })
            $script:RecentFiles = $script:RecentFiles | Select-Object -First 10
            $out = @{ RecentFiles = $script:RecentFiles } | ConvertTo-Json
            $out | Set-Content $configPath
        }
    }
    # Save file to recent on browse or analyze
    if ($btnBrowseFile) { $btnBrowseFile.Add_Click({ Save-RecentFile $txtFilePath.Text }) }
    if ($btnAnalyzeFile) {
        $btnAnalyzeFile.Add_Click({
        Save-RecentFile $txtFilePath.Text
        $file = $txtFilePath.Text
        if (-not (Test-Path $file)) {
            $lblFileSummary.Text = "File not found."
            return
        }
        $fileSizeMB = [math]::Round((Get-Item $file).Length / 1MB, 2)
        $lines = Get-Content $file -Raw | Out-String
        $lines = $lines -split "`r?`n"
        $result = @()
        if ($fileSizeMB -gt 5) {
            # Multi-threaded parsing for large files
            $numThreads = [Math]::Min([Environment]::ProcessorCount, 8)
            $chunkSize = [Math]::Ceiling($lines.Count / $numThreads)
            $jobs = @()
            for ($i=0; $i -lt $numThreads; $i++) {
                $start = $i * $chunkSize
                $end = [Math]::Min($start + $chunkSize, $lines.Count)
                if ($start -ge $lines.Count) { break }
                $chunk = $lines[$start..($end-1)]
                $jobs += Start-Job -ScriptBlock {
                    param($chunk)
                    # Simulate parsing: return lines as-is (replace with real parser)
                    return $chunk
                } -ArgumentList @(,$chunk)
            }
            $result = $jobs | ForEach-Object { Receive-Job -Job $_ -Wait }
            $jobs | ForEach-Object { Remove-Job -Job $_ -Force }
            $result = $result | Where-Object { $_ }
            $lblFileSummary.Text = "Multi-threaded parse complete ($fileSizeMB MB, $numThreads threads)."
        } else {
            $result = $lines
            $lblFileSummary.Text = "Single-threaded parse complete ($fileSizeMB MB)."
        }
        # ...existing logic for filtering, parsing, and displaying log entries using $result...
        # For demonstration, just show first 100 lines in gridFile
        $gridFile.DataSource = $result | Select-Object -First 100 | ForEach-Object { [pscustomobject]@{ Line = $_ } }
    })
    # --- Context Menu for Grid ---
    $gridContextMenu = New-Object Windows.Forms.ContextMenuStrip
    $copyMsgItem = $gridContextMenu.Items.Add('Copy Full Message')
    $exportEntryItem = $gridContextMenu.Items.Add('Export Entry')
    $openDetailsItem = $gridContextMenu.Items.Add('Open Details')
    if ($grid) {
        $grid.MouseDown += {
            if ($_.Button -eq 'Right') {
                $pos = $grid.PointToClient([Windows.Forms.Cursor]::Position)
                $hit = $grid.HitTest($pos.X, $pos.Y)
                if ($hit.RowIndex -ge 0) {
                    $grid.ClearSelection(); $grid.Rows[$hit.RowIndex].Selected = $true
                    $gridContextMenu.Show($grid, $pos)
                }
            }
        }
    }
    if ($copyMsgItem) {
        $copyMsgItem.Click.Add({
            $rowIdx = $grid.SelectedCells[0].RowIndex
            $msg = $script:rawLogEntries[$rowIdx].Message
            [Windows.Forms.Clipboard]::SetText($msg)
        })
    }
    if ($exportEntryItem) {
        $exportEntryItem.Click.Add({
            $rowIdx = $grid.SelectedCells[0].RowIndex
            $entry = $script:rawLogEntries[$rowIdx]
            $save = New-Object Windows.Forms.SaveFileDialog
            $save.Filter = 'Text Files (*.txt)|*.txt|All Files (*.*)|*.*'
            $save.FileName = "LogEntry_$($entry.EventId)_$($entry.TimeCreated.ToString('yyyyMMdd_HHmmss')).txt"
            if ($save.ShowDialog() -eq [Windows.Forms.DialogResult]::OK) {
                $entry.Message | Set-Content $save.FileName
            }
        })
    }
    if ($openDetailsItem) {
        $openDetailsItem.Click.Add({
            $rowIdx = $grid.SelectedCells[0].RowIndex
            # Reuse double-click logic
            $grid.Rows[$rowIdx].Selected = $true
            $grid.OnCellDoubleClick.Invoke($grid, (New-Object Windows.Forms.DataGridViewCellEventArgs($grid.CurrentCell.ColumnIndex, $rowIdx)))
        })
    }
    # --- Keyboard Shortcuts ---
    $form.KeyPreview = $true
    $form.Add_KeyDown({
        if ($_.Control -and $_.KeyCode -eq 'F') { $txtSearch.Focus() }
        elseif ($_.KeyCode -eq 'F5') { $btnFetch.PerformClick() }
    })
    # Esc closes detail view is handled in detail form logic
    # --- Theme Support ---
    $theme = 'Light' # Default theme
    function Set-Theme {
        param($mode)
        $theme = $mode
        $bg = if ($mode -eq 'Dark') { [Drawing.Color]::FromArgb(30,30,30) } else { [Drawing.Color]::White }
        $fg = if ($mode -eq 'Dark') { [Drawing.Color]::WhiteSmoke } else { [Drawing.Color]::Black }
        $form.BackColor = $bg; $form.ForeColor = $fg
        foreach ($ctrl in $form.Controls) { $ctrl.BackColor = $bg; $ctrl.ForeColor = $fg }
        foreach ($tab in $tabControl.TabPages) { $tab.BackColor = $bg; $tab.ForeColor = $fg }
        foreach ($ctrl in $tabEventLogs.Controls) { $ctrl.BackColor = $bg; $ctrl.ForeColor = $fg }
        foreach ($ctrl in $tabFileAnalysis.Controls) { $ctrl.BackColor = $bg; $ctrl.ForeColor = $fg }
        foreach ($ctrl in $tabUtilities.Controls) { $ctrl.BackColor = $bg; $ctrl.ForeColor = $fg }
        $grid.BackgroundColor = $bg; $grid.ForeColor = $fg
        $gridFile.BackgroundColor = $bg; $gridFile.ForeColor = $fg
    }

    $btnTheme = New-Object System.Windows.Forms.Button
    $btnTheme.Text = 'Toggle Theme'
    $btnTheme.Location = New-Object System.Drawing.Point(1050, 10)
    $btnTheme.Size = New-Object System.Drawing.Size(120, 30)
    $btnTheme.Add_Click({
        if ($theme -eq 'Light') { Set-Theme 'Dark' } else { Set-Theme 'Light' }
    })
    # --- Filtering & Searching Controls ---
    $lblSearch = New-Object System.Windows.Forms.Label
    $lblSearch.Text = 'Search:'
    $lblSearch.Location = New-Object System.Drawing.Point(10, 95)
    $lblSearch.Size = New-Object System.Drawing.Size(50, 20)
    $txtSearch = New-Object System.Windows.Forms.TextBox
    $txtSearch.Location = New-Object Drawing.Point(65,95)
    $txtSearch.Size = New-Object Drawing.Size(200,20)

    $lblLevelFilter = New-Object System.Windows.Forms.Label
    $lblLevelFilter.Text = 'Level:'
    $lblLevelFilter.Location = New-Object System.Drawing.Point(280, 95)
    $lblLevelFilter.Size = New-Object System.Drawing.Size(45, 20)
    $cmbLevelFilter = New-Object System.Windows.Forms.ComboBox
    $cmbLevelFilter.Location = New-Object Drawing.Point(330,95)
    $cmbLevelFilter.Size = New-Object Drawing.Size(110,20)
    $cmbLevelFilter.DropDownStyle = 'DropDownList'
    $defaultLevels = @('All','Critical','Error','Warning','Information','Verbose')
    $cmbLevelFilter.Items.AddRange($defaultLevels)
    $cmbLevelFilter.SelectedIndex = 0

    $lblProviderFilter = New-Object System.Windows.Forms.Label
    $lblProviderFilter.Text = 'Provider:'
    $lblProviderFilter.Location = New-Object System.Drawing.Point(440, 95)
    $lblProviderFilter.Size = New-Object System.Drawing.Size(60, 20)
    $txtProviderFilter = New-Object System.Windows.Forms.TextBox
    $txtProviderFilter.Location = New-Object Drawing.Point(505,95)
    $txtProviderFilter.Size = New-Object Drawing.Size(120,20)
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
            # 1️⃣ Export normally via the provided scriptblock
            & $ExportBlock $save.FileName

            # 2️⃣ Compute hash for integrity
            if ($Format -eq "CSV") {
                # Read CSV content without any hash lines
                $content = Get-Content -Path $save.FileName | Where-Object { $_ -notmatch '^#HASH:' }

                # Compute SHA256 hash of CSV content
                $hash = [System.BitConverter]::ToString(
                    (New-Object System.Security.Cryptography.SHA256Managed).ComputeHash(
                        [System.Text.Encoding]::UTF8.GetBytes(($content -join "`n"))
                    )
                ) -replace '-', ''

                # Prepend the hash line at the top
                $finalContent = @("#HASH:$hash") + $content
                Set-Content -Path $save.FileName -Value $finalContent

                # ✅ Optional: Verify immediately after writing
                $verifyContent = Get-Content -Path $save.FileName | Select-Object -Skip 1
                $verifyHash = [System.BitConverter]::ToString(
                    (New-Object System.Security.Cryptography.SHA256Managed).ComputeHash(
                        [System.Text.Encoding]::UTF8.GetBytes(($verifyContent -join "`n"))
                    )
                ) -replace '-', ''

                if ($verifyHash -ne $hash) {
                    [Windows.Forms.MessageBox]::Show("⚠ Warning: Hash verification failed!", "Integrity Check", 'OK', 'Warning')
                } else {
                    Write-Host "[DEBUG] Hash verified successfully for $($save.FileName)"
                }

            } elseif ($Format -eq "JSON") {
                # Read raw JSON data
                $dataJson = Get-Content -Path $save.FileName -Raw

                # Compute SHA256 of JSON string
                $hash = [System.BitConverter]::ToString(
                    (New-Object System.Security.Cryptography.SHA256Managed).ComputeHash(
                        [System.Text.Encoding]::UTF8.GetBytes($dataJson)
                    )
                ) -replace '-', ''

                # Wrap JSON in object with embedded hash
                $finalJson = @{
                    Data = $script:logData
                    Hash = $hash
                } | ConvertTo-Json -Depth 5

                # Overwrite the file
                Set-Content -Path $save.FileName -Value $finalJson
            }

            [Windows.Forms.MessageBox]::Show("Exported to $Format successfully with embedded hash.", "Export Complete", 'OK', 'Information')
        } catch {
            [Windows.Forms.MessageBox]::Show("Export failed: $($_.Exception.Message)", "Export Error", 'OK', 'Error')
        }
    }
}



    # --- Initialize Script Variables ---
    Add-Type -AssemblyName System.Data
    [System.Data.DataTable]$script:logData = @()
    [object[]]$script:rawLogEntries = @()
    [string[]]$script:allLogs = @()
    [object[]]$script:allEvents = @()
    $script:fetchJob = $null
    $script:fetchJobResult = $null
    $script:fetchJobError = $null
    $script:fetching = $false
    $script:ErrorLog = @()

    # --- Enumerate all logs at module initialization ---
    try {
        $classicLogs = Get-EventLog -List | Select-Object -ExpandProperty Log
        $modernLogs  = Get-WinEvent -ListLog * | Where-Object { $_.RecordCount -gt 0 } | Select-Object -ExpandProperty LogName
        $script:allLogs = ($classicLogs + $modernLogs) | Sort-Object -Unique
    } catch {
        $script:allLogs = @('System','Application','Security')
        $script:ErrorLog += "[LOG ENUM ERROR] $($_.Exception.Message)"
    }

    # --- Form Setup ---
    $form = New-Object Windows.Forms.Form
    $form.Text = "Smart Log Analyzer - Enhanced Multi-Function UI"
    $form.Size = New-Object Drawing.Size(1200, 850)
    $form.StartPosition = "CenterScreen"
    $form.MinimumSize = New-Object Drawing.Size(1000, 700)
    $form.FormBorderStyle = [Windows.Forms.FormBorderStyle]::Sizable

    # --- Create TabControl ---
    $tabControl = New-Object Windows.Forms.TabControl
    $tabControl.Location = New-Object Drawing.Point(5, 5)
    $tabControl.Size = New-Object Drawing.Size(1180, 800)
    $tabControl.Anchor = 'Top,Left,Right,Bottom'

    # --- Create Tab Pages ---
    $tabEventLogs = New-Object Windows.Forms.TabPage
    $tabEventLogs.Text = "Event Log Analysis"
    $tabFileAnalysis = New-Object Windows.Forms.TabPage
    $tabFileAnalysis.Text = "Log File Analysis"
    $tabUtilities = New-Object Windows.Forms.TabPage
    $tabUtilities.Text = "Utilities"
    $tabControl.TabPages.AddRange(@($tabEventLogs, $tabFileAnalysis, $tabUtilities))

    # Modularize tab creation
    New-EventLogsTab -dtStart ([ref]$dtStart) -dtEnd ([ref]$dtEnd) -grid ([ref]$grid) -tabEventLogs ([ref]$tabEventLogs)
    New-FileAnalysisTab -gridFile ([ref]$gridFile) -tabFileAnalysis ([ref]$tabFileAnalysis)
    New-UtilitiesTab -tabUtilities ([ref]$tabUtilities)

    # =============================================================================
    # TAB 1: EVENT LOG ANALYSIS (using Invoke-SmartAnalyzer + Get-SystemLogs)
    # =============================================================================

    # --- Event Logs Tab Controls ---
    # (Log type selection removed; always aggregate all logs)

    $lblStartTime = New-Label "Start Time:" 210 20 70
    $dtStart = New-Object Windows.Forms.DateTimePicker
    $dtStart.Format = 'Custom'
    $dtStart.CustomFormat = "yyyy-MM-dd HH:mm"
    $dtStart.Location = New-Object Drawing.Point(280, 20)
    $dtStart.Size = New-Object Drawing.Size(140, 20)
    # Set minimum date to 6 months ago to support historical log analysis
    $dtStart.MinDate = (Get-Date).AddMonths(-6)
    $dtStart.MaxDate = Get-Date
    # Default to 24 hours ago for reasonable performance, but allow user to go back 6 months
    $dtStart.Value = (Get-Date).AddDays(-1)

    $lblEndTime = New-Label "End Time:" 430 20 65
    $dtEnd = New-Object Windows.Forms.DateTimePicker
    $dtEnd.Format = 'Custom'
    $dtEnd.CustomFormat = "yyyy-MM-dd HH:mm"
    $dtEnd.Location = New-Object Drawing.Point(500, 20)
    $dtEnd.Size = New-Object Drawing.Size(140, 20)
    # Set date range to support 6 months of historical data
    $dtEnd.MinDate = (Get-Date).AddMonths(-6)
    $dtEnd.MaxDate = Get-Date
    $dtEnd.Value = Get-Date

    $chkRedact = New-Object Windows.Forms.CheckBox
    $chkRedact.Text = "Redact Sensitive Data"
    $chkRedact.Location = New-Object Drawing.Point(10, 50)
    $chkRedact.Size = New-Object Drawing.Size(180, 20)

    $chkRedactLog = New-Object Windows.Forms.CheckBox
    $chkRedactLog.Text = "Generate Redaction Log"
    $chkRedactLog.Location = New-Object Drawing.Point(200, 50)
    $chkRedactLog.Size = New-Object Drawing.Size(180, 20)

    $chkAttentionOnly = New-Object Windows.Forms.CheckBox
    $chkAttentionOnly.Text = "Show Critical Events Only"
    $chkAttentionOnly.Location = New-Object Drawing.Point(10, 75)
    $chkAttentionOnly.Size = New-Object Drawing.Size(180, 20)
    $chkAttentionOnly.Checked = $false  # Default to showing all events

    # Add time range preset buttons
    $lblPresets = New-Label "Quick Time Ranges:" 660 20 120
    $btn1Hour = New-Button "1h" 660 45 35 25
    $btn24Hours = New-Button "24h" 700 45 35 25
    $btn7Days = New-Button "7d" 740 45 35 25
    $btn30Days = New-Button "30d" 780 45 35 25
    $btn6Months = New-Button "6mo" 820 45 35 25

    # Add informational label about extended date range
    $lblInfo = New-Object Windows.Forms.Label
    $lblInfo.Text = "💡 Can analyze logs up to 6 months back (large ranges may take longer)"
    $lblInfo.Location = New-Object Drawing.Point(680, 75)
    $lblInfo.Size = New-Object Drawing.Size(300, 20)
    $lblInfo.ForeColor = [Drawing.Color]::DarkBlue
    $lblInfo.Font = New-Object Drawing.Font("Arial", 8, [Drawing.FontStyle]::Italic)

    $btnFetch = New-Button "Fetch & Analyze Logs" 200 75 150 30
    $btnExportCSV = New-Button "Export to CSV" 360 75 90 30
    $btnExportExcel = New-Button "Export to Excel" 460 75 110 30
    $btnExportJSON = New-Button "Export to JSON" 460 75 90 30
    $btnExportReport = New-Button "Export Log Report" 560 75 110 30
    $btnRedactPreview = New-Button "Preview Redaction" 680 75 130 30

    $grid = New-Object Windows.Forms.DataGridView
    $grid.Location = New-Object Drawing.Point(10, 110)
    $grid.Size = New-Object Drawing.Size(1140, 550)
    $grid.Anchor = 'Top,Left,Right,Bottom'
    $grid.ReadOnly = $true
    $grid.VirtualMode = $true
    $grid.AutoGenerateColumns = $true
    $grid.AutoSizeColumnsMode = 'Fill'
    $grid.AllowUserToAddRows = $false
    $grid.AllowUserToDeleteRows = $false
    $grid.SelectionMode = 'FullRowSelect'
    $grid.MultiSelect = $false
    # --- VirtualMode: CellValueNeeded handler ---
    $grid.add_CellValueNeeded({
        param($src, $e)
        try {
            if ($script:logData -and $e.RowIndex -ge 0 -and $e.RowIndex -lt $script:logData.Count) {
                $row = $script:logData[$e.RowIndex]
                switch ($e.ColumnIndex) {
                    0 { $e.Value = $row.Timestamp }
                    1 { $e.Value = $row.Level }
                    2 { $e.Value = $row.Provider }
                    3 { $e.Value = $row.EventId }
                    4 { $e.Value = if ($row.Message) { $row.Message.Substring(0, [Math]::Min($row.Message.Length, 500)) } else { "No message" } }
                }
            }
        } catch {}
    })

    $lblSummary = New-Label "Summary will appear here..." 10 670 1140 50
    $lblSummary.AutoSize = $false
    $lblSummary.Anchor = 'Left,Right,Bottom'

    # --- Chart for error counts over time ---
    $chart = $null
    try {
        $chart = New-Object Windows.Forms.DataVisualization.Charting.Chart
        $chart.Size = New-Object Drawing.Size(1140, 120)
        $chart.Location = New-Object Drawing.Point(10, 720)
        $chart.Anchor = 'Left,Right,Bottom'
        $chartArea = New-Object Windows.Forms.DataVisualization.Charting.ChartArea
        $chartArea.AxisX.Title = 'Time'
        $chartArea.AxisY.Title = 'Error Count'
        $chart.ChartAreas.Add($chartArea)
        $series = New-Object Windows.Forms.DataVisualization.Charting.Series 'Errors'
        $series.ChartType = 'Column'
        $series.Color = [Drawing.Color]::LightCoral
        $chart.Series.Add($series)
    } catch {}

    # Add all Event Logs controls to the tab
    $tabEventLogs.Controls.AddRange(@(
        $lblStartTime, $dtStart, $lblEndTime, $dtEnd,
        $lblPresets, $btn1Hour, $btn24Hours, $btn7Days, $btn30Days, $btn6Months, $lblInfo,
        $chkRedact, $chkRedactLog, $chkAttentionOnly,
        $btnFetch, $btnExportCSV, $btnExportExcel, $btnExportJSON, $btnExportReport, $btnRedactPreview,
        $btnTheme,
        $lblSearch, $txtSearch, $lblLevelFilter, $cmbLevelFilter, $lblProviderFilter, $txtProviderFilter,
        $grid, $lblSummary, $chart
    ))
    $btnRedactPreview.Add_Click({
        if (-not $script:rawLogEntries -or $script:rawLogEntries.Count -eq 0) {
            Show-ExportStatus 'No log data to redact.'
            return
        }
        # Simulate redaction: replace emails and IPs with [REDACTED]
        $redacted = $script:rawLogEntries | ForEach-Object {
            $msg = $_.Message -replace '\b[\w.-]+@[\w.-]+\.[a-zA-Z]{2,6}\b', '[REDACTED]'
            $msg = $msg -replace '\b\d{1,3}(?:\.\d{1,3}){3}\b', '[REDACTED]'
            [pscustomobject]@{
                Timestamp = $_.TimeCreated
                Level = $_.LevelDisplayName
                Provider = $_.ProviderName
                EventId = $_.EventId
                Message = $msg
            }
        }
        $dlg = New-Object Windows.Forms.Form
        $dlg.Text = 'Redaction Preview'
        $dlg.Size = New-Object Drawing.Size(900,600)
        $dlg.StartPosition = 'CenterParent'
        $gridPreview = New-Object Windows.Forms.DataGridView
        $gridPreview.Location = New-Object Drawing.Point(10,10)
        $gridPreview.Size = New-Object Drawing.Size(860,500)
        $gridPreview.Anchor = 'Top,Left,Right,Bottom'
        $gridPreview.ReadOnly = $true
        $gridPreview.AutoGenerateColumns = $true
        $gridPreview.DataSource = $redacted
        $btnExport = New-Object Windows.Forms.Button
        $btnExport.Text = 'Export Redacted...'
        $btnExport.Location = New-Object Drawing.Point(10,520)
        $btnExport.Size = New-Object Drawing.Size(150,30)
        $btnExport.Add_Click({
            $save = New-Object Windows.Forms.SaveFileDialog
            $save.Filter = 'Text Files (*.txt)|*.txt|All Files (*.*)|*.*'
            $save.FileName = "RedactedLog_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
            if ($save.ShowDialog() -eq [Windows.Forms.DialogResult]::OK) {
                $redacted | ForEach-Object { $_.Message } | Set-Content $save.FileName
                [Windows.Forms.MessageBox]::Show("Redacted log exported to $($save.FileName)", 'Export Complete', 'OK', 'Information')
            }
        })
        $dlg.Controls.AddRange(@($gridPreview, $btnExport))
        [void]$dlg.ShowDialog($form)
    })
    $btnExportExcel.Add_Click({
        if (-not $script:logData -or $script:logData.Count -eq 0) {
            Show-ExportStatus 'No log data to export.'
            return
        }
        $save = New-Object Windows.Forms.SaveFileDialog
        $save.Filter = 'Excel Workbook (*.xlsx)|*.xlsx|All Files (*.*)|*.*'
        $save.FileName = "LogExport_$(Get-Date -Format 'yyyyMMdd_HHmmss').xlsx"
        if ($save.ShowDialog() -eq [Windows.Forms.DialogResult]::OK) {
            try {
                if (Get-Module -ListAvailable -Name ImportExcel) {
                    $script:logData | Export-Excel -Path $save.FileName -WorksheetName 'Logs' -AutoSize -TableName 'LogData' -ErrorAction Stop
                    Show-ExportStatus "Exported to Excel: $($save.FileName)"
                } else {
                    Show-ExportStatus 'ImportExcel module not found. Falling back to CSV.'
                    $csvPath = [System.IO.Path]::ChangeExtension($save.FileName, 'csv')
                    $script:logData | Export-Csv $csvPath -NoTypeInformation -ErrorAction Stop
                    Show-ExportStatus "Exported to CSV: $csvPath"
                }
            } catch {
                Show-ExportStatus "Export failed: $($_.Exception.Message)"
            }
        }
    })
    # --- Column Sorting ---
    $sortOrder = @{}
    $grid.add_ColumnHeaderMouseClick({
        param($src, $e)
        $col = $grid.Columns[$e.ColumnIndex]
        $colName = $col.Name
        $order = if ($sortOrder[$colName] -eq 'Asc') { 'Desc' } else { 'Asc' }
        $sortOrder[$colName] = $order
        $script:logData = if ($order -eq 'Asc') {
            $script:logData | Sort-Object $colName
        } else {
            $script:logData | Sort-Object $colName -Descending
        }
        $grid.RowCount = $script:logData.Count
        $grid.Refresh()
    })

    # --- Filtering Logic ---
    function Apply-LogFilter {
        $filtered = $script:rawLogEntries
        if ($txtSearch.Text) {
            $filtered = $filtered | Where-Object { $_.Message -like "*${($txtSearch.Text)}*" }
        }
        if ($cmbLevelFilter.SelectedItem -and $cmbLevelFilter.SelectedItem -ne 'All') {
            $filtered = $filtered | Where-Object { $_.LevelDisplayName -eq $cmbLevelFilter.SelectedItem }
        }
        if ($txtProviderFilter.Text) {
            $filtered = $filtered | Where-Object { $_.ProviderName -like "*${($txtProviderFilter.Text)}*" }
        }
        $script:logData = $filtered | ForEach-Object {
            [pscustomobject]@{
                Timestamp = if ($_.TimeCreated) { $_.TimeCreated.ToString("yyyy-MM-dd HH:mm:ss") } else { "Unknown" }
                Level     = if ($_.LevelDisplayName) { $_.LevelDisplayName } else { "Unknown" }
                Provider  = if ($_.ProviderName) { $_.ProviderName } else { "Unknown" }
                EventId   = if ($_.EventId) { $_.EventId } else { "N/A" }
                Message   = $_.Message
            }
        }
        $grid.RowCount = $script:logData.Count
        $grid.Refresh()
    }
    $txtSearch.Add_TextChanged({ Apply-LogFilter })
    $cmbLevelFilter.Add_SelectedIndexChanged({ Apply-LogFilter })
    $txtProviderFilter.Add_TextChanged({ Apply-LogFilter })

    # =============================================================================
    # TAB 2: LOG FILE ANALYSIS (using Get-LogEntries)
    # =============================================================================

    # --- File Analysis Tab Controls ---
    $lblFilePath = New-Label "Log File Path:" 10 20 100
    $txtFilePath = New-Object Windows.Forms.TextBox
    $txtFilePath.Location = New-Object Drawing.Point(120, 20)
    $txtFilePath.Size = New-Object Drawing.Size(400, 20)

    $btnBrowseFile = New-Button "Browse..." 530 18 80 25
    $btnAnalyzeFile = New-Button "Analyze File" 620 18 100 25

    # Advanced filtering options for Get-LogEntries
    $lblIncludeKeywords = New-Label "Include Keywords (comma-separated):" 10 55 200
    $txtIncludeKeywords = New-Object Windows.Forms.TextBox
    $txtIncludeKeywords.Location = New-Object Drawing.Point(220, 55)
    $txtIncludeKeywords.Size = New-Object Drawing.Size(300, 20)

    $lblExcludeKeywords = New-Label "Exclude Keywords (comma-separated):" 10 85 200
    $txtExcludeKeywords = New-Object Windows.Forms.TextBox
    $txtExcludeKeywords.Location = New-Object Drawing.Point(220, 85)
    $txtExcludeKeywords.Size = New-Object Drawing.Size(300, 20)

    $lblEventIds = New-Label "Event IDs (comma-separated):" 530 55 150
    $txtEventIds = New-Object Windows.Forms.TextBox
    $txtEventIds.Location = New-Object Drawing.Point(690, 55)
    $txtEventIds.Size = New-Object Drawing.Size(200, 20)

    $lblProviderNames = New-Label "Provider Names (comma-separated):" 530 85 150
    $txtProviderNames = New-Object Windows.Forms.TextBox
    $txtProviderNames.Location = New-Object Drawing.Point(690, 85)
    $txtProviderNames.Size = New-Object Drawing.Size(200, 20)

    # File analysis options
    $chkFileRedact = New-Object Windows.Forms.CheckBox
    $chkFileRedact.Text = "Redact Sensitive Data"
    $chkFileRedact.Location = New-Object Drawing.Point(10, 115)
    $chkFileRedact.Size = New-Object Drawing.Size(150, 20)

    $chkFileColorize = New-Object Windows.Forms.CheckBox
    $chkFileColorize.Text = "Colorize Output"
    $chkFileColorize.Location = New-Object Drawing.Point(170, 115)
    $chkFileColorize.Size = New-Object Drawing.Size(120, 20)

    $lblSortOrder = New-Label "Sort Order:" 300 115 80
    $cmbSortOrder = New-Object Windows.Forms.ComboBox
    $cmbSortOrder.Location = New-Object Drawing.Point(390, 115)
    $cmbSortOrder.Size = New-Object Drawing.Size(100, 20)
    $cmbSortOrder.DropDownStyle = 'DropDownList'
    $cmbSortOrder.Items.AddRange(@("Forward", "Reverse"))
    $cmbSortOrder.SelectedIndex = 0

    $lblLineLimit = New-Label "Line Limit:" 500 115 70
    $numLineLimit = New-Object Windows.Forms.NumericUpDown
    $numLineLimit.Location = New-Object Drawing.Point(580, 115)
    $numLineLimit.Size = New-Object Drawing.Size(80, 20)
    $numLineLimit.Minimum = 0
    $numLineLimit.Maximum = 100000
    $numLineLimit.Value = 1000

    # File analysis grid and summary
    $gridFile = New-Object Windows.Forms.DataGridView
    $gridFile.Location = New-Object Drawing.Point(10, 150)
    $gridFile.Size = New-Object Drawing.Size(1140, 500)
    $gridFile.Anchor = 'Top,Left,Right,Bottom'
    $gridFile.ReadOnly = $true
    $gridFile.AutoGenerateColumns = $true
    $gridFile.AutoSizeColumnsMode = 'Fill'
    $gridFile.AllowUserToAddRows = $false
    $gridFile.AllowUserToDeleteRows = $false
    $gridFile.SelectionMode = 'FullRowSelect'
    $gridFile.MultiSelect = $false

    $lblFileSummary = New-Label "File analysis summary will appear here..." 10 660 1140 50
    $lblFileSummary.AutoSize = $false
    $lblFileSummary.Anchor = 'Left,Right,Bottom'

    # Add all File Analysis controls to the tab
    $tabFileAnalysis.Controls.AddRange(@(
        $lblFilePath, $txtFilePath, $btnBrowseFile, $btnAnalyzeFile,
        $lblIncludeKeywords, $txtIncludeKeywords, $lblExcludeKeywords, $txtExcludeKeywords,
        $lblEventIds, $txtEventIds, $lblProviderNames, $txtProviderNames,
        $chkFileRedact, $chkFileColorize, $lblSortOrder, $cmbSortOrder, $lblLineLimit, $numLineLimit,
        $gridFile, $lblFileSummary
    ))

    # --- Event Handlers ---

    # Time range preset button handlers
    $btn1Hour.Add_Click({ Set-TimeRange 1 ([ref]$dtStart) ([ref]$dtEnd) })
    $btn24Hours.Add_Click({ Set-TimeRange 24 ([ref]$dtStart) ([ref]$dtEnd) })
    $btn7Days.Add_Click({ Set-TimeRange 168 ([ref]$dtStart) ([ref]$dtEnd) })
    $btn30Days.Add_Click({ Set-TimeRange 720 ([ref]$dtStart) ([ref]$dtEnd) })
    $btn6Months.Add_Click({ Set-TimeRange 4320 ([ref]$dtStart) ([ref]$dtEnd) })
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
        param($src, $e)
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
        if ($script:fetching) {
            [Windows.Forms.MessageBox]::Show("A log fetch is already in progress.", "Busy", 'OK', 'Information')
            return
        }
    $script:fetching = $true
    $lblSummary.Text = "Fetching logs... (async)"
    $script:logData = @()
    $script:rawLogEntries = @()
    $script:allEvents = @()
    $grid.DataSource = $null
    $grid.Rows.Clear()
    $grid.Columns.Clear()
    $progress = New-Object Windows.Forms.ProgressBar
    $progress.Style = 'Marquee'
    $progress.MarqueeAnimationSpeed = 30
    $progress.Location = New-Object Drawing.Point(10, 630)
    $progress.Size = New-Object Drawing.Size(400, 20)
    $tabEventLogs.Controls.Add($progress)
    if ($chart) { $chart.Series['Errors'].Points.Clear() }

        $startTime = $dtStart.Value
        $endTime = $dtEnd.Value
        $attentionOnly = $chkAttentionOnly.Checked
        $redact = $chkRedact.Checked
        $redactLog = $chkRedactLog.Checked

        $script:fetchJob = Start-Job -ScriptBlock {
            param($startTime, $endTime, $attentionOnly, $redact, $redactLog, $allLogs)
            $ErrorActionPreference = 'Stop'
            $allEvents = @()
            foreach ($log in $allLogs) {
                try {
                    $filter = @{ LogName = $log; StartTime = $startTime; EndTime = $endTime }
                    $events = Get-WinEvent -FilterHashtable $filter -ErrorAction Stop
                    $allEvents += $events
                } catch {}
            }
            $allEvents = $allEvents | Sort-Object TimeCreated
            $allEvents | ForEach-Object {
                [pscustomobject]@{
                    TimeCreated = $_.TimeCreated
                    LevelDisplayName = $_.LevelDisplayName
                    ProviderName = $_.ProviderName
                    EventId = $_.Id
                    Message = $_.Message
                    RawMessage = $_.ToXml()
                }
            }
        } -ArgumentList $startTime, $endTime, $attentionOnly, $redact, $redactLog, $script:allLogs

        $autoRefreshTimer.Interval = 1000
        $autoRefreshTimer.add_Tick({
            if ($script:fetchJob -and ($script:fetchJob.State -eq 'Completed' -or $script:fetchJob.State -eq 'Failed')) {
                $autoRefreshTimer.Stop()
                $tabEventLogs.Controls.Remove($progress)
                try {
                    $result = Receive-Job -Job $script:fetchJob -ErrorAction Stop
                    Remove-Job -Job $script:fetchJob -Force
                    $script:rawLogEntries = $result
                    $script:logData = $result | ForEach-Object {
                        [pscustomobject]@{
                            Timestamp = if ($_.TimeCreated) { $_.TimeCreated.ToString("yyyy-MM-dd HH:mm:ss") } else { "Unknown" }
                            Level     = if ($_.LevelDisplayName) { $_.LevelDisplayName } else { "Unknown" }
                            Provider  = if ($_.ProviderName) { $_.ProviderName } else { "Unknown" }
                            EventId   = if ($_.EventId) { $_.EventId } else { "N/A" }
                            Message   = $_.Message
                        }
                    }
                    $grid.DataSource = $null
                    $grid.RowCount = $script:logData.Count
                    $grid.Refresh()
                    $lblSummary.Text = "Fetched $($script:logData.Count) log entries."
                    # --- Update log level filter dropdown dynamically ---
                    $levels = $script:rawLogEntries | ForEach-Object { $_.LevelDisplayName } | Where-Object { $_ } | Select-Object -Unique
                    $allLevels = @('All') + ($defaultLevels | Where-Object { $_ -ne 'All' })
                    foreach ($lvl in $levels) { if ($lvl -and ($allLevels -notcontains $lvl)) { $allLevels += $lvl } }
                    $cmbLevelFilter.Items.Clear()
                    $cmbLevelFilter.Items.AddRange($allLevels)
                    $cmbLevelFilter.SelectedIndex = 0
                    # --- Update chart with error counts over time ---
                    if ($chart -and $script:rawLogEntries.Count -gt 0) {
                        $bins = @{}
                        foreach ($entry in $script:rawLogEntries) {
                            if ($entry.LevelDisplayName -eq 'Error' -and $entry.TimeCreated) {
                                $bin = $entry.TimeCreated.ToString('yyyy-MM-dd HH:00')
                                if (-not $bins.ContainsKey($bin)) { $bins[$bin] = 0 }
                                $bins[$bin]++
                            }
                        }
                        $chart.Series['Errors'].Points.Clear()
                        foreach ($bin in ($bins.Keys | Sort-Object)) {
                            $chart.Series['Errors'].Points.AddXY($bin, $bins[$bin]) | Out-Null
                        }
                        $chart.ChartAreas[0].RecalculateAxesScale()
                    }
                } catch {
                    $lblSummary.Text = "Error occurred while fetching logs."
                    [Windows.Forms.MessageBox]::Show("Failed to fetch logs:`n`n$($_.Exception.Message)", "Error", 'OK', 'Error')
                }
                $script:fetching = $false
            }
        })
    $autoRefreshTimer.Start()
    })

    $lblExportStatus = New-Label '' 10 800 600 20
    $tabEventLogs.Controls.Add($lblExportStatus)
    function Show-ExportStatus($msg) { $lblExportStatus.Text = $msg }
    $btnExportCSV.Add_Click({
        Show-ExportStatus 'Exporting to CSV...'
        Start-Job -ScriptBlock {
            param($data, $file)
            $data | Export-Csv $file -NoTypeInformation -ErrorAction Stop
        } -ArgumentList ($script:logData, "LogExport_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv") | Out-Null
        Start-Sleep -Milliseconds 500
        Show-ExportStatus 'Export complete.'
    })
    $btnExportJSON.Add_Click({
        Show-ExportStatus 'Exporting to JSON...'
        Start-Job -ScriptBlock {
            param($data, $file)
            $data | ConvertTo-Json -Depth 5 | Set-Content $file -ErrorAction Stop
        } -ArgumentList ($script:logData, "LogExport_$(Get-Date -Format 'yyyyMMdd_HHmmss').json") | Out-Null
        Start-Sleep -Milliseconds 500
        Show-ExportStatus 'Export complete.'
    })
    $btnExportReport.Add_Click({
        if (-not $script:rawLogEntries -or $script:rawLogEntries.Count -eq 0) {
            Show-ExportStatus 'No log data to export as report.'
            return
        }
        Show-ExportStatus 'Exporting report...'
        Start-Job -ScriptBlock {
            param($lines, $file)
            Export-LogReport -LogLines $lines -OutputPath $file -ErrorAction Stop
        } -ArgumentList ($script:rawLogEntries, "LogReport_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt") | Out-Null
        Start-Sleep -Milliseconds 500
        Show-ExportStatus 'Export complete.'
    })

    # Form resize handler for proper control positioning (all tabs)
    $form.Add_Resize({
        try {
            $formWidth = $form.ClientSize.Width
            $formHeight = $form.ClientSize.Height

            # Event Logs tab
            $grid.Size = New-Object Drawing.Size(($formWidth - 20), ($formHeight - 210))
            $lblSummary.Location = New-Object Drawing.Point(10, ($formHeight - 80))
            $lblSummary.Size = New-Object Drawing.Size(($formWidth - 20), 60)
            $lblInfo.Location = New-Object Drawing.Point(([Math]::Max(680, $formWidth - 400)), 65)
            $btnTheme.Location = New-Object Drawing.Point(($formWidth - 150), 10)
            $lblExportStatus.Location = New-Object Drawing.Point(10, ($formHeight - 40))

            $lblSearch.Location = New-Object Drawing.Point(10, 95)
            $txtSearch.Location = New-Object Drawing.Point(65, 95)
            $lblLevelFilter.Location = New-Object Drawing.Point(280, 95)
            $cmbLevelFilter.Location = New-Object Drawing.Point(330, 95)
            $lblProviderFilter.Location = New-Object Drawing.Point(440, 95)
            $txtProviderFilter.Location = New-Object Drawing.Point(505, 95)

            # File Analysis tab
            $gridFile.Size = New-Object Drawing.Size(($formWidth - 20), ($formHeight - 210))
            $lblFileSummary.Location = New-Object Drawing.Point(10, ($formHeight - 80))
            $lblFileSummary.Size = New-Object Drawing.Size(($formWidth - 20), 60)
            $lblFilePath.Location = New-Object Drawing.Point(10, 20)
            $txtFilePath.Location = New-Object Drawing.Point(120, 20)
            $btnBrowseFile.Location = New-Object Drawing.Point(($formWidth - 250), 18)
            $btnAnalyzeFile.Location = New-Object Drawing.Point(($formWidth - 140), 18)
            $lblIncludeKeywords.Location = New-Object Drawing.Point(10, 55)
            $txtIncludeKeywords.Location = New-Object Drawing.Point(220, 55)
            $lblExcludeKeywords.Location = New-Object Drawing.Point(10, 85)
            $txtExcludeKeywords.Location = New-Object Drawing.Point(220, 85)
            $lblEventIds.Location = New-Object Drawing.Point(($formWidth - 670), 55)
            $txtEventIds.Location = New-Object Drawing.Point(($formWidth - 510), 55)
            $lblProviderNames.Location = New-Object Drawing.Point(($formWidth - 670), 85)
            $txtProviderNames.Location = New-Object Drawing.Point(($formWidth - 510), 85)
            $chkFileRedact.Location = New-Object Drawing.Point(10, 115)
            $chkFileColorize.Location = New-Object Drawing.Point(170, 115)
            $lblSortOrder.Location = New-Object Drawing.Point(300, 115)
            $cmbSortOrder.Location = New-Object Drawing.Point(390, 115)
            $lblLineLimit.Location = New-Object Drawing.Point(500, 115)
            $numLineLimit.Location = New-Object Drawing.Point(580, 115)
        } catch {
            # Suppress resize errors
        }
    })

    $form.Controls.AddRange(@($tabControl,$btnHelp,$btnErrorLog,$btnSavePreset,$btnLoadPreset,$btnExportSelection,$chkAutoRefresh,$lblRefreshInterval,$numRefreshInterval,$btnColumnChooser))
    Set-Theme $theme
    $form.Size = New-Object Drawing.Size($script:UserSettings.WindowSize[0],$script:UserSettings.WindowSize[1])
    if ($script:UserSettings.Theme) { Set-Theme $script:UserSettings.Theme }
    if ($script:UserSettings.Filters) {
        if ($script:UserSettings.Filters.Search) { $txtSearch.Text = $script:UserSettings.Filters.Search }
        if ($script:UserSettings.Filters.Level) { $cmbLevelFilter.SelectedItem = $script:UserSettings.Filters.Level }
        if ($script:UserSettings.Filters.Provider) { $txtProviderFilter.Text = $script:UserSettings.Filters.Provider }
    }
    $form.Add_Resize({ Save-UserSettings })
    $form.Add_FormClosing({ Save-UserSettings })

    Write-Host "[DEBUG] Displaying form"
    [void]$form.ShowDialog()
    $form.Dispose()

    Unregister-Event -SourceIdentifier $cellFormatEvent.Name
    Remove-Job -Id $cellFormatEvent.Id -Force

    Write-Host "[DEBUG] Show-LogAnalyzerUI finished"
    # exit gracefully without relying on $LASTEXITCODE
}

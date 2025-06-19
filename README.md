# SmartLogAnalyzer

**SmartLogAnalyzer** is a cross-platform PowerShell module that helps system administrators and developers intelligently parse, filter, and summarize logs from `.log`, `.txt`, `.etl`, and even `journalctl`-style system logs. It supports command-line usage and includes a Windows Forms UI for interactive exploration.

![Banner](GUI/Assets/banner.png)

---

## ✨ Features

- 🔍 Filter logs by keyword, timestamp, event ID, level, and provider
- 📋 Summarize log entries (errors, warnings, info, etc.)
- 💾 Export to CSV or JSON
- 🪟 Windows Forms UI (Windows only)
- 🐧 Linux support (for standard text logs)
- ⚙️ Custom regex-based log parsing via `theme.config` or `config.json`

---

## 🚀 Installation

# SmartLogAnalyzer

[![PowerShell Gallery](https://img.shields.io/powershellgallery/v/SmartLogAnalyzer.svg?style=flat-square)](https://www.powershellgallery.com/packages/SmartLogAnalyzer)
[![Downloads](https://img.shields.io/powershellgallery/dt/SmartLogAnalyzer.svg?style=flat-square)](https://www.powershellgallery.com/packages/SmartLogAnalyzer)

SmartLogAnalyzer helps sysadmins and developers parse and analyze logs intelligently across platforms with optional GUI.

## Install via PowerShell
```powershell
Install-Module -Name SmartLogAnalyzer -Scope CurrentUser

## ⚙️ Script Execution Note

- If you encounter a "script execution disabled" error, it may be due to PowerShell's execution policy. You can optionally enable script execution for    trusted scripts using:
- powershell: 
    Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned

💡 Run this in PowerShell as Administrator. Make sure you trust the source.




📦 Usage

CLI Mode
- powershell: Invoke-SmartAnalyzer -Path "C:\logs\app.log" -IncludeKeywords "error", "fail" -ExportFormat CSV
UI Mode (Windows Only)

powershell: Show-LogAnalyzerUI
Summarize a Log Manually

🧪 Run Tests with Pester:
Make sure Pester is installed:
powershell: Install-Module -Name Pester -Force -Scope CurrentUser

Then run your tests:
powershell: Invoke-Pester -Script "Tests\Invoke-SmartAnalyzer.tests.ps1"
powershell: Invoke-Pester -Script "Tests\SmartLogAnalyzer.Tests.ps1"

📁 Project Structure

SLAnalyzer/
├── Public/
│   ├── Get-LogEntries.ps1
│   ├── Get-LogSummary.ps1
│   ├── Show-LogAnalyzerUI.ps1
│   └── Invoke-SmartAnalyzer.ps1
├── Private/
│   ├── Convert-Timestamp.ps1
│   ├── Format-LogEntry.ps1
│   └── Analyzers.Helpers.ps1
├── GUI/
│   └── Assets/
│       └── banner.png, theme.config, etc.
├── Tests/
│   ├── SmartLogAnalyzer.Tests.ps1
│   └── Sample.Logs/
├── SmartLogAnalyzer.psd1
├── SmartLogAnalyzer.psm1
├── config.json
├── README.md
└── LICENSE


📄 License
MIT License. See LICENSE for details.

🧠 Credits
Created by Willie Bonner — Independent Developer & System Automation Enthusiast.

🌐 Links
📦 PowerShell Gallery: Coming Soon

🐙 GitHub: https://github.com/williebonnerjr/SLAnalyzer

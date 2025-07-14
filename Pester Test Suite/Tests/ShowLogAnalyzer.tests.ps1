# Requires -Module Pester
# File: Show-LogAnalyzerUI.tests.ps1

$modulePath = Join-Path $PSScriptRoot "..\..\SmartLogAnalyzer.psm1"
Import-Module $modulePath -Force

Describe "Show-LogAnalyzerUI" {

    BeforeAll {
        # Store original IsWindows in script scope to be accessible in AfterAll
        $script:originalIsWindows = $IsWindows
    }

    AfterAll {
        # Restore environment state
        Set-Variable -Name IsWindows -Value $script:originalIsWindows -Scope Global
    }

    Context "On non-Windows platforms" {
        BeforeEach {
            Set-Variable -Name IsWindows -Value $false -Scope Global
        }

        It "Throws an error if not running on Windows" {
            { Show-LogAnalyzerUI } | Should -Throw "❌ The Smart Log Analyzer UI is only supported on Windows."
        }
    }

    Context "On Windows with .NET available" {
        BeforeEach {
            Set-Variable -Name IsWindows -Value $true -Scope Global
        }

        Mock Add-Type { return $null }
        Mock Import-Module { return $null }
        Mock ([System.Windows.Forms.Form])::ShowDialog { return "OK" }

        It "Successfully initializes and displays the form" {
            # This is a dry-run that checks setup succeeds without actual UI interaction
            { Show-LogAnalyzerUI } | Should -Not -Throw
        }

        It "Attempts to import the SmartLogAnalyzer module" {
            Mock Import-Module -MockWith { Set-Variable -Name ModuleImported -Value $true -Scope Global }

            Remove-Variable -Name ModuleImported -ErrorAction SilentlyContinue -Scope Global
            Show-LogAnalyzerUI
            $Global:ModuleImported | Should -BeTrue
        }

        It "Attempts to load Windows Forms assemblies" {
            Mock Add-Type -ParameterFilter { $AssemblyName -eq "System.Windows.Forms" } -MockWith {
                Set-Variable -Name FormsLoaded -Value $true -Scope Global
            }

            Remove-Variable -Name FormsLoaded -ErrorAction SilentlyContinue -Scope Global
            Show-LogAnalyzerUI
            $Global:FormsLoaded | Should -BeTrue
        }
    }

    Context "When Windows Forms is unavailable" {
        BeforeEach {
            Set-Variable -Name IsWindows -Value $true -Scope Global
        }

        Mock Add-Type { throw "Cannot load System.Windows.Forms" }

        It "Throws an error when Add-Type fails" {
            { Show-LogAnalyzerUI } | Should -Throw "❌ Failed to load Windows Forms. This feature requires .NET and Windows."
        }
    }

    Context "When SmartLogAnalyzer module import fails" {
        BeforeEach {
            Set-Variable -Name IsWindows -Value $true -Scope Global
        }

        Mock Add-Type { return $null }
        Mock Import-Module { throw "Module not found" }

        It "Throws an error if module import fails" {
            { Show-LogAnalyzerUI } | Should -Throw "❌ Failed to import SmartLogAnalyzer module."
        }
    }
}

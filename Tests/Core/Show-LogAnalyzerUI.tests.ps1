BeforeAll {
    # Import the SmartLogAnalyzer module before running any tests
    $modulePath = Join-Path $PSScriptRoot "..\..\SmartLogAnalyzer.psd1"
    try {
        Import-Module $modulePath -Force -ErrorAction Stop
    }
    catch {
        Write-Error "SmartLogAnalyzer module could not be loaded from '$modulePath'. Please check the module path and try again.`nError: $($_.Exception.Message)"
        exit 1
    }

    if (-not (Get-Module -Name SmartLogAnalyzer)) {
        Write-Error "SmartLogAnalyzer module is not loaded after import attempt."
        exit 1
    }
}

# Only run these UI tests on Windows since Windows Forms is Windows-only
Describe "Show-LogAnalyzerUI Functionality" -Skip:(!$IsWindows) {

    It "Should be available on Windows" {
        Get-Command Show-LogAnalyzerUI -ErrorAction Stop | Should -Not -BeNullOrEmpty
    }

    It "Should launch the UI without errors" {
        { Show-LogAnalyzerUI } | Should -Not -Throw
    }
}
# This test suite is designed to validate the Show-LogAnalyzerUI function,
# which is part of the SmartLogAnalyzer module. It ensures that the UI can be accessed

# If the tests run on non-Windows systems, this entire Describe block will be skipped,
# preventing false failures on unsupported platforms.

# This test suite ensures that:
# - The UI function is properly exported and accessible on Windows
# - The UI can launch without runtime errors, supporting stability and integration testing
#
# These tests are critical for verifying the GUI component of the SmartLogAnalyzer module,
# helping maintain cross-platform compatibility by explicitly skipping on unsupported OSes.
#
# Running these tests as part of CI workflows catches GUI issues early,
# allowing maintainable growth as the UI evolves.

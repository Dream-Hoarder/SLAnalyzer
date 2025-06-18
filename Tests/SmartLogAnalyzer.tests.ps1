Describe 'Smart Log Analyzer - Integration Tests' {
    $samplePath = Join-Path $PSScriptRoot 'SampleLogs/sample.log'

    Context 'Basic Entry and Summary Validation' {
        It 'Parses entries and returns summary correctly' {
            $result = Invoke-SmartAnalyzer -Path $samplePath

            $result | Should -Not -BeNullOrEmpty
            $result.Entries.Count | Should -BeGreaterThan 0

            $summary = $result.Summary
            $summary | Should -HaveProperty 'TotalLines'
            $summary.TotalLines | Should -Be $result.Entries.Count
            $summary | Should -HaveProperty 'ErrorCount'
            $summary | Should -HaveProperty 'InfoCount'
            $summary | Should -HaveProperty 'WarningCount'
        }
    }

    Context 'Filtering by Include/Exclude Keywords' {
        It 'Includes only lines with "fatal"' {
            $result = Invoke-SmartAnalyzer -Path $samplePath -IncludeKeywords 'fatal'
            $result.Entries.Count | Should -BeGreaterThan 0
            ($result.Entries -join "\n") | Should -Match 'fatal'
        }

        It 'Excludes lines with "debug"' {
            $result = Invoke-SmartAnalyzer -Path $samplePath -ExcludeKeywords 'debug'
            ($result.Entries -join "\n") | Should -Not -Match 'debug'
        }
    }

    Context 'Time Range Filtering' {
        $start = Get-Date '2023-01-01'
        $end   = Get-Date '2023-12-31'

        It 'Filters lines by date range' {
            $result = Invoke-SmartAnalyzer -Path $samplePath -StartTime $start -EndTime $end
            foreach ($line in $result.Entries) {
                $parsed = Convert-ToTimestamp -Line $line
                if ($parsed) {
                    $parsed | Should -BeGreaterThanOrEqualTo $start
                    $parsed | Should -BeLessThanOrEqualTo $end
                }
            }
        }
    }

    Context 'Exporting Functionality' {
        It 'Exports to CSV and JSON correctly' {
            $csvPath = Join-Path $PSScriptRoot 'tmp/export.csv'
            $jsonPath = Join-Path $PSScriptRoot 'tmp/export.json'

            Invoke-SmartAnalyzer -Path $samplePath -ExportPath $csvPath -ExportFormat CSV | Out-Null
            Invoke-SmartAnalyzer -Path $samplePath -ExportPath $jsonPath -ExportFormat JSON | Out-Null

            Test-Path $csvPath | Should -BeTrue
            Test-Path $jsonPath | Should -BeTrue

            Remove-Item $csvPath, $jsonPath -Force
        }
    }

    Context 'Invalid Input Handling' {
        It 'Throws for missing file' {
            { Invoke-SmartAnalyzer -Path 'C:\not\real\path.log' } | Should -Throw
        }
    }
}

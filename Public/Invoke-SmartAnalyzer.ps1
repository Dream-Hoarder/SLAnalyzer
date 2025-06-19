function Invoke-SmartAnalyzer {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory)]
        [string]$Path,

        [string[]]$IncludeKeywords = @(),
        [string[]]$ExcludeKeywords = @(),
        [datetime]$StartTime,
        [datetime]$EndTime,

        [ValidateSet("Forward", "Reverse")]
        [string]$SortOrder = "Forward",

        [int[]]$EventId,
        [string[]]$Level,
        [string[]]$ProviderName,

        [string]$ExportPath,
        [ValidateSet("CSV", "JSON")]
        [string]$ExportFormat = "CSV",

        [string]$ReportPath,
        [ValidateSet("Text", "Json", "Csv", "Html")]
        [string]$ReportFormat = "Text",

        [switch]$RedactSensitiveData,
        [switch]$GenerateRedactionLog,
        [switch]$IncludeMetadata
    )

    try {
        # Dynamically build parameters for Get-LogEntries
        $params = @{ Path = $Path }

        if ($IncludeKeywords)    { $params.IncludeKeywords = $IncludeKeywords }
        if ($ExcludeKeywords)    { $params.ExcludeKeywords = $ExcludeKeywords }
        if ($StartTime)          { $params.StartTime = $StartTime }
        if ($EndTime)            { $params.EndTime = $EndTime }
        if ($SortOrder)          { $params.SortOrder = $SortOrder }
        if ($EventId)            { $params.EventId = $EventId }
        if ($Level)              { $params.Level = $Level }
        if ($ProviderName)       { $params.ProviderName = $ProviderName }
        if ($ExportPath)         { $params.ExportPath = $ExportPath }
        if ($ExportFormat)       { $params.ExportFormat = $ExportFormat }

        # Process logs
        $logEntries = Get-LogEntries @params
        $summary = Get-LogSummary -LogLines $logEntries

        # Conditionally export report
        if ($ReportPath -and $PSCmdlet.ShouldProcess($ReportPath, "Export SmartLogAnalyzer Report")) {
            Export-LogReport -Summary $summary `
                             -Entries $logEntries `
                             -SourcePath $Path `
                             -OutputPath $ReportPath `
                             -Format $ReportFormat `
                             -Redact:$RedactSensitiveData `
                             -IncludeMetadata:$IncludeMetadata `
                             -GenerateRedactionLog:$GenerateRedactionLog
            Write-Information "📄 Report exported to: $ReportPath"
        }

        return [pscustomobject]@{
            Entries = $logEntries
            Summary = $summary
        }
    } catch {
        Write-Error $_.Exception.Message
        throw "❌ Smart Analyzer failed. See error details above."
    }
}




# SIG # Begin signature block
# MIIFsAYJKoZIhvcNAQcCoIIFoTCCBZ0CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCBil8rs1vLlt28e
# b0t7eubhPhqGPrZAKOn8cmaTifpOW6CCAxwwggMYMIICAKADAgECAhAVMtqhUrdy
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
# ICf5e4JvwwCNpPIn+wwU0matuwLeWiSQ0ZsnorzDgN9sMA0GCSqGSIb3DQEBAQUA
# BIIBAL3IWh7FsOS11+zQ62LWCinJqHz771uCEiYPJTaKFGLOnKAzT/SwcyKZXJZ/
# BnXkKgdmleUwNn7VuBi9w4mHF1GP78u9aSyKe0qfsjzyrufQ1HICcNZWqQmzAukw
# 0QYIZIMG7Q+l93iEy8270PfZ9rjjnvOTifnXXilpedVydxZ1+J2EFKRcWFoQb134
# 9yd3gONStW+TTp0yIn5g6IBNtp1V84tN7ZNryAsL1+YqFb3YFndJysl/VxHkU2T3
# uNndnpn8AUMNIM4wT63Yg456C50cEVQ65iwy2l3aut6OtLg7gqv35c3ewDG8I3dk
# FgjQheJ+l1CJIyKOTEAzu61w+3Q=
# SIG # End signature block

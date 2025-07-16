# Convert-Timestamp.ps1 (Fixed and Improved)

# Regex patterns (unchanged)
$timestampPatterns = @(
    '\d{4}-\d{2}-\d{2}[ T]\d{2}:\d{2}:\d{2}(?:\.\d{1,7})?(?:Z|[+-]\d{2}:\d{2})?',
    '[A-Za-z]{3}\s+\d{1,2}\s+\d{2}:\d{2}:\d{2}',
    '\d{2}/\d{2}/\d{4}\s+\d{2}:\d{2}:\d{2}(?:\s*[AP]M)?',
    '\d{4}/\d{2}/\d{2}\s+\d{2}:\d{2}:\d{2}(?:\s*[AP]M)?',
    '\d{2}/\d{2}/\d{4}',
    '\d{4}/\d{2}/\d{2}'
)

$Script:LogLineRegex = [regex]::new(
    '(?<Timestamp>' + ($timestampPatterns -join '|') + ')',
    [System.Text.RegularExpressions.RegexOptions]::Compiled
)

# Try exact formats
function Invoke-TryParseExactFormats {
    param (
        [string]$TimestampText,
        [System.Globalization.CultureInfo]$Culture
    )

    $formats = @(
        @{ Format = "o"; Style = [System.Globalization.DateTimeStyles]::RoundtripKind },
        @{ Format = "yyyy-MM-ddTHH:mm:ss.ffffffZ"; Style = [System.Globalization.DateTimeStyles]::RoundtripKind },
        @{ Format = "yyyy-MM-ddTHH:mm:ss.ffffff"; Style = [System.Globalization.DateTimeStyles]::AssumeUniversal },
        @{ Format = "yyyy-MM-ddTHH:mm:ss.fffZ"; Style = [System.Globalization.DateTimeStyles]::RoundtripKind },
        @{ Format = "yyyy-MM-ddTHH:mm:ss.fff"; Style = [System.Globalization.DateTimeStyles]::AssumeUniversal },
        @{ Format = "yyyy-MM-ddTHH:mm:ssZ"; Style = [System.Globalization.DateTimeStyles]::AssumeUniversal },
        @{ Format = "yyyy-MM-ddTHH:mm:ss"; Style = [System.Globalization.DateTimeStyles]::AssumeUniversal },
        @{ Format = "yyyy-MM-dd HH:mm:ss.fff"; Style = [System.Globalization.DateTimeStyles]::None },
        @{ Format = "yyyy-MM-dd HH:mm:ss"; Style = [System.Globalization.DateTimeStyles]::None },
        @{ Format = "MM/dd/yyyy HH:mm:ss.fff"; Style = [System.Globalization.DateTimeStyles]::None },
        @{ Format = "MM/dd/yyyy HH:mm:ss"; Style = [System.Globalization.DateTimeStyles]::None },
        @{ Format = "dd/MM/yyyy HH:mm:ss.fff"; Style = [System.Globalization.DateTimeStyles]::None },
        @{ Format = "dd/MM/yyyy HH:mm:ss"; Style = [System.Globalization.DateTimeStyles]::None },
        @{ Format = "MM/dd/yyyy hh:mm:ss tt"; Style = [System.Globalization.DateTimeStyles]::None },
        @{ Format = "dd/MM/yyyy hh:mm:ss tt"; Style = [System.Globalization.DateTimeStyles]::None },
        @{ Format = "MM/dd/yyyy"; Style = [System.Globalization.DateTimeStyles]::None },
        @{ Format = "dd/MM/yyyy"; Style = [System.Globalization.DateTimeStyles]::None },
        @{ Format = "yyyy/MM/dd"; Style = [System.Globalization.DateTimeStyles]::None }
    )

    foreach ($entry in $formats) {
        $parsed = $null
        if ([datetime]::TryParseExact($TimestampText, $entry.Format, $Culture, $entry.Style, [ref]$parsed) -and $parsed) {
            return $parsed.ToUniversalTime()
        }
    }

    return $null
}

# Syslog parser
function Invoke-TryParseSyslog {
    param (
        [string]$TimestampText,
        [System.Globalization.CultureInfo]$Culture,
        [int]$CurrentYear = (Get-Date).Year
    )

    $syslogFormats = @("MMM d HH:mm:ss", "MMM dd HH:mm:ss")

    foreach ($fmt in $syslogFormats) {
        $syslogResult = $null
        if ([datetime]::TryParseExact($TimestampText, $fmt, $Culture, [System.Globalization.DateTimeStyles]::AllowWhiteSpaces, [ref]$syslogResult) -and $syslogResult) {
            try {
                return (Get-Date -Year $CurrentYear -Month $syslogResult.Month -Day $syslogResult.Day `
                             -Hour $syslogResult.Hour -Minute $syslogResult.Minute -Second $syslogResult.Second).ToUniversalTime()
            } catch {
                Write-Verbose "Syslog reconstruction failed: $_"
            }
        }
    }

    return $null
}

# Main timestamp converter
function Convert-Timestamp {
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline = $true)]
        [string]$TimestampString,

        [Parameter()]
        [System.Globalization.CultureInfo]$Culture = [System.Globalization.CultureInfo]::GetCultureInfo('en-US'),

        [Parameter()]
        [int]$TestYear
    )

    process {
        if ([string]::IsNullOrWhiteSpace($TimestampString)) {
            return $null
        }

        try {
            $result = Invoke-TryParseExactFormats -TimestampText $TimestampString -Culture $Culture
            if ($result) { return $result }

            if ($PSBoundParameters.ContainsKey('TestYear')) {
                $result = Invoke-TryParseSyslog -TimestampText $TimestampString -Culture $Culture -CurrentYear $TestYear
            } else {
                $result = Invoke-TryParseSyslog -TimestampText $TimestampString -Culture $Culture
            }

            if ($result) { return $result }

            $fallback = $null
            if ([datetime]::TryParse($TimestampString, $Culture, [System.Globalization.DateTimeStyles]::AllowWhiteSpaces, [ref]$fallback) -and $fallback) {
                return $fallback.ToUniversalTime()
            }

            return $null
        } catch {
            Write-Verbose "❌ Exception while parsing timestamp: '$TimestampString' - $_"
            return $null
        }
    }
}

# Enhanced log line parser
function ConvertFrom-LogEntry {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [string]$LogLine
    )

    process {
        try {
            $match = $Script:LogLineRegex.Match($LogLine)
            if (-not $match.Success) {
                Write-Verbose "No timestamp match found in line: $LogLine"
                return [PSCustomObject]@{
                    Timestamp = $null
                    Level     = "UNPARSEABLE"
                    Message   = $LogLine
                    RawLine   = $LogLine
                }
            }

            $timestampString = $match.Groups["Timestamp"].Value.Trim()
            $parsedTimestamp = Convert-Timestamp -TimestampString $timestampString

            if (-not $parsedTimestamp) {
                Write-Verbose "Failed to parse matched timestamp: '$timestampString'"
            }
        } catch {
            Write-Verbose "Exception while parsing log line: '$LogLine' - $_"
            return [PSCustomObject]@{
                Timestamp = $null
                Level     = "UNPARSEABLE"
                Message   = $LogLine
                RawLine   = $LogLine
            }   
            $levelMatch
        }
    }
}
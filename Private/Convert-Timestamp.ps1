# Requires -Version 5.1

# --- Precompile regex for log parsing performance ---
$timestampPatterns = @(
    '\d{4}-\d{2}-\d{2}[ T]\d{2}:\d{2}:\d{2}(?:\.\d{1,7})?(?:Z|[+-]\d{2}:?\d{2})?', # ISO with optional offset
    '[A-Za-z]{3}\s+\d{1,2}\s+\d{2}:\d{2}:\d{2}',                                  # Syslog
    '\d{2}/\d{2}/\d{4}\s+\d{2}:\d{2}:\d{2}(?:\s*[AP]M)?',                         # MM/DD/YYYY HH:MM:SS [AM/PM]
    '\d{4}/\d{2}/\d{2}\s+\d{2}:\d{2}:\d{2}(?:\s*[AP]M)?',                         # YYYY/MM/DD HH:MM:SS [AM/PM]
    '\d{2}/\d{2}/\d{4}',                                                         # MM/DD/YYYY (date only)
    '\d{4}/\d{2}/\d{2}'                                                          # YYYY/MM/DD (date only)
)

# Standard pattern: timestamp at beginning
$Script:LogLineRegex = [regex]::new(
    '^(?<Timestamp>(' + ($timestampPatterns -join '|') + '))' +
    '(?:\s*\[(?<Level>[A-Z]+)\])?\s*(?<Message>.*)$',
    [System.Text.RegularExpressions.RegexOptions]::Compiled
)

# Fallback pattern: timestamp anywhere in line
$Script:LogFallbackRegex = [regex]::new(
    '(?<Timestamp>(' + ($timestampPatterns -join '|') + ')).*?(?:\[(?<Level>[A-Z]+)\])?\s*(?<Message>.*)',
    [System.Text.RegularExpressions.RegexOptions]::Compiled
)

# --- Helper: Try known formats ---
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
        @{ Format = "yyyy-MM-ddTHH:mm:ssZ"; Style = [System.Globalization.DateTimeStyles]::RoundtripKind },
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
        [datetime]$parsed = $null
        if ([datetime]::TryParseExact($TimestampText, $entry.Format, $Culture, $entry.Style, [ref]$parsed)) {
            try {
                return $parsed.ToUniversalTime()
            } catch {
                Write-Verbose "⚠️ Unable to convert to UTC: $($parsed)"
            }
        }
    }

    return $null
}

# --- Helper: Syslog style format ---
function Invoke-TryParseSyslog {
    param (
        [string]$TimestampText,
        [System.Globalization.CultureInfo]$Culture,
        [int]$CurrentYear = $(Get-Date).Year
    )

    $syslogFormats = @("MMM d HH:mm:ss", "MMM dd HH:mm:ss")

    foreach ($fmt in $syslogFormats) {
        [datetime]$result = $null
        if ([datetime]::TryParseExact($TimestampText, $fmt, $Culture, [System.Globalization.DateTimeStyles]::AllowWhiteSpaces, [ref]$result)) {
            try {
                $fullDate = Get-Date -Year $CurrentYear -Month $result.Month -Day $result.Day `
                    -Hour $result.Hour -Minute $result.Minute -Second $result.Second
                return $fullDate.ToUniversalTime()
            } catch {
                Write-Verbose "⚠️ Failed to build full syslog DateTime: $($_.Exception.Message)"
            }
        }
    }

    return $null
}

# --- Public: Convert a string timestamp ---
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

        $result = Invoke-TryParseExactFormats -TimestampText $TimestampString -Culture $Culture
        if ($result) { return $result }

        if ($PSBoundParameters.ContainsKey('TestYear')) {
            $result = Invoke-TryParseSyslog -TimestampText $TimestampString -Culture $Culture -CurrentYear $TestYear
        } else {
            $result = Invoke-TryParseSyslog -TimestampText $TimestampString -Culture $Culture
        }
        if ($result) { return $result }

        # Final fallback
        [datetime]$fallback = $null
        if ([datetime]::TryParse($TimestampString, $Culture, [System.Globalization.DateTimeStyles]::AllowWhiteSpaces, [ref]$fallback)) {
            try {
                return $fallback.ToUniversalTime()
            } catch {
                Write-Verbose "⚠️ Failed fallback UTC conversion for '$TimestampString'"
            }
        }

        Write-Verbose "❌ Failed to parse timestamp: '$TimestampString'"
        return $null
    }
}

# --- Public: Convert log line to structured object ---
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
                # Try fallback: timestamp anywhere
                $match = $Script:LogFallbackRegex.Match($LogLine)
                if (-not $match.Success) {
                    Write-Verbose "❌ Log line could not be matched: '$LogLine'"
                    return [PSCustomObject]@{
                        Timestamp = $null
                        Level     = "UNPARSEABLE"
                        Message   = $LogLine
                        RawLine   = $LogLine
                    }
                }
            }

            $timestampString = $match.Groups["Timestamp"].Value.Trim()
            $level = $match.Groups["Level"].Value
            $message = $match.Groups["Message"].Value.Trim()

            $parsedTimestamp = Convert-Timestamp -TimestampString $timestampString

            return [PSCustomObject]@{
                Timestamp = $parsedTimestamp
                Level     = if ([string]::IsNullOrWhiteSpace($level)) { "UNKNOWN" } else { $level }
                Message   = $message
                RawLine   = $LogLine
            }
        }
        catch {
            Write-Warning "❌ Exception while parsing: '$LogLine' - $_"
            return $null
        }
    }
}

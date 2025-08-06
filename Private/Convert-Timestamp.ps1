# Requires -Version 5.1

# --- Precompile regex for log parsing performance ---
$timestampPatterns = @(
    '\d{4}-\d{2}-\d{2}[ T]\d{2}:\d{2}:\d{2}(?:\.\d{1,7})?(?:Z|[+-]\d{2}:?\d{2})?', # ISO with optional fractional seconds and offset/Z
    '[A-Za-z]{3}\s+\d{1,2}\s+\d{2}:\d{2}:\d{2}',                                  # Syslog (e.g., Jul 14 13:45:30 or Jul  3 04:01:02)
    '\d{2}/\d{2}/\d{4}\s+\d{2}:\d{2}:\d{2}(?:\.\d{1,7})?(?:\s*[AP]M)?',           # MM/DD/YYYY HH:MM:SS with optional fractional seconds and AM/PM
    '\d{4}/\d{2}/\d{2}\s+\d{2}:\d{2}:\d{2}(?:\.\d{1,7})?(?:\s*[AP]M)?',           # YYYY/MM/DD HH:MM:SS with optional fractional seconds and AM/PM
    '\d{2}/\d{2}/\d{4}',                                                          # MM/DD/YYYY (date only)
    '\d{4}/\d{2}/\d{2}'                                                           # YYYY/MM/DD (date only)
)

# Standard pattern: timestamp at beginning
$Script:LogLineRegex = [regex]::new(
    '^(?<Timestamp>(' + ($timestampPatterns -join '|') + '))' +
    '\s*(?:\[(?<Level>[A-Z]+)\])?\s*(?<Message>.*)$', # Added \s* before and after level for more flexibility
    [System.Text.RegularExpressions.RegexOptions]::Compiled
)

# Fallback pattern: timestamp anywhere in line
$Script:LogFallbackRegex = [regex]::new(
    '(?<Timestamp>(' + ($timestampPatterns -join '|') + ')).*?(?:\[(?<Level>[A-Z]+)\])?\s*(?<Message>.*)', # Also added \s* around level
    [System.Text.RegularExpressions.RegexOptions]::Compiled
)

# --- Helper: Try known formats ---
function Invoke-TryParseExactFormats {
    param (
        [string]$TimestampText,
        [System.Globalization.CultureInfo]$Culture
    )

    # Trim the timestamp text once at the beginning of the helper function for cleanliness
    $TimestampText = $TimestampText.Trim()

    $formats = @(
        # ISO 8601 & Roundtrip formats
        @{ Format = "o"; Style = [System.Globalization.DateTimeStyles]::RoundtripKind },
        @{ Format = "yyyy-MM-ddTHH:mm:ss.ffffffZ"; Style = [System.Globalization.DateTimeStyles]::RoundtripKind },
        @{ Format = "yyyy-MM-ddTHH:mm:ss.fffZ"; Style = [System.Globalization.DateTimeStyles]::RoundtripKind },
        @{ Format = "yyyy-MM-ddTHH:mm:ssZ"; Style = [System.Globalization.DateTimeStyles]::RoundtripKind }, # For Z suffix without fractional seconds

        # ISO 8601 without Z or offset, assuming Universal (or local then converting to Universal)
        @{ Format = "yyyy-MM-ddTHH:mm:ss.ffffff"; Style = [System.Globalization.DateTimeStyles]::AssumeUniversal },
        @{ Format = "yyyy-MM-ddTHH:mm:ss.fff"; Style = [System.Globalization.DateTimeStyles]::AssumeUniversal },
        @{ Format = "yyyy-MM-ddTHH:mm:ss"; Style = [System.Globalization.DateTimeStyles]::AssumeUniversal },

        # Common Date & Time formats (e.g., from logs)
        @{ Format = "yyyy-MM-dd HH:mm:ss.ffffff"; Style = [System.Globalization.DateTimeStyles]::None },
        @{ Format = "yyyy-MM-dd HH:mm:ss.fff"; Style = [System.Globalization.DateTimeStyles]::None },
        @{ Format = "yyyy-MM-dd HH:mm:ss"; Style = [System.Globalization.DateTimeStyles]::None },

        @{ Format = "MM/dd/yyyy HH:mm:ss.ffffff"; Style = [System.Globalization.DateTimeStyles]::None },
        @{ Format = "MM/dd/yyyy HH:mm:ss.fff"; Style = [System.Globalization.DateTimeStyles]::None },
        @{ Format = "MM/dd/yyyy HH:mm:ss"; Style = [System.Globalization.DateTimeStyles]::None },

        @{ Format = "dd/MM/yyyy HH:mm:ss.ffffff"; Style = [System.Globalization.DateTimeStyles]::None },
        @{ Format = "dd/MM/yyyy HH:mm:ss.fff"; Style = [System.Globalization.DateTimeStyles]::None },
        @{ Format = "dd/MM/yyyy HH:mm:ss"; Style = [System.Globalization.DateTimeStyles]::None },

        @{ Format = "MM/dd/yyyy hh:mm:ss tt"; Style = [System.Globalization.DateTimeStyles]::None }, # With AM/PM
        @{ Format = "dd/MM/yyyy hh:mm:ss tt"; Style = [System.Globalization.DateTimeStyles]::None }, # With AM/PM

        # Date-only formats
        @{ Format = "MM/dd/yyyy"; Style = [System.Globalization.DateTimeStyles]::None },
        @{ Format = "dd/MM/yyyy"; Style = [System.Globalization.DateTimeStyles]::None },
        @{ Format = "yyyy/MM/dd"; Style = [System.Globalization.DateTimeStyles]::None }
    )

    foreach ($entry in $formats) {
        $parsed = [datetime]::new()
        if ([datetime]::TryParseExact($TimestampText, $entry.Format, $Culture, $entry.Style, [ref]$parsed)) {
            try {
                # Determine DateTimeKind based on format/style
                # RoundtripKind implies the Kind is already set by parsing (Local, Utc, Unspecified)
                # For 'Z' or offset-containing formats, the Kind should be Utc or Local/Offset.
                # For others, if it's not explicitly UTC, assume it's local and convert to UTC.
                if ($entry.Style -band [System.Globalization.DateTimeStyles]::RoundtripKind -or
                    $parsed.Kind -eq [System.DateTimeKind]::Utc -or
                    $parsed.Kind -eq [System.DateTimeKind]::Local)
                {
                    # If it's already Utc or Local, or RoundtripKind handled it, just return it.
                    # The Pester test for 'Z' expecting 'Local' is unusual; standard behavior would be 'Utc'.
                    # We return 'parsed' directly, letting its Kind be whatever TryParseExact determined.
                    return $parsed
                } else {
                    # For formats with Style::None or AssumeUniversal (which are usually parsed as Unspecified),
                    # convert to Universal Time.
                    return $parsed.ToUniversalTime()
                }
            } catch {
                Write-Verbose "⚠️ Invoke-TryParseExactFormats: Unable to process or convert to UTC for '$TimestampText' with format '$($entry.Format)': $($_.Exception.Message)"
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
        [int]$CurrentYear = $(Get-Date).Year # Default to current system year
    )

    # Trim the timestamp text for syslog parsing to handle variable spacing
    $TimestampText = $TimestampText.Trim()

    # The 'd' format specifier handles both single and double digit days automatically
    # when combined with AllowWhiteSpaces, eliminating the need for a separate 'dd' format.
    $syslogFormats = @("MMM d HH:mm:ss") # This format should handle 'Jul 14 13:45:30' and 'Jul  3 04:01:02'

    foreach ($fmt in $syslogFormats) {
        $result = [datetime]::new()
        # Use AllowWhiteSpaces for flexible parsing of single/double digit days with varying spaces
        if ([datetime]::TryParseExact($TimestampText, $fmt, $Culture, [System.Globalization.DateTimeStyles]::AllowWhiteSpaces, [ref]$result)) {
            try {
                # Construct the full date by adding the year.
                $currentDate = Get-Date # Get the current date and time for comparison
                $fullDate = Get-Date -Year $CurrentYear -Month $result.Month -Day $result.Day `
                    -Hour $result.Hour -Minute $result.Minute -Second $result.Second

                # Syslog timestamps often don't include the year. If the parsed date is in the future
                # relative to the current date, it likely means the log was from the previous year
                # (e.g., a December log processed in January of the next year). Adjust the year.
                if ($fullDate -gt $currentDate) {
                    $fullDate = $fullDate.AddYears(-1)
                }

                # Syslog typically implies local time, convert to Universal Time for consistency
                return $fullDate.ToUniversalTime()
            } catch {
                Write-Verbose "⚠️ Invoke-TryParseSyslog: Failed to build full syslog DateTime for '$TimestampText': $($_.Exception.Message)"
            }
        }
    }

    return $null
}

# --- Public: Convert a string timestamp ---
function Convert-Timestamp {
    [CmdletBinding(DefaultParameterSetName = 'Default')] # Added default parameter set name
    param (
        [Parameter(ValueFromPipeline = $true, Mandatory = $true, Position = 0)] # Made mandatory and positional for pipeline
        [string]$TimestampString,

        [Parameter()]
        [System.Globalization.CultureInfo]$Culture = [System.Globalization.CultureInfo]::GetCultureInfo('en-US'),

        [Parameter()]
        [int]$TestYear # For testing syslog year override
    )

    process {
        if ([string]::IsNullOrWhiteSpace($TimestampString)) {
            Write-Verbose "Convert-Timestamp: TimestampString is null or whitespace, returning null."
            return $null
        }

        # Try exact formats first (ISO, common date/time, etc.)
        $result = Invoke-TryParseExactFormats -TimestampText $TimestampString -Culture $Culture
        if ($result) {
            Write-Verbose "Convert-Timestamp: Successfully parsed '$TimestampString' with Invoke-TryParseExactFormats."
            return $result
        }

        # Then try syslog format
        if ($PSBoundParameters.ContainsKey('TestYear')) {
            $result = Invoke-TryParseSyslog -TimestampText $TimestampString -Culture $Culture -CurrentYear $TestYear
        } else {
            $result = Invoke-TryParseSyslog -TimestampText $TimestampString -Culture $Culture
        }
        if ($result) {
            Write-Verbose "Convert-Timestamp: Successfully parsed '$TimestampString' with Invoke-TryParseSyslog."
            return $result
        }

        # Final fallback using generic TryParse for highly flexible formats
        $fallback = [datetime]::new()
        # Trim again, just in case the string somehow picked up extra spaces that weren't handled earlier
        if ([datetime]::TryParse($TimestampString.Trim(), $Culture, [System.Globalization.DateTimeStyles]::AllowWhiteSpaces, [ref]$fallback)) {
            try {
                Write-Verbose "Convert-Timestamp: Successfully parsed '$TimestampString' with generic TryParse."
                # If generic TryParse succeeds, it often defaults to local time if no offset/zone info. Convert to UTC.
                return $fallback.ToUniversalTime()
            } catch {
                Write-Verbose "⚠️ Convert-Timestamp: Failed generic fallback UTC conversion for '$TimestampString': $($_.Exception.Message)"
            }
        }

        Write-Verbose "❌ Convert-Timestamp: Failed to parse timestamp: '$TimestampString' after all attempts."
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
                # Try fallback regex: timestamp anywhere in the line
                $match = $Script:LogFallbackRegex.Match($LogLine)
                if (-not $match.Success) {
                    Write-Verbose "❌ ConvertFrom-LogEntry: Log line could not be matched by any regex pattern: '$LogLine'"
                    return [PSCustomObject]@{
                        Timestamp = $null
                        Level     = "UNPARSEABLE"
                        Message   = $LogLine
                        RawLine   = $LogLine
                    }
                }
            }

            # Extract matched groups
            $timestampString = $match.Groups["Timestamp"].Value.Trim()
            $level = $match.Groups["Level"].Value
            $message = $match.Groups["Message"].Value.Trim()

            # Convert the extracted timestamp string
            $parsedTimestamp = Convert-Timestamp -TimestampString $timestampString

            # Create and return the structured object
            return [PSCustomObject]@{
                Timestamp = $parsedTimestamp
                Level     = if ([string]::IsNullOrWhiteSpace($level)) { "UNKNOWN" } else { $level }
                Message   = $message
                RawLine   = $LogLine
            }
        }
        catch {
            Write-Warning "❌ ConvertFrom-LogEntry: An exception occurred while processing log line '$LogLine': $($_.Exception.Message)"
            # Return a structured object indicating an error, rather than just $null
            return [PSCustomObject]@{
                Timestamp = $null
                Level     = "ERROR"
                Message   = "Exception occurred during parsing: $($_.Exception.Message)"
                RawLine   = $LogLine
            }
        }
    }
}

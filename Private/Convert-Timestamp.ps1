# Requires -Version 5.1

# Precompile regex for log parsing
$LogLineRegex = [regex]::new(
    '^(?<Timestamp>(\d{4}-\d{2}-\d{2}[ T]\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:\d{2})?|' +
    '[A-Za-z]{3}\s+\d{1,2}\s+\d{2}:\d{2}:\d{2}|' +
    '(?:\d{2}/\d{2}/\d{4}|\d{4}/\d{2}/\d{2})\s+\d{2}:\d{2}:\d{2}(?:\s*[AP]M)?|' +
    '(?:\d{2}/\d{2}/\d{4}|\d{4}/\d{2}/\d{2})\s+\d{2}:\d{2}:\d{2}|' +
    '(?:\d{2}/\d{2}/\d{4}|\d{4}/\d{2}/\d{2})))' +
    '(?:\s*\[(?<Level>[A-Z]+)\])?\s*(?<Message>.*)$',
    [System.Text.RegularExpressions.RegexOptions]::Compiled
)

function Convert-Timestamp {
    <#
    .SYNOPSIS
        Converts a string timestamp into a System.DateTime object.
    .DESCRIPTION
        Attempts to parse a given timestamp string into a DateTime object using
        common formats, syslog-style fallback, and flexible parsing.
    .PARAMETER TimestampString
        The timestamp string to parse.
    .RETURNS
        [datetime] if parsing succeeds, otherwise $null.
    #>
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline = $true)]
        [string]$TimestampString,

        [Parameter()]
        [System.Globalization.CultureInfo]$Culture = [System.Globalization.CultureInfo]::GetCultureInfo('en-US')
    )

    process {
        if ([string]::IsNullOrWhiteSpace($TimestampString)) {
            return $null
        }

        $formats = @(
            @{ Format = "o"; Style = [System.Globalization.DateTimeStyles]::RoundtripKind },
            @{ Format = "yyyy-MM-ddTHH:mm:ss"; Style = [System.Globalization.DateTimeStyles]::AssumeUniversal },
            @{ Format = "yyyy-MM-ddTHH:mm:ss'Z'"; Style = [System.Globalization.DateTimeStyles]::AssumeUniversal },
            @{ Format = "yyyy-MM-ddTHH:mm:ss.fff"; Style = [System.Globalization.DateTimeStyles]::AssumeUniversal },
            @{ Format = "yyyy-MM-ddTHH:mm:ss.fff'Z'"; Style = [System.Globalization.DateTimeStyles]::AssumeUniversal },
            @{ Format = "yyyy-MM-dd HH:mm:ss"; Style = [System.Globalization.DateTimeStyles]::None },
            @{ Format = "MM/dd/yyyy HH:mm:ss"; Style = [System.Globalization.DateTimeStyles]::None },
            @{ Format = "dd/MM/yyyy HH:mm:ss"; Style = [System.Globalization.DateTimeStyles]::None },
            @{ Format = "MM/dd/yyyy hh:mm:ss tt"; Style = [System.Globalization.DateTimeStyles]::None },
            @{ Format = "dd/MM/yyyy hh:mm:ss tt"; Style = [System.Globalization.DateTimeStyles]::None }
        )

        foreach ($entry in $formats) {
            [datetime]$parsed = $null
            if ([datetime]::TryParseExact($TimestampString, $entry.Format, $Culture, $entry.Style, [ref]$parsed)) {
                return $parsed
            }
        }

        # Syslog-style fallback (no year)
        $syslogFormats = @("MMM d HH:mm:ss", "MMM dd HH:mm:ss")
        $currentYear = (Get-Date).Year

        foreach ($fmt in $syslogFormats) {
            [datetime]$syslogResult = $null
            if ([datetime]::TryParseExact($TimestampString, $fmt, $Culture, [System.Globalization.DateTimeStyles]::AllowWhiteSpaces, [ref]$syslogResult)) {
                try {
                    $adjusted = Get-Date -Year $currentYear -Month $syslogResult.Month -Day $syslogResult.Day `
                        -Hour $syslogResult.Hour -Minute $syslogResult.Minute -Second $syslogResult.Second
                    return $adjusted
                }
                catch {
                    continue
                }
            }
        }

        # Generic flexible fallback
        [datetime]$fallback = $null
        if ([datetime]::TryParse($TimestampString, $Culture, [System.Globalization.DateTimeStyles]::AllowWhiteSpaces, [ref]$fallback)) {
            return $fallback
        }

        return $null
    }
}

function ConvertFrom-LogEntry {
    <#
    .SYNOPSIS
        Converts a log line string into a structured object with Timestamp, Level, Message.
    .PARAMETER LogLine
        Single log line string to parse.
    .RETURNS
        PSCustomObject with properties: Timestamp ([datetime]), Level (string), Message (string), RawLine (string).
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]$LogLine
    )

    process {
        try {
            $match = $LogLineRegex.Match($LogLine)
            if ($match.Success) {
                $timestampString = $match.Groups["Timestamp"].Value.Trim()
                $level = $match.Groups["Level"].Value
                $message = $match.Groups["Message"].Value.Trim()

                $parsedTimestamp = Convert-Timestamp -TimestampString $timestampString

                [PSCustomObject]@{
                    Timestamp = $parsedTimestamp
                    Level     = if ([string]::IsNullOrWhiteSpace($level)) { "UNKNOWN" } else { $level }
                    Message   = $message
                    RawLine   = $LogLine
                }
            }
            else {
                [PSCustomObject]@{
                    Timestamp = $null
                    Level     = "UNPARSEABLE"
                    Message   = $LogLine
                    RawLine   = $LogLine
                }
            }
        }
        catch {
            return $null
        }
    }
}

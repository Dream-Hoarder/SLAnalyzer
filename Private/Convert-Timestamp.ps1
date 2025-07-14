# Requires -Version 5.1

function Convert-Timestamp {
    <#
    .SYNOPSIS
        Converts a string timestamp into a System.DateTime object.
    .DESCRIPTION
        Attempts to parse a given timestamp string into a DateTime object using
        multiple common formats, including ISO8601, syslog style, and generic fallbacks.
    .PARAMETER TimestampString
        The timestamp string to parse.
    .RETURNS
        [datetime] if parsing succeeds, otherwise $null.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false, ValueFromPipeline = $true)]
        [string]$TimestampString,

        [Parameter(Mandatory = $false)]
        [System.Globalization.CultureInfo]$Culture = [System.Globalization.CultureInfo]::GetCultureInfo('en-US')
    )

    process {
        try {
            if ([string]::IsNullOrWhiteSpace($TimestampString)) {
                return $null
            }

            [datetime]$result = $null

            $formats = @(
                @{ Format = "o"; Style = [System.Globalization.DateTimeStyles]::RoundtripKind },
                @{ Format = "yyyy-MM-ddTHH:mm:ss"; Style = [System.Globalization.DateTimeStyles]::AssumeUniversal },
                @{ Format = "yyyy-MM-ddTHH:mm:ss'Z'"; Style = [System.Globalization.DateTimeStyles]::AssumeUniversal },
                @{ Format = "yyyy-MM-ddTHH:mm:ss.fff"; Style = [System.Globalization.DateTimeStyles]::AssumeUniversal },
                @{ Format = "yyyy-MM-ddTHH:mm:ss.fff'Z'"; Style = [System.Globalization.DateTimeStyles]::AssumeUniversal },
                @{ Format = "yyyy-MM-ddTHH:mm:sszzz"; Style = [System.Globalization.DateTimeStyles]::None },
                @{ Format = "yyyy-MM-ddTHH:mm:ss.fffzzz"; Style = [System.Globalization.DateTimeStyles]::None },
                @{ Format = "yyyy-MM-dd HH:mm:ss"; Style = [System.Globalization.DateTimeStyles]::None },
                @{ Format = "yyyy/MM/dd HH:mm:ss"; Style = [System.Globalization.DateTimeStyles]::None },
                @{ Format = "MM/dd/yyyy HH:mm:ss"; Style = [System.Globalization.DateTimeStyles]::None },
                @{ Format = "dd/MM/yyyy HH:mm:ss"; Style = [System.Globalization.DateTimeStyles]::None },
                @{ Format = "yyyy-MM-dd"; Style = [System.Globalization.DateTimeStyles]::None },
                @{ Format = "yyyyMMdd"; Style = [System.Globalization.DateTimeStyles]::None },
                @{ Format = "MM/dd/yyyy"; Style = [System.Globalization.DateTimeStyles]::None },
                @{ Format = "dd/MM/yyyy"; Style = [System.Globalization.DateTimeStyles]::None },
                @{ Format = "MM/dd/yyyy hh:mm:ss tt"; Style = [System.Globalization.DateTimeStyles]::None },
                @{ Format = "dd/MM/yyyy hh:mm:ss tt"; Style = [System.Globalization.DateTimeStyles]::None },
                @{ Format = "yyyy-MM-dd hh:mm:ss tt"; Style = [System.Globalization.DateTimeStyles]::None }
            )

            foreach ($formatEntry in $formats) {
                if ([DateTime]::TryParseExact($TimestampString, $formatEntry.Format, $Culture, $formatEntry.Style, [ref]$result)) {
                    return $result.ToLocalTime()
                }
            }

            # Syslog-style fallback (assume current year)
            $syslogFormats = @("MMM d HH:mm:ss", "MMM dd HH:mm:ss")
            $syslogStyle = [System.Globalization.DateTimeStyles]::AllowWhiteSpaces
            $currentYear = (Get-Date).Year

            foreach ($fmt in $syslogFormats) {
                [datetime]$syslogResult = $null
                if ([DateTime]::TryParseExact($TimestampString, $fmt, $Culture, $syslogStyle, [ref]$syslogResult)) {
                    $syslogResult = [datetime]::SpecifyKind($syslogResult, [System.DateTimeKind]::Unspecified)
                    $adjusted = $syslogResult.AddYears($currentYear - $syslogResult.Year)
                    return $adjusted
                }
            }

            # Generic flexible parse attempts
            $genericStyles = @(
                [System.Globalization.DateTimeStyles]::AllowWhiteSpaces,
                [System.Globalization.DateTimeStyles]::AssumeUniversal,
                [System.Globalization.DateTimeStyles]::AssumeLocal,
                [System.Globalization.DateTimeStyles]::RoundtripKind,
                ([System.Globalization.DateTimeStyles]::AllowWhiteSpaces -bor [System.Globalization.DateTimeStyles]::AssumeUniversal),
                ([System.Globalization.DateTimeStyles]::AllowWhiteSpaces -bor [System.Globalization.DateTimeStyles]::AssumeLocal),
                ([System.Globalization.DateTimeStyles]::AllowWhiteSpaces -bor [System.Globalization.DateTimeStyles]::RoundtripKind)
            )

            foreach ($gStyle in $genericStyles) {
                [datetime]$genericResult = $null
                if ([DateTime]::TryParse($TimestampString, $Culture, $gStyle, [ref]$genericResult)) {
                    return $genericResult.ToLocalTime()
                }
            }

            # Last fallback: DateTime.Parse
            try {
                $parsedDateTime = [DateTime]::Parse($TimestampString, $Culture)
                return $parsedDateTime.ToLocalTime()
            }
            catch {
                return $null
            }
        }
        catch {
            return $null
        }
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
            $regex = '^(?<Timestamp>(\d{4}-\d{2}-\d{2}[ T]\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:\d{2})?|[A-Za-z]{3}\s+\d{1,2}\s+\d{2}:\d{2}:\d{2}|(?:\d{2}/\d{2}/\d{4}|\d{4}/\d{2}/\d{2})\s+\d{2}:\d{2}:\d{2}(?:\s*[AP]M)?|(?:\d{2}/\d{2}/\d{4}|\d{4}/\d{2}/\d{2})\s+\d{2}:\d{2}:\d{2}|(?:\d{2}/\d{2}/\d{4}|\d{4}/\d{2}/\d{2})))(?:\s*\[(?<Level>[A-Z]+)\])?\s*(?<Message>.*)$'

            if ($LogLine -match $regex) {
                $timestampString = $Matches.Timestamp.Trim()
                $level = $Matches.Level
                $message = $Matches.Message.Trim()

                $parsedTimestamp = Convert-Timestamp -TimestampString $timestampString

                if (-not $parsedTimestamp) {
                    # Timestamp parsing failed, but still return object with null Timestamp
                    # Optionally could log a warning here but omitted to avoid noise in modules
                }

                [PSCustomObject]@{
                    Timestamp = $parsedTimestamp
                    Level     = if ([string]::IsNullOrEmpty($level)) { "UNKNOWN" } else { $level }
                    Message   = $message
                    RawLine   = $LogLine
                }
            }
            else {
                # Return minimal object for unparseable lines
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

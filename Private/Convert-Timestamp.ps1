# Requires -Version 5.1 # Or 7.0 for PowerShell Core features if needed, but this should work on 5.1+

function Convert-Timestamp {
    <#
    .SYNOPSIS
        Converts a string timestamp into a System.DateTime object.
    .DESCRIPTION
        This function attempts to parse a given timestamp string into a System.DateTime object
        using a variety of common formats and parsing styles. It includes fallbacks for
        ISO 8601, syslog-like formats (assuming current year), and generic parsing attempts.
        It's designed to be robust against different timestamp representations.
    .PARAMETER TimestampString
        The string containing the timestamp to convert.
    .RETURNS
        A System.DateTime object if parsing is successful, otherwise $null.
    .EXAMPLE
        Convert-Timestamp -TimestampString "2025-07-03T14:30:00"
        # Output: A DateTime object representing 7/3/2025 2:30:00 PM (local time)

    .EXAMPLE
        Convert-Timestamp -TimestampString "Jul  3 14:30:00"
        # Output: A DateTime object for July 3rd of the current year, 2:30:00 PM (local time)

    .EXAMPLE
        "2025-07-03 10:00:00" | Convert-Timestamp
        # Output: A DateTime object representing 7/3/2025 10:00:00 AM (local time)
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
                Write-Verbose "Input is null or whitespace. Returning null."
                return $null
            }

            [datetime]$result = $null

            # --- Phase 1: Try parsing with specific formats and tailored DateTimeStyles ---
            $formats = @(
                @{ Format = "o"; Style = [System.Globalization.DateTimeStyles]::RoundtripKind }, # 2025-07-03T14:30:00.0000000Z
                @{ Format = "yyyy-MM-ddTHH:mm:ss"; Style = [System.Globalization.DateTimeStyles]::AssumeUniversal }, # 2025-07-03T14:30:00
                @{ Format = "yyyy-MM-ddTHH:mm:ss'Z'"; Style = [System.Globalization.DateTimeStyles]::AssumeUniversal }, # 2025-07-03T14:30:00Z
                @{ Format = "yyyy-MM-ddTHH:mm:ss.fff"; Style = [System.Globalization.DateTimeStyles]::AssumeUniversal },
                @{ Format = "yyyy-MM-ddTHH:mm:ss.fff'Z'"; Style = [System.Globalization.DateTimeStyles]::AssumeUniversal },
                @{ Format = "yyyy-MM-ddTHH:mm:sszzz"; Style = [System.Globalization.DateTimeStyles]::None },
                @{ Format = "yyyy-MM-ddTHH:mm:ss.fffzzz"; Style = [System.Globalization.DateTimeStyles]::None },
                @{ Format = "yyyy-MM-dd HH:mm:ss"; Style = [System.Globalization.DateTimeStyles]::None }, # 2025-07-03 23:59:59
                @{ Format = "yyyy/MM/dd HH:mm:ss"; Style = [System.Globalization.DateTimeStyles]::None },
                @{ Format = "MM/dd/yyyy HH:mm:ss"; Style = [System.Globalization.DateTimeStyles]::None },
                @{ Format = "dd/MM/yyyy HH:mm:ss"; Style = [System.Globalization.DateTimeStyles]::None },
                @{ Format = "yyyy-MM-dd"; Style = [System.Globalization.DateTimeStyles]::None },
                @{ Format = "yyyyMMdd"; Style = [System.Globalization.DateTimeStyles]::None },
                @{ Format = "MM/dd/yyyy"; Style = [System.Globalization.DateTimeStyles]::None },
                @{ Format = "dd/MM/yyyy"; Style = [System.Globalization.DateTimeStyles]::None },
                @{ Format = "MM/dd/yyyy hh:mm:ss tt"; Style = [System.Globalization.DateTimeStyles]::None }, # 07/03/2025 08:00:00 AM
                @{ Format = "dd/MM/yyyy hh:mm:ss tt"; Style = [System.Globalization.DateTimeStyles]::None },
                @{ Format = "yyyy-MM-dd hh:mm:ss tt"; Style = [System.Globalization.DateTimeStyles]::None }
            )

            foreach ($formatEntry in $formats) {
                $currentFormat = $formatEntry.Format
                $currentStyle = $formatEntry.Style

                if ([DateTime]::TryParseExact($TimestampString, $currentFormat, $Culture, $currentStyle, [ref]$result)) {
                    Write-Verbose "Parsed using format '$currentFormat' with style '$currentStyle'"
                    return $result.ToLocalTime()
                }
            }

            # --- Phase 2: Syslog-style fallback ---
            $syslogFormats = @("MMM d HH:mm:ss", "MMM dd HH:mm:ss")
            $syslogStyle = [System.Globalization.DateTimeStyles]::AllowWhiteSpaces
            $currentYear = (Get-Date).Year

            foreach ($fmt in $syslogFormats) {
                [datetime]$syslogResult = $null
                if ([DateTime]::TryParseExact($TimestampString, $fmt, $Culture, $syslogStyle, [ref]$syslogResult)) {
                    $syslogResult = [datetime]::SpecifyKind($syslogResult, [System.DateTimeKind]::Unspecified)
                    $adjusted = $syslogResult.AddYears($currentYear - $syslogResult.Year)
                    Write-Verbose "Parsed as syslog format '$fmt' and adjusted year to $currentYear"
                    return $adjusted
                }
            }

            # --- Phase 3: Flexible TryParse attempts ---
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
                    Write-Verbose "Parsed using generic TryParse with style '$gStyle'"
                    return $genericResult.ToLocalTime()
                }
            }

            # --- Phase 4: Ultimate fallback ---
            try {
                $parsedDateTime = [DateTime]::Parse($TimestampString, $Culture)
                Write-Verbose "Parsed using DateTime.Parse fallback"
                return $parsedDateTime.ToLocalTime()
            }
            catch {
                Write-Verbose "DateTime.Parse failed: $_"
            }

            Write-Verbose "All parsing attempts failed. Returning null."
            return $null
        }
        catch {
            Write-Warning "Convert-Timestamp failed on input '$TimestampString': $_"
            return $null
        }
    }
}
function ConvertFrom-LogEntry {
    <#
    .SYNOPSIS
        Converts a single log line into a PSCustomObject with structured properties.
    .DESCRIPTION
        This function takes a raw log line string, extracts the timestamp, log level,
        and message using a regular expression, and then converts the timestamp
        into a System.DateTime object using Convert-Timestamp.
        It outputs a PSCustomObject, making log data easy to filter, sort, and analyze.

        Assumed log format: "Timestamp [LEVEL] Message" or "Timestamp Message"
        (where Timestamp can be various formats handled by Convert-Timestamp).
    .PARAMETER LogLine
        The full log line string to convert.
    .RETURNS
        A PSCustomObject with properties:
        - Timestamp (System.DateTime)
        - Level (string, e.g., "INFO", "WARNING", "ERROR", or "UNKNOWN" if not found)
        - Message (string)
        Returns $null if the log line cannot be parsed.
    .EXAMPLE
        $logLine1 = "2025-07-03T14:30:00 [INFO] User 'admin' logged in successfully."
        ConvertFrom-LogEntry -LogLine $logLine1 | Format-List

        # Output:
        # Timestamp : 7/3/2025 2:30:00 PM
        # Level     : INFO
        # Message   : User 'admin' logged in successfully.

    .EXAMPLE
        $logLine2 = "Jul  3 10:15:05 [WARNING] Disk space low on /dev/sda1."
        ConvertFrom-LogEntry -LogLine $logLine2 | Select-Object Timestamp, Level

        # Output:
        # Timestamp          Level
        # ---------          -----
        # 7/3/2025 10:15:05 AM WARNING

    .EXAMPLE
        Get-Content "C:\Path\To\Your\LogFile.log" | ConvertFrom-LogEntry | Where-Object {$_.Level -eq "ERROR"}
        # Converts each line from a log file and filters for error entries.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]$LogLine
    )

    process {
        try {
            # Regex to capture timestamp, optional level, and message.
            $regex = '^(?<Timestamp>(\d{4}-\d{2}-\d{2}[ T]\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:\d{2})?|[A-Za-z]{3}\s+\d{1,2}\s+\d{2}:\d{2}:\d{2}|(?:\d{2}/\d{2}/\d{4}|\d{4}/\d{2}/\d{2})\s+\d{2}:\d{2}:\d{2}(?:\s*[AP]M)?|(?:\d{2}/\d{2}/\d{4}|\d{4}/\d{2}/\d{2})\s+\d{2}:\d{2}:\d{2}|(?:\d{2}/\d{2}/\d{4}|\d{4}/\d{2}/\d{2})))(?:\s*\[(?<Level>[A-Z]+)\])?\s*(?<Message>.*)$'

            if ($LogLine -match $regex) {
                $timestampString = $Matches.Timestamp.Trim()
                $level = $Matches.Level
                $message = $Matches.Message.Trim()

                # Convert the timestamp string using our helper function
                $parsedTimestamp = Convert-Timestamp -TimestampString $timestampString

                # If timestamp parsing fails, we can still return an object,
                # but with a null timestamp or handle as an error.
                if (-not $parsedTimestamp) {
                    Write-Warning "ConvertFrom-LogEntry: Could not parse timestamp '$timestampString' from log line: '$LogLine'"
                    # Optionally, return $null here if a valid timestamp is strictly required
                    # return $null
                }

                # Create the PSCustomObject
                [PSCustomObject]@{
                    Timestamp = $parsedTimestamp
                    Level     = if ([string]::IsNullOrEmpty($level)) { "UNKNOWN" } else { $level }
                    Message   = $message
                    RawLine   = $LogLine # Include the original raw line for debugging/reference
                }
            }
            else {
                Write-Warning "ConvertFrom-LogEntry: Could not parse log line using regex: '$LogLine'"
                # Return an object with minimal info for unparseable lines, or $null
                [PSCustomObject]@{
                    Timestamp = $null
                    Level     = "UNPARSEABLE"
                    Message   = $LogLine
                    RawLine   = $LogLine
                }
            }
        }
        catch {
            Write-Error "ConvertFrom-LogEntry failed on log line '$LogLine': $_"
            return $null
        }
    } # End process block
}

# --- Example Usage ---
Write-Host "`n--- Demonstrating ConvertFrom-LogEntry ---"

$sampleLogLines = @(
    "2025-07-03T14:30:00 [INFO] User 'admin' logged in successfully.",
    "2025-07-03T14:30:00Z [DEBUG] Debug information for process ID 1234.",
    "Jul  3 10:15:05 [WARNING] Disk space low on /dev/sda1.",
    "2025-07-03 23:59:59 This is a log entry without a specific level.",
    "07/03/2025 08:00:00 AM [ERROR] Failed to connect to database.",
    "NotAValidTimestamp [CRITICAL] System crashed!", # Unparseable timestamp, but regex should match
    "Just a plain message without a clear timestamp or level." # Completely unparseable by regex
)

foreach ($line in $sampleLogLines) {
    Write-Host "`nConverting: $line"
    $parsedObject = ConvertFrom-LogEntry -LogLine $line
    if ($parsedObject) {
        $parsedObject | Format-List
    } else {
        Write-Host "  -> Failed to convert log line into an object."
    }
}

Write-Host "`n--- Filtering and Sorting Example ---"
$logData = @(
    "2025-07-03T14:30:00 [INFO] User 'admin' logged in successfully.",
    "2025-07-03T14:30:00Z [DEBUG] Debug information for process ID 1234.",
    "Jul  3 10:15:05 [WARNING] Disk space low on /dev/sda1.",
    "2025-07-03 23:59:59 This is a log entry without a specific level.",
    "07/03/2025 08:00:00 AM [ERROR] Failed to connect to database.",
    "2025-07-02T12:00:00 [INFO] Another entry from yesterday."
) | ConvertFrom-LogEntry

Write-Host "`nAll converted log entries:"
$logData | Format-Table -AutoSize

Write-Host "`nErrors only:"
$logData | Where-Object {$_.Level -eq "ERROR"} | Format-Table -AutoSize

Write-Host "`nSorted by Timestamp (oldest first):"
$logData | Sort-Object Timestamp | Format-Table -AutoSize

Write-Host "`nMessages containing 'disk':"
$logData | Where-Object {$_.Message -match "disk"} | Format-Table -AutoSize
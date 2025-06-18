function Convert-Timestamp {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$Line
    )

    # Try matching a timestamp first
    if ($Line -match '(\d{4}-\d{2}-\d{2}[ T]\d{2}:\d{2}:\d{2}(?:Z|[\+\-]\d{2}:\d{2})?)') {
        $rawTimestamp = $matches[1]

        $formats = @(
            'yyyy-MM-dd HH:mm:ss',
            'yyyy-MM-ddTHH:mm:ss',
            'yyyy-MM-ddTHH:mm:ssZ',
            'yyyy-MM-ddTHH:mm:sszzz'
        )

        foreach ($fmt in $formats) {
            $parsed = $null
            if ([datetime]::TryParseExact($rawTimestamp, $fmt, $null, [System.Globalization.DateTimeStyles]::None, [ref]$parsed)) {
                return $parsed
            }
        }
    }

    # Syslog format: "Jun 12 14:35:00"
    if ($Line -match '^(?<Month>\w{3}) +(?<Day>\d{1,2}) (?<Time>\d{2}:\d{2}:\d{2})') {
        $year = (Get-Date).Year
        $dateStr = "$($matches['Month']) $($matches['Day']) $year $($matches['Time'])"
        return [datetime]::ParseExact($dateStr, 'MMM dd yyyy HH:mm:ss', $null)
    }

    return $null
}

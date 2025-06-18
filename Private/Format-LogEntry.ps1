function Format-LogEntry {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$Line,

        [string[]]$CustomPatterns = @()
    )

    # Try custom regex rules from config or input
    foreach ($pattern in $CustomPatterns) {
        if ($Line -match $pattern) {
            return [PSCustomObject]@{
                Timestamp = if ($matches['Time']) { $matches['Time'] } else { $null }
                Level     = if ($matches['Level']) { $matches['Level'] } else { 'Info' }
                Provider  = if ($matches['Source']) { $matches['Source'] } else { 'Unknown' }
                Message   = if ($matches['Message']) { $matches['Message'] } else { $Line }
            }
        }
    }

    # Fallback 1: SmartLogAnalyzer default format
    if ($Line -match '^(?<Time>[\d\-\s:]+) \[(?<Level>[^\]]+)\] (?<Provider>[^:]+): (?<Message>.+)$') {
        return [PSCustomObject]@{
            Timestamp = [datetime]::ParseExact($matches['Time'], 'yyyy-MM-dd HH:mm:ss', $null)
            Level     = $matches['Level']
            Provider  = $matches['Provider']
            Message   = $matches['Message']
        }
    }

    # Fallback 2: Syslog-like format
    if ($Line -match '^(?<Month>\w{3}) +(?<Day>\d{1,2}) (?<Time>\d{2}:\d{2}:\d{2}) (?<Host>\S+) (?<Source>[^:]+): (?<Message>.+)$') {
        $year = (Get-Date).Year
        $datetime = "$($matches['Month']) $($matches['Day']) $year $($matches['Time'])"
        return [PSCustomObject]@{
            Timestamp = [datetime]::ParseExact($datetime, 'MMM dd yyyy HH:mm:ss', $null)
            Level     = 'Info'
            Provider  = $matches['Source']
            Message   = $matches['Message']
        }
    }

    # No match fallback
    return $null
}

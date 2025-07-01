function Protect-Message {
    param (
        [string]$Message
    )
    # Define sensitive patterns to redact
    $patterns = @(
        'password\s*\S+',
        'token\s*\S+',
        'secret\s*\S+',
        'apikey\s*\S+',
        'api_key\s*\S+'
    )
    foreach ($pat in $patterns) {
        $Message = [regex]::Replace($Message, $pat, '[REDACTED]', 'IgnoreCase')
    }
    return $Message
}

function Format-LogEntry {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$Line,

        [string[]]$CustomPatterns = @(),

        [switch]$Redact
    )

    # Try custom regex rules from config or input
    foreach ($pattern in $CustomPatterns) {
        if ($Line -match $pattern) {
            $timestamp = if ($matches['Time']) { $matches['Time'] } else { $null }
            $level     = if ($matches['Level']) { $matches['Level'] } else { 'Info' }
            $provider  = if ($matches['Source']) { $matches['Source'] } else { 'Unknown' }
            $message   = if ($matches['Message']) { $matches['Message'] } else { $Line }

            if ($Redact) {
                $message = Protect-Message -Message $message
            }

            return [PSCustomObject]@{
                Timestamp = $timestamp
                Level     = $level
                Provider  = $provider
                Message   = $message
            }
        }
    }

    # Fallback 1: SmartLogAnalyzer default format
    if ($Line -match '^(?<Time>[\d\-\s:]+) \[(?<Level>[^\]]+)\] (?<Provider>[^:]+): (?<Message>.+)$') {
        $timestamp = [datetime]::ParseExact($matches['Time'], 'yyyy-MM-dd HH:mm:ss', $null)
        $level = $matches['Level']
        $provider = $matches['Provider']
        $message = $matches['Message']

        if ($Redact) {
            $message = Protect-Message -Message $message
        }

        return [PSCustomObject]@{
            Timestamp = $timestamp
            Level     = $level
            Provider  = $provider
            Message   = $message
        }
    }

    # Fallback 2: Syslog-like format
    if ($Line -match '^(?<Month>\w{3}) +(?<Day>\d{1,2}) (?<Time>\d{2}:\d{2}:\d{2}) (?<Host>\S+) (?<Source>[^:]+): (?<Message>.+)$') {
        $year = (Get-Date).Year
        $datetime = "$($matches['Month']) $($matches['Day']) $year $($matches['Time'])"
        $timestamp = [datetime]::ParseExact($datetime, 'MMM dd yyyy HH:mm:ss', $null)
        $level = 'Info'
        $provider = $matches['Source']
        $message = $matches['Message']

        if ($Redact) {
            $message = Protect-Message -Message $message
        }

        return [PSCustomObject]@{
            Timestamp = $timestamp
            Level     = $level
            Provider  = $provider
            Message   = $message
        }
    }

    # No match fallback
    return $null
}





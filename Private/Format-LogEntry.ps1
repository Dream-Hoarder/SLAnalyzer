function Protect-Message {
    param (
        [string]$Message
    )
    # Refined sensitive data patterns with boundary-aware redaction
    $patterns = @(
        '(?i)\b(password|token|secret|apikey|api_key)\b\s*[:=]?\s*\S+'
    )
    foreach ($pattern in $patterns) {
        $Message = [regex]::Replace($Message, $pattern, '[REDACTED]', 'IgnoreCase')
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

    # --- Custom Pattern Matching ---
    if ($CustomPatterns.Count -gt 0) {
        foreach ($pattern in $CustomPatterns) {
            if ($Line -match $pattern) {
                $timestamp = $matches['Time']
                $level     = $matches['Level']    ?? 'Info'
                $provider  = $matches['Source']   ?? 'Unknown'
                $message   = $matches['Message']  ?? $Line

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
    }

    # --- SmartLogAnalyzer Default ---
    if ($Line -match '^(?<Time>\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}) \[(?<Level>[^\]]+)\] (?<Provider>[^:]+): (?<Message>.+)$') {
        $timestamp = $null
        try {
            [datetime]::TryParseExact($matches['Time'], 'yyyy-MM-dd HH:mm:ss', $null, 'None', [ref]$timestamp) | Out-Null
        } catch {
            $timestamp = $null
        }

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

    # --- Syslog-like ---
    if ($Line -match '^(?<Month>\w{3}) +(?<Day>\d{1,2}) (?<Time>\d{2}:\d{2}:\d{2}) (?<Host>\S+) (?<Source>[^:]+): (?<Message>.+)$') {
        $timestamp = $null
        try {
            $year = (Get-Date).Year
            $datetime = "$($matches['Month']) $($matches['Day']) $year $($matches['Time'])"
            [datetime]::TryParseExact($datetime, 'MMM dd yyyy HH:mm:ss', $null, 'None', [ref]$timestamp) | Out-Null
        } catch {
            $timestamp = $null
        }

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

    # --- No match fallback ---
    return $null
}

function Protect-LogEntry {
    [CmdletBinding()]
    param (
        [pscustomobject]$Entry,
        [ref]$RedactionLog
    )

    $copy = $Entry.PSObject.Copy()

    # Redact UserName if exists
    if ($copy.PSObject.Properties.Match('UserName')) {
        if ($copy.UserName -match '\S') {
            $RedactionLog.Value.Add("UserName: $($copy.UserName)")
            $copy.UserName = '[REDACTED]'
        }
    }

    # Redact valid IP addresses in the Message field
    if ($copy.PSObject.Properties.Match('Message')) {
        $ipRegex = '\b(?:(?:25[0-5]|2[0-4]\d|1\d{2}|[1-9]?\d)\.){3}(?:25[0-5]|2[0-4]\d|1\d{2}|[1-9]?\d)\b'
        if ($copy.Message -match $ipRegex) {
            foreach ($match in [regex]::Matches($copy.Message, $ipRegex)) {
                $RedactionLog.Value.Add("IP Address: $($match.Value)")
                $copy.Message = $copy.Message -replace [regex]::Escape($match.Value), '[REDACTED]'
            }
        }
    }

    # Redact Email if it exists and matches pattern
    if ($copy.PSObject.Properties.Match('Email')) {
        $emailRegex = '\b[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}\b'
        if ($copy.Email -match $emailRegex) {
            $RedactionLog.Value.Add("Email: $($copy.Email)")
            $copy.Email = '[REDACTED]'
        }
    }

    return $copy
}

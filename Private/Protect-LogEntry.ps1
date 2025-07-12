function Protect-LogEntry {
    [CmdletBinding()]
    param (
        [pscustomobject]$Entry,
        [ref]$RedactionLog
    )

    $copy = $Entry.PSObject.Copy()

    # Redact username
    if ($copy.UserName -match '\S') {
        $RedactionLog.Value.Add("UserName: $($copy.UserName)")
        $copy.UserName = '[REDACTED]'
    }

    # Redact IP addresses
    if ($copy.Message -match '\b\d{1,3}(\.\d{1,3}){3}\b') {
        $ipMatch = [regex]::Match($copy.Message, '\b\d{1,3}(\.\d{1,3}){3}\b')
        if ($ipMatch.Success) {
            $RedactionLog.Value.Add("IP Address: $($ipMatch.Value)")
            $copy.Message = $copy.Message -replace $ipMatch.Value, '[REDACTED]'
        }
    }

    # Redact email
    if ($copy.Email -match '\b\S+@\S+\.\S+\b') {
        $RedactionLog.Value.Add("Email: $($copy.Email)")
        $copy.Email = '[REDACTED]'
    }

    return $copy
}



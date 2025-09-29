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

function Format-WindowsEventMessage {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [System.Object]$EventObject
    )
    
    try {
        # If there's already a formatted message, prefer that
        if ($EventObject.Message -and $EventObject.Message -notmatch '^\s*<Event xmlns') {
            return $EventObject.Message
        }
        
        # Handle raw XML event data
        if ($EventObject.PSObject.Properties['RawLine'] -and $EventObject.RawLine -match '<Event xmlns') {
            try {
                [xml]$xmlEvent = $EventObject.RawLine
                
                # Extract common event information
                $eventId = $xmlEvent.Event.System.EventID.'#text'
                $providerName = $xmlEvent.Event.System.Provider.Name
                $level = $xmlEvent.Event.System.Level
                $computer = $xmlEvent.Event.System.Computer
                
                # Extract event data parameters
                $eventData = @()
                if ($xmlEvent.Event.EventData -and $xmlEvent.Event.EventData.Data) {
                    foreach ($data in $xmlEvent.Event.EventData.Data) {
                        if ($data.'#text') {
                            $eventData += $data.'#text'
                        }
                    }
                }
                
                # Create human-readable message based on common event patterns
                $humanMessage = Format-EventByIdAndProvider -EventId $eventId -Provider $providerName -EventData $eventData -Computer $computer
                
                if ($humanMessage) {
                    return $humanMessage
                } else {
                    # Fallback: create a basic readable message
                    $dataString = if ($eventData.Count -gt 0) { " Data: $($eventData -join ', ')" } else { "" }
                    return "Event $eventId from $providerName on $computer.$dataString"
                }
            } catch {
                Write-Verbose "Failed to parse XML event data: $($_.Exception.Message)"
            }
        }
        
        # If we can't format it, return the original message or a fallback
        if ($EventObject.Message) {
            return $EventObject.Message
        } else {
            return "Event from $($EventObject.ProviderName) (ID: $($EventObject.EventId))"
        }
    } catch {
        Write-Verbose "Error formatting Windows event message: $($_.Exception.Message)"
        return $EventObject.Message -replace '<[^>]+>', '' # Strip XML tags as fallback
    }
}

function Format-EventByIdAndProvider {
    [CmdletBinding()]
    param (
        [string]$EventId,
        [string]$Provider,
        [array]$EventData,
        [string]$Computer
    )
    
    # Common Windows Event translations
    $translations = @{
        # Service Control Manager events
        'Service Control Manager' = @{
            '7040' = "Service '{0}' start type changed from '{1}' to '{2}' (Service name: {3})"
            '7045' = "Service '{0}' was installed with start type '{1}' and runs as '{2}'"
            '7034' = "Service '{0}' terminated unexpectedly. This has happened {1} time(s)"
            '7035' = "Service '{0}' was successfully sent a {1} control"
            '7036' = "Service '{0}' entered the {1} state"
            '7030' = "Service '{0}' is configured as an interactive service but the system does not support this"
            '7009' = "Timeout waiting for service '{0}' to connect"
            '7000' = "Service '{0}' failed to start due to error: {1}"
            '7001' = "Service '{0}' depends on service '{1}' which failed to start"
            '7031' = "Service '{0}' terminated and will restart in {1} milliseconds"
        }
        
        # System events  
        'Microsoft-Windows-Kernel-General' = @{
            '1' = "System time was changed from '{0}' to '{1}'"
            '12' = "Operating system started at {0}"
            '13' = "Operating system is shutting down at {0}"
            '5' = "Access to {0} was denied"
            '16' = "Registry hive cleanup completed for {0} - updated {1} keys"
        }
        
        # User32 events
        'User32' = @{
            '1074' = "System shutdown initiated by user '{0}' on computer '{1}'. Reason: {2}"
        }
        
        # Logon/Logoff events (Security log)
        'Microsoft-Windows-Security-Auditing' = @{
            '4624' = "User '{0}' successfully logged on to '{1}' from '{2}' using logon type {3}"
            '4625' = "Failed logon attempt for user '{0}' on '{1}' from '{2}'. Reason: {3}"
            '4634' = "User '{0}' logged off from session {1}"
            '4648' = "User '{0}' attempted to log on using explicit credentials for '{1}'"
            '4672' = "Special privileges assigned to user '{0}' for new logon session"
            '4720' = "User account '{0}' was created by '{1}'"
            '4726' = "User account '{0}' was deleted by '{1}'"
            '4740' = "User account '{0}' was locked out"
        }
        
        # Winlogon events
        'Microsoft-Windows-Winlogon' = @{
            '7001' = "User logon notification (Customer Experience Improvement Program)"
            '7002' = "User logoff notification (Customer Experience Improvement Program)"
            '6005' = "The winlogon service was started"
            '6006' = "The winlogon service was stopped"
        }
        
        # Power/Kernel events
        'Microsoft-Windows-Kernel-Power' = @{
            '1' = "System is entering sleep state {0}. Sleep reason: {1}"
            '42' = "System is entering sleep state {0}"
            '107' = "System resumed from sleep"
            '109' = "Kernel power event occurred: {0}"
            '41' = "System rebooted without cleanly shutting down first"
        }
        
        # Application errors
        'Application Error' = @{
            '1000' = "Application '{0}' version {1} crashed. Faulting module: {2}"
            '1001' = "Fault bucket for application '{0}', type {1}"
        }
        
        # Windows Update Client
        'Microsoft-Windows-WindowsUpdateClient' = @{
            '19' = "Windows Update installation completed successfully: {0}"
            '20' = "Windows Update installation failed: {0}"
            '25' = "Windows Update installation started: {0}"
        }
        
        # DNS Client
        'Microsoft-Windows-DNS-Client' = @{
            '1014' = "DNS name resolution failed for '{0}'. Error: {1}"
        }
        
        # Disk events
        'Microsoft-Windows-Ntfs' = @{
            '55' = "File system corruption detected on volume {0}. Check disk recommended"
        }
        
        # Application crashes
        'Application Hang' = @{
            '1002' = "Application '{0}' stopped responding and was terminated"
        }
        
        # Windows Error Reporting
        'Windows Error Reporting' = @{
            '1001' = "Error report generated for crashed application '{0}'"
        }
        
        # Terminal Services
        'Microsoft-Windows-TerminalServices-LocalSessionManager' = @{
            '21' = "Remote Desktop Services session logon succeeded for user '{0}'"
            '23' = "Remote Desktop Services session logoff succeeded for user '{0}'"
            '24' = "Remote Desktop Services session disconnected for user '{0}'"
            '25' = "Remote Desktop Services session reconnected for user '{0}'"
        }
        
        # Group Policy
        'Microsoft-Windows-GroupPolicy' = @{
            '1502' = "Group Policy processing completed successfully in {0} seconds"
            '1503' = "Group Policy processing failed. Error: {0}"
        }
    }
    
    if ($translations.ContainsKey($Provider) -and $translations[$Provider].ContainsKey($EventId)) {
        $template = $translations[$Provider][$EventId]
        try {
            return $template -f $EventData
        } catch {
            # If formatting fails, return the template with available data
            return "$template (Data: $($EventData -join ', '))"
        }
    }
    
    return $null
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
                if ($matches) {
                    $timestamp = $matches['Time']
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
        }
    }

    # --- SmartLogAnalyzer Default ---
    if ($Line -match '^(?<Time>\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}) \[(?<Level>[^\]]+)\] (?<Provider>[^:]+): (?<Message>.+)$') {
        if ($matches) {
            $timestamp = Convert-Timestamp -TimestampString $matches['Time']

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
    }

    # --- Syslog-like ---
    if ($Line -match '^(?<Month>\w{3}) +(?<Day>\d{1,2}) (?<Time>\d{2}:\d{2}:\d{2}) (?<Host>\S+) (?<Source>[^:]+): (?<Message>.+)$') {
        if ($matches) {
            $timestampString = "$($matches['Month']) $($matches['Day']) $($matches['Time'])"
            $timestamp = Convert-Timestamp -TimestampString $timestampString

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
    }

    # --- No match fallback ---
    return $null
}

function Get-HtmlTemplate {
    param(
        [string]$Timestamp,
        [string]$SourcePath,
        [int]$EntryCount,
        [string]$ModuleVersion
    )

    $escapedSourcePath = Format-HtmlString -InputString $SourcePath

    return @"
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>SmartLogAnalyzer Report</title>
    <style>
        body { font-family: 'Segoe UI', sans-serif; background: #f8f9fa; color: #333; padding: 2em; }
        .header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 2em; border-radius: 8px; }
        .metadata { margin-top: 1em; }
        table { width: 100%; border-collapse: collapse; background: white; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
        ul { padding-left: 1.5em; }
        h1, h2 { margin-bottom: 0.5em; }
    </style>
</head>
<body>
<div class="header">
    <h1>SmartLogAnalyzer Report</h1>
    <div class="metadata">
        <strong>Generated:</strong> $Timestamp<br>
        <strong>Source:</strong> $escapedSourcePath<br>
        <strong>Entries:</strong> $EntryCount<br>
        <strong>Version:</strong> $ModuleVersion
    </div>
</div>
<h2>Summary</h2>
<ul>
"@
}

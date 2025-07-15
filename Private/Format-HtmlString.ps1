function Format-HtmlString {
    param([string]$InputString)

    if ([string]::IsNullOrEmpty($InputString)) {
        return ''
    }

    return $InputString `
        -replace '&', '&amp;' `
        -replace '<', '&lt;' `
        -replace '>', '&gt;' `
        -replace '"', '&quot;' `
        -replace "'", '&#39;'
}

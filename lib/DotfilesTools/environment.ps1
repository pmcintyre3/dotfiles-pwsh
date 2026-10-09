function Add-PathEntry {
    <#
    .SYNOPSIS
        Add an existing folder to $env:PATH once (prepends by default). Missing folders are ignored.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)] [string] $Path,
        [switch] $Append
    )

    process {
        if (-not (Test-Path -Path $Path -PathType Container)) { return }

        $normalized = $Path.TrimEnd('\', '/')
        $separator = [IO.Path]::PathSeparator
        $entries = @($env:PATH -split $separator | Where-Object { $_ })
        if ($entries | Where-Object { $_.TrimEnd('\', '/') -eq $normalized }) { return }

        $env:PATH = if ($Append) {
            (@($entries) + $normalized) -join $separator
        } else {
            (@($normalized) + $entries) -join $separator
        }
    }
}

function New-LocalFileFromTemplate {
    <#
    .SYNOPSIS
        Copy x.template to x if x doesn't exist yet. Returns $true when it created the file.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param([Parameter(Mandatory)] [string] $TemplatePath)

    $destination = $TemplatePath -replace '\.template$', ''
    if ($destination -eq $TemplatePath) { throw "Template file must end in .template: $TemplatePath" }
    if (Test-Path -Path $destination) { return $false }

    Copy-Item -Path $TemplatePath -Destination $destination
    return $true
}

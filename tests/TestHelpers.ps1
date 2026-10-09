# Shared by the profile, bootstrap, and dot tests. Never point these at the real $PROFILE or $HOME.

function Copy-DotfilesRepo {
    [CmdletBinding()]
    [OutputType([string])]
    param([Parameter(Mandatory)] [string] $Destination)

    $root = Split-Path -Path $PSScriptRoot -Parent
    New-Item -ItemType Directory -Path $Destination -Force | Out-Null
    Get-ChildItem -Path $root -Force |
        Where-Object { $_.Name -ne '.git' } |
        Copy-Item -Destination $Destination -Recurse -Force

    # Start from a clean machine: drop any local files copied from the dev clone.
    Get-ChildItem -Path $Destination -Recurse -Force -File -Include '*.local.ps1', '*.local.psd1', 'gitconfig.local', '*.backup-*' |
        Remove-Item -Force
    return $Destination
}

function Invoke-ProfileProbe {
    <#
    .SYNOPSIS
        Dot-source <RepoRoot>\powershell\profile.ps1 in a clean child pwsh and report what loaded.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $RepoRoot,
        [string[]] $CommandName = @('Add-PathEntry')
    )

    $probePath = Join-Path (Split-Path -Path $RepoRoot -Parent) 'probe.ps1'
    Set-Content -Path $probePath -Value @'
param([string] $ProfilePath, [string] $Names)
Remove-Item Env:ProjectHome -ErrorAction Ignore
$Error.Clear()
. $ProfilePath
$loadErrors = $Error.Count
[pscustomobject]@{
    LoadErrors = $loadErrors
    Commands   = @($Names -split ',' | Where-Object { Get-Command -Name $_ -ErrorAction Ignore })
    Source     = $ProjectPaths.Source
    BinOnPath  = @($env:PATH -split ';') -contains (Join-Path $DotfilesRoot 'bin')
} | ConvertTo-Json -Compress
'@

    $output = @(& pwsh -NoProfile -NonInteractive -File $probePath `
            -ProfilePath (Join-Path $RepoRoot 'powershell\profile.ps1') `
            -Names ($CommandName -join ',') *>&1 | ForEach-Object { "$_" })
    [pscustomobject]@{
        Output = $output
        Result = $output[-1] | ConvertFrom-Json
    }
}

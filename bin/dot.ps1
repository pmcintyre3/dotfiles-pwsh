#Requires -Version 7.4
<#
.SYNOPSIS
    dot: keep this machine current. Pulls the repo, then re-runs bootstrap (links + installers).
    Run it now and then. Credit: holman/dotfiles bin/dot, via haacked/dotfiles.
.EXAMPLE
    dot        # update everything
    dot -e     # open the dotfiles in VS Code
#>
[CmdletBinding()]
param(
    [Alias('e')] [switch] $Edit
)

$root = Split-Path -Path $PSScriptRoot -Parent

if ($Edit) {
    if (Get-Command -Name code -ErrorAction Ignore) { code $root } else { Invoke-Item $root }
    return
}

Import-Module (Join-Path $root 'lib\DotfilesTools.psm1') -Force

if (Test-Path -Path (Join-Path $root '.git')) {
    Write-Status -Level Info -Message 'git pull --ff-only'
    git -C $root pull --ff-only
    if ($LASTEXITCODE -ne 0) {
        Write-Status -Level Fail -Message "git pull failed (local changes or diverged history). Resolve it in $root, then re-run dot."
        exit 1
    }
} else {
    Write-Status -Level Skip -Message "$root isn't a git clone (zip install), so there's nothing to pull. Re-install with git to get updates."
}

$setDefaults = Join-Path $root 'windows\set-defaults.ps1'
if (Test-Path -Path $setDefaults) { & $setDefaults }

& (Join-Path $root 'script\bootstrap.ps1')
exit $LASTEXITCODE

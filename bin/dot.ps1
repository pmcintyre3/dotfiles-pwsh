#Requires -Version 7.4
<#
.SYNOPSIS
    dot: keep this machine current. Pulls the repo, then re-runs bootstrap (links + installers).
    Run it now and then. Credit: holman/dotfiles bin/dot, via haacked/dotfiles.
.EXAMPLE
    dot             # update everything (installs missing packages and extensions)
    dot -Upgrade    # same, and upgrade managed packages
    dot -Elevated   # machine-wide steps skipped for lack of admin (one UAC prompt)
    dot -ResetExplorerViews   # forget remembered folder views (backed up first) so defaults apply
    dot -e          # open the dotfiles in VS Code
#>
[CmdletBinding()]
param(
    [Alias('e')] [switch] $Edit,
    [switch] $Upgrade,
    [switch] $Elevated,
    [switch] $ResetExplorerViews
)

$root = Split-Path -Path $PSScriptRoot -Parent

if ($Edit) {
    if (Get-Command -Name code -ErrorAction Ignore) { code $root } else { Invoke-Item $root }
    return
}

Import-Module (Join-Path $root 'lib\DotfilesTools.psm1') -Force

if ($ResetExplorerViews) {
    try {
        & (Join-Path $root 'windows\reset-explorer-views.ps1')
        exit 0
    } catch {
        Write-Status -Level Fail -Message $_.Exception.Message
        exit 1
    }
}

if ($Elevated) {
    $log = Join-Path $root '.state\elevated.log'
    New-Item -ItemType Directory -Path (Split-Path -Path $log -Parent) -Force | Out-Null
    Remove-Item -Path $log -ErrorAction Ignore
    $elevatedScript = Join-Path $root 'script\elevated.ps1'
    Write-Status -Level Info -Message 'Running machine-wide steps elevated (approve the UAC prompt)...'
    try {
        $process = Start-Process -FilePath 'pwsh' -Verb RunAs -Wait -PassThru `
            -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$elevatedScript`" -LogPath `"$log`""
    } catch {
        Write-Status -Level Fail -Message "Elevated run didn't start: $($_.Exception.Message)"
        exit 1
    }
    if (Test-Path -Path $log) { Get-Content -Path $log | Out-Host }
    exit $process.ExitCode
}

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

& (Join-Path $root 'script\bootstrap.ps1') -Upgrade:$Upgrade
exit $LASTEXITCODE

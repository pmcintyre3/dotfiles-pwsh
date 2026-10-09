#Requires -Version 7.4
<#
.SYNOPSIS
    dot -ResetExplorerViews: forget remembered Explorer folder views so every folder picks up the defaults
    (e.g. Downloads not grouped by date). Backs up to .state\ first and deletes nothing if that fails;
    then re-applies the windows defaults (they live under Bags) and restarts Explorer.
    Also forgets per-folder view/sort tweaks and any "Apply to Folders" templates (all in the .reg backup).
    WinSetView (github.com/LesFerch/WinSetView) resets views the same way.
#>
[CmdletBinding()]
param(
    [string[]] $ViewKeys = @(
        'HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\Shell\BagMRU'
        'HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\Shell\Bags'
        'HKCU:\Software\Microsoft\Windows\Shell\BagMRU'
        'HKCU:\Software\Microsoft\Windows\Shell\Bags'
    ),
    [string] $BackupDir = (Join-Path (Split-Path -Path $PSScriptRoot -Parent) '.state'),
    [string] $InstallScript = (Join-Path $PSScriptRoot 'install.ps1'),
    [switch] $NoRestart
)

Import-Module (Join-Path $PSScriptRoot '..\lib\DotfilesTools.psm1')

$existing = @($ViewKeys | Where-Object { Test-Path -Path $_ })
if ($existing) {
    New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
    $stamp = Get-Date -Format yyyyMMddHHmmss
    $index = 0
    foreach ($key in $existing) {
        $index++
        $file = Join-Path $BackupDir "explorer-views-$stamp-$index.reg"
        reg export ($key -replace '^HKCU:\\', 'HKCU\') $file /y | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "Backing up $key failed (reg export exit $LASTEXITCODE); nothing was deleted." }
    }
    Write-Status -Level Success -Message "Backed up Explorer views to $(Join-Path $BackupDir "explorer-views-$stamp-*.reg")"
    foreach ($key in $existing) { Remove-Item -Path $key -Recurse -Force }
    Write-Status -Level Success -Message "Cleared remembered folder views ($($existing.Count) key(s))"
} else {
    Write-Status -Level Skip -Message 'No remembered folder views to clear'
}

& $InstallScript | Out-Host

if (-not $NoRestart) {
    Stop-Process -Name explorer -Force -ErrorAction Ignore
    Start-Sleep -Seconds 2
    if (-not (Get-Process -Name explorer -ErrorAction Ignore)) { Start-Process -FilePath 'explorer.exe' }
    Write-Status -Level Success -Message 'Restarted Explorer'
}

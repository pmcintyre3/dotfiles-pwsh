#Requires -Version 7.4
<#
.SYNOPSIS
    packages topic installer: install missing packages from the enabled groups (packages.psd1).
    Per-user winget first, then Scoop, then machine-wide only when allowed; -Upgrade also upgrades.
#>
[CmdletBinding()]
param(
    [string] $Root = (Split-Path -Path $PSScriptRoot -Parent),
    [string] $ManifestPath = (Join-Path $PSScriptRoot 'packages.psd1'),
    [switch] $Upgrade,
    [switch] $MachineOnly
)

Import-Module (Join-Path $PSScriptRoot '..\lib\DotfilesTools.psm1')
. (Join-Path $PSScriptRoot 'package-tools.ps1')

$config = Read-DotfilesConfig -Root $Root
$manifest = Import-PowerShellDataFile -Path $ManifestPath
# elevated.ps1 has already checked Elevation before running -MachineOnly.
$machineAllowed = (Test-IsAdmin) -and ($MachineOnly -or $config.Elevation -eq 'Auto')

$plan = @(Get-PackagePlan -Packages $manifest.Packages -Groups $config.PackageGroups -InstalledWinget (Get-InstalledWingetId))
$results = foreach ($item in $plan) {
    if ($item.Installed) {
        if ($Upgrade -and $item.Winget -and -not $MachineOnly) {
            Update-ManagedPackage -Package $item
        } else {
            [pscustomobject]@{ Name = $item.Name; Action = 'Present'; Via = $null; Reason = $null }
        }
        continue
    }
    Install-ManagedPackage -Package $item -MachineAllowed $machineAllowed -MachineOnly:$MachineOnly
}

foreach ($result in $results) {
    switch ($result.Action) {
        'Installed'  { Write-Status -Level Success -Message "$($result.Name) installed ($($result.Via))" }
        'Upgraded'   { Write-Status -Level Success -Message "$($result.Name) upgraded" }
        'NeedsAdmin' { Write-Status -Level Skip -Message "$($result.Name): $($result.Reason)" }
        'Skipped'    { Write-Status -Level Skip -Message "$($result.Name): $($result.Reason)" }
        'Failed'     { Write-Status -Level Fail -Message "$($result.Name): $($result.Reason)" }
    }
}

$count = { param($actions) @($results | Where-Object { $_.Action -in $actions }).Count }
Write-Status -Level Info -Message ("Packages ({0}): {1} already installed, {2} installed, {3} upgraded, {4} need admin, {5} failed" -f
    ($config.PackageGroups -join ', '), (& $count 'Present', 'UpToDate'), (& $count 'Installed'), (& $count 'Upgraded'),
    (& $count 'NeedsAdmin'), (& $count 'Failed'))

$failed = & $count 'Failed'
if ($failed) { throw "$failed package(s) failed" }

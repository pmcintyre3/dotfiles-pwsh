#Requires -Version 7.4
<#
.SYNOPSIS
    packages topic installer: install missing packages from the enabled groups (packages.psd1).
    Per-user winget first, then Scoop, then machine-wide only when allowed; -Upgrade also upgrades.
    Packages that need admin are recorded in .state\needs-admin-packages.json for `dot -Elevated`,
    whose -MachineOnly run installs exactly those (it may be another account, so it detects nothing itself).
#>
[CmdletBinding()]
param(
    [string] $Root = (Split-Path -Path $PSScriptRoot -Parent),
    [string] $ManifestPath = (Join-Path $PSScriptRoot 'packages.psd1'),
    [string] $StateDir = (Join-Path $Root '.state'),
    [switch] $Upgrade,
    [switch] $MachineOnly
)

Import-Module (Join-Path $PSScriptRoot '..\lib\DotfilesTools.psm1')
. (Join-Path $PSScriptRoot 'package-tools.ps1')

$config = Read-DotfilesConfig -Root $Root
$manifest = Import-PowerShellDataFile -Path $ManifestPath
# elevated.ps1 has already checked Elevation before running -MachineOnly.
$machineAllowed = (Test-IsAdmin) -and ($MachineOnly -or $config.Elevation -eq 'Auto')
$needsAdminPath = Join-Path $StateDir 'needs-admin-packages.json'

function Invoke-PackageStep {
    # One package's exception is that package's failure, never the end of the run.
    param([string] $Name, [scriptblock] $Step)
    try { & $Step } catch { [pscustomobject]@{ Name = $Name; Action = 'Failed'; Via = $null; Reason = $_.Exception.Message } }
}

function Save-NeedsAdmin {
    param([string[]] $Ids)
    New-Item -ItemType Directory -Path $StateDir -Force | Out-Null
    ConvertTo-Json -InputObject @($Ids | Where-Object { $_ }) | Set-Content -Path $needsAdminPath
}

if ($MachineOnly) {
    $pending = @()
    if (Test-Path -Path $needsAdminPath) { $pending = @(Get-Content -Path $needsAdminPath -Raw | ConvertFrom-Json) }
    $plan = @(Get-PackagePlan -Packages $manifest.Packages -Groups $config.PackageGroups -SkipDetection)
    $results = @(
        foreach ($item in ($plan | Where-Object { $_.Winget -and $_.Winget -in $pending })) {
            Invoke-PackageStep $item.Name { Install-ManagedPackage -Package $item -MachineAllowed $true -MachineOnly }
        }
        if ($Upgrade) {
            foreach ($item in ($plan | Where-Object { $_.Winget })) {
                Invoke-PackageStep $item.Name { Update-ManagedPackage -Package $item -Scope 'machine' }
            }
        }
    )
    $installedNames = @($results | Where-Object { $_.Action -eq 'Installed' } | ForEach-Object { $_.Name })
    Save-NeedsAdmin -Ids @($plan | Where-Object { $_.Winget -in $pending -and $_.Name -notin $installedNames } | ForEach-Object { $_.Winget })
    if (-not $pending -and -not $Upgrade) { Write-Status -Level Skip -Message 'No packages are waiting for admin' }
} else {
    $installedIds = Get-InstalledWingetId
    if (-not $installedIds.Ok) {
        Write-Status -Level Skip -Message "winget isn't usable here ($($installedIds.Reason)); skipped packages this run"
        return
    }
    $plan = @(Get-PackagePlan -Packages $manifest.Packages -Groups $config.PackageGroups -InstalledWinget $installedIds.Ids)
    $upgradeScope = if ($machineAllowed) { $null } else { 'user' }
    $results = @(
        foreach ($item in $plan) {
            if ($item.Installed) {
                if ($Upgrade) {
                    Invoke-PackageStep $item.Name { Update-ManagedPackage -Package $item -Scope $upgradeScope }
                } else {
                    [pscustomobject]@{ Name = $item.Name; Action = 'Present'; Via = $null; Reason = $null }
                }
                continue
            }
            Invoke-PackageStep $item.Name { Install-ManagedPackage -Package $item -MachineAllowed $machineAllowed }
        }
    )
    $needsAdminNames = @($results | Where-Object { $_.Action -eq 'NeedsAdmin' } | ForEach-Object { $_.Name })
    Save-NeedsAdmin -Ids @($plan | Where-Object { $_.Name -in $needsAdminNames } | ForEach-Object { $_.Winget })
}

foreach ($result in $results) {
    switch ($result.Action) {
        'Installed'  { Write-Status -Level Success -Message "$($result.Name) installed ($($result.Via))" }
        'Upgraded'   { Write-Status -Level Success -Message "$($result.Name) upgraded ($($result.Via))" }
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

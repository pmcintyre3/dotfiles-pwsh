# Package helpers for packages/install.ps1. The thin wrappers around winget/scoop/choco are separate
# functions so tests can mock them; nothing here runs at dot-source time.

$script:WingetNoApplicableInstaller = -1978335216   # APPINSTALLER_CLI_ERROR_NO_APPLICABLE_INSTALLER (e.g. no per-user installer)
$script:WingetUpdateNotApplicable = -1978335189     # APPINSTALLER_CLI_ERROR_UPDATE_NOT_APPLICABLE (already up to date)
$script:WingetNoInstalledPackage = -1978335212      # APPINSTALLER_CLI_ERROR_NO_APPLICATIONS_FOUND (not installed in that scope)

function Test-PackageManager {
    param([Parameter(Mandatory)] [string] $Name)
    [bool] (Get-Command -Name $Name -ErrorAction Ignore)
}

function Get-InstalledWingetId {
    # Package IDs winget can see as installed (any scope), via `winget export`.
    # Ok = $false means winget exists but couldn't list packages (e.g. blocked by policy): don't treat that as "nothing installed".
    if (-not (Test-PackageManager -Name 'winget')) { return [pscustomobject]@{ Ok = $true; Ids = @(); Reason = $null } }
    $export = Join-Path ([IO.Path]::GetTempPath()) "dotfiles-winget-$([guid]::NewGuid().ToString('N')).json"
    try {
        $code = Invoke-Winget -Quiet -Arguments @('export', '--output', $export, '--accept-source-agreements', '--disable-interactivity')
        if ($code -ne 0) { return [pscustomobject]@{ Ok = $false; Ids = @(); Reason = "winget export exited $code" } }
        if (-not (Test-Path -Path $export)) { return [pscustomobject]@{ Ok = $false; Ids = @(); Reason = 'winget export wrote no file' } }
        $json = Get-Content -Path $export -Raw | ConvertFrom-Json
        return [pscustomobject]@{ Ok = $true; Ids = @($json.Sources.Packages.PackageIdentifier); Reason = $null }
    } finally {
        Remove-Item -Path $export -ErrorAction Ignore
    }
}

function Test-ScoopPackageInstalled {
    param([Parameter(Mandatory)] [string] $Name)
    $scoopRoot = if ($env:SCOOP) { $env:SCOOP } else { Join-Path $HOME 'scoop' }
    Test-Path -Path (Join-Path $scoopRoot "apps\$Name\current")
}

function Invoke-Winget {
    param(
        [Parameter(Mandatory)] [string[]] $Arguments,
        [switch] $Quiet
    )
    if ($Quiet) { winget @Arguments 2>&1 | Out-Null } else { winget @Arguments | Out-Host }
    return $LASTEXITCODE
}

function Invoke-Scoop {
    param([Parameter(Mandatory)] [string[]] $Arguments)
    scoop @Arguments | Out-Host
}

function Install-Scoop {
    # Scoop's official per-user installer (https://scoop.sh); never run elevated.
    $installerPath = Join-Path ([IO.Path]::GetTempPath()) 'dotfiles-install-scoop.ps1'
    Invoke-RestMethod -Uri 'https://get.scoop.sh' -OutFile $installerPath
    try {
        & $installerPath | Out-Host
    } finally {
        Remove-Item -Path $installerPath -ErrorAction Ignore
    }
    $scoopShims = Join-Path $(if ($env:SCOOP) { $env:SCOOP } else { Join-Path $HOME 'scoop' }) 'shims'
    if (Test-Path -Path $scoopShims) { $env:PATH = "$scoopShims;$env:PATH" }
}

function Invoke-Choco {
    param([Parameter(Mandatory)] [string[]] $Arguments)
    choco @Arguments | Out-Host
    return $LASTEXITCODE
}

function Get-PackagePlan {
    param(
        [Parameter(Mandatory)] [hashtable[]] $Packages,
        [string[]] $Groups = @(),
        [string[]] $InstalledWinget = @(),
        # Elevated runs may be another account, whose view of "installed" is wrong for this user.
        [switch] $SkipDetection
    )
    foreach ($package in $Packages) {
        if ($package.Group -notin $Groups) { continue }
        $via = $null
        if (-not $SkipDetection) {
            if ($package.Winget -and $package.Winget -in $InstalledWinget) { $via = 'winget' }
            elseif ($package.Scoop -and (Test-ScoopPackageInstalled -Name $package.Scoop)) { $via = 'scoop' }
        }
        [pscustomobject]@{
            Name = $package.Name; Group = $package.Group
            Winget = $package.Winget; Scoop = $package.Scoop; Choco = $package.Choco
            Installed = [bool] $via; InstalledVia = $via
        }
    }
}

function New-PackageResult {
    param([string] $Name, [string] $Action, [string] $Via, [string] $Reason)
    [pscustomobject]@{ Name = $Name; Action = $Action; Via = $Via; Reason = $Reason }
}

function Install-ManagedPackage {
    param(
        [Parameter(Mandatory)] [pscustomobject] $Package,
        [Parameter(Mandatory)] [bool] $MachineAllowed,
        [switch] $MachineOnly
    )
    $common = '--exact', '--silent', '--accept-package-agreements', '--accept-source-agreements', '--disable-interactivity'
    $hasWinget = $Package.Winget -and (Test-PackageManager -Name 'winget')

    if (-not $MachineOnly) {
        if ($hasWinget) {
            $code = Invoke-Winget -Arguments (@('install', '--id', $Package.Winget, '--scope', 'user') + $common)
            if ($code -eq 0) { return New-PackageResult $Package.Name 'Installed' 'winget (user)' $null }
            if ($code -ne $script:WingetNoApplicableInstaller) {
                return New-PackageResult $Package.Name 'Failed' $null "winget exited $code"
            }
        }
        if ($Package.Scoop) {
            if (-not (Test-PackageManager -Name 'scoop')) {
                Install-Scoop
                if (-not (Test-PackageManager -Name 'scoop')) {
                    return New-PackageResult $Package.Name 'Failed' $null "Scoop isn't installed and couldn't be installed (see the output above)"
                }
            }
            Invoke-Scoop -Arguments @('install', $Package.Scoop)
            if (Test-ScoopPackageInstalled -Name $Package.Scoop) { return New-PackageResult $Package.Name 'Installed' 'scoop' $null }
            return New-PackageResult $Package.Name 'Failed' $null "scoop install $($Package.Scoop) didn't install it"
        }
    }

    if ($MachineAllowed) {
        if ($hasWinget) {
            $code = Invoke-Winget -Arguments (@('install', '--id', $Package.Winget, '--scope', 'machine') + $common)
            if ($code -eq 0) { return New-PackageResult $Package.Name 'Installed' 'winget (machine)' $null }
            return New-PackageResult $Package.Name 'Failed' $null "winget (machine) exited $code"
        }
        if ($Package.Choco -and (Test-PackageManager -Name 'choco')) {
            $code = Invoke-Choco -Arguments @('install', $Package.Choco, '-y', '--no-progress')
            if ($code -eq 0) { return New-PackageResult $Package.Name 'Installed' 'choco' $null }
            return New-PackageResult $Package.Name 'Failed' $null "choco exited $code"
        }
    } elseif ($hasWinget -or $Package.Choco) {
        return New-PackageResult $Package.Name 'NeedsAdmin' $null 'no per-user installer; run dot -Elevated'
    }

    return New-PackageResult $Package.Name 'Skipped' $null 'no available package manager can install it'
}

function Update-ManagedPackage {
    param(
        [Parameter(Mandatory)] [pscustomobject] $Package,
        # 'user' or 'machine' limits winget to installs of that scope (so no UAC prompts when machine changes aren't allowed).
        [string] $Scope
    )
    if ($Package.InstalledVia -eq 'scoop') {
        Invoke-Scoop -Arguments @('update', $Package.Scoop)
        return New-PackageResult $Package.Name 'Upgraded' 'scoop' $null
    }
    $arguments = @('upgrade', '--id', $Package.Winget, '--exact', '--silent',
        '--accept-package-agreements', '--accept-source-agreements', '--disable-interactivity')
    if ($Scope) { $arguments += '--scope', $Scope }
    $code = Invoke-Winget -Arguments $arguments
    if ($code -eq 0) { return New-PackageResult $Package.Name 'Upgraded' 'winget' $null }
    if ($code -in $script:WingetUpdateNotApplicable, $script:WingetNoInstalledPackage) { return New-PackageResult $Package.Name 'UpToDate' $null $null }
    return New-PackageResult $Package.Name 'Failed' $null "winget upgrade exited $code"
}

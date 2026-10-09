# dotfiles-pwsh one-line installer. Run from Windows PowerShell 5.1 or PowerShell 7, no admin needed:
#   irm https://raw.githubusercontent.com/pmcintyre3/dotfiles-pwsh/main/install.ps1 | iex
# Installs git and PowerShell 7 per-user if missing, clones to ~\.dotfiles, then runs script\bootstrap.ps1.
# Keep this file Windows PowerShell 5.1 compatible: no ??, ?:, &&, or ||.

$DotfilesRepoUrl = 'https://github.com/pmcintyre3/dotfiles-pwsh.git'
$DotfilesZipUrl = 'https://github.com/pmcintyre3/dotfiles-pwsh/archive/refs/heads/main.zip'
$DotfilesTarget = Join-Path $HOME '.dotfiles'

function Test-DotfilesCommand {
    param([string] $Name)
    [bool] (Get-Command -Name $Name -ErrorAction SilentlyContinue)
}

function Install-DotfilesGit {
    if (Test-DotfilesCommand 'git') { return $true }
    if (-not (Test-DotfilesCommand 'winget')) { return $false }

    Write-Host 'Installing Git for the current user...'
    winget install --id Git.Git --exact --scope user --silent --accept-package-agreements --accept-source-agreements
    $userGit = Join-Path $env:LOCALAPPDATA 'Programs\Git\cmd'
    if (Test-Path -Path $userGit) { $env:PATH = "$userGit;$env:PATH" }
    return (Test-DotfilesCommand 'git')
}

function Install-DotfilesPwsh {
    if (Test-DotfilesCommand 'pwsh') { return $true }
    if (-not (Test-DotfilesCommand 'winget')) { return $false }

    # The Microsoft Store package installs per-user, so no admin is needed.
    Write-Host 'Installing PowerShell 7 for the current user (Microsoft Store package)...'
    winget install --id 9MZ1SNWT0N5D --source msstore --accept-package-agreements --accept-source-agreements
    return (Test-DotfilesCommand 'pwsh')
}

function Get-DotfilesSource {
    if (Test-Path -Path (Join-Path $DotfilesTarget '.git')) {
        Write-Host "Updating the existing clone at $DotfilesTarget..."
        git -C $DotfilesTarget pull --ff-only
        if ($LASTEXITCODE -ne 0) { throw "git pull failed in $DotfilesTarget. Resolve it and re-run." }
        return
    }
    if (Test-Path -Path $DotfilesTarget) {
        throw "$DotfilesTarget exists but isn't a git clone. Move it aside and re-run."
    }

    if (Install-DotfilesGit) {
        git clone $DotfilesRepoUrl $DotfilesTarget
        if ($LASTEXITCODE -ne 0) { throw 'git clone failed.' }
        return
    }

    Write-Warning "git isn't available and couldn't be installed, so downloading a zip instead. 'dot' can't update a zip copy."
    $zip = Join-Path ([IO.Path]::GetTempPath()) 'dotfiles-pwsh.zip'
    $extract = Join-Path ([IO.Path]::GetTempPath()) 'dotfiles-pwsh-extract'
    Remove-Item -Path $extract -Recurse -Force -ErrorAction SilentlyContinue
    Invoke-WebRequest -Uri $DotfilesZipUrl -OutFile $zip -UseBasicParsing
    Expand-Archive -Path $zip -DestinationPath $extract -Force
    New-Item -ItemType Directory -Path (Split-Path -Path $DotfilesTarget -Parent) -Force | Out-Null
    Move-Item -Path (Join-Path $extract 'dotfiles-pwsh-main') -Destination $DotfilesTarget
    Remove-Item -Path $zip, $extract -Recurse -Force -ErrorAction SilentlyContinue
}

function Install-Dotfiles {
    $ErrorActionPreference = 'Stop'
    if (-not (Install-DotfilesPwsh)) {
        throw 'PowerShell 7 is required. Install it from https://aka.ms/powershell and re-run.'
    }
    Get-DotfilesSource
    & pwsh -NoProfile -ExecutionPolicy Bypass -File (Join-Path $DotfilesTarget 'script\bootstrap.ps1')
}

if ($env:DOTFILES_INSTALL_NOEXEC -ne '1') { Install-Dotfiles }

function Test-IsAdmin {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    ([Security.Principal.WindowsPrincipal] $identity).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Test-CanSymlink {
    # Private. Actually creates a symlink in %TEMP%; that's the only reliable answer
    # (admin, Developer Mode, and policy all interact).
    $dir = Join-Path ([IO.Path]::GetTempPath()) "dotfiles-symlink-probe-$([guid]::NewGuid().ToString('N'))"
    New-Item -ItemType Directory -Path $dir | Out-Null
    try {
        $target = Join-Path $dir 'target.txt'
        Set-Content -Path $target -Value 'probe'
        New-Item -ItemType SymbolicLink -Path (Join-Path $dir 'link.txt') -Target $target -ErrorAction Stop | Out-Null
        return $true
    } catch {
        return $false
    } finally {
        Remove-Item -Path $dir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Test-UrlReachable {
    # Private.
    param([Parameter(Mandatory)] [string] $Uri)

    try {
        Invoke-WebRequest -Uri $Uri -Method Head -TimeoutSec 5 -UseBasicParsing -ErrorAction Stop | Out-Null
        return $true
    } catch {
        return $false
    }
}

function Get-MachineCapability {
    <#
    .SYNOPSIS
        What this machine allows; bootstrap and installers choose strategies from it. See design.md section 7.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param([switch] $SkipNetwork)

    $devModeKey = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock'
    $devMode = (Get-ItemProperty -Path $devModeKey -Name AllowDevelopmentWithoutDevLicense -ErrorAction Ignore).AllowDevelopmentWithoutDevLicense -eq 1

    $gpoPolicy = Get-ExecutionPolicy -List |
        Where-Object { $_.Scope -in 'MachinePolicy', 'UserPolicy' -and $_.ExecutionPolicy -ne 'Undefined' } |
        Select-Object -First 1

    [pscustomobject]@{
        IsAdmin            = Test-IsAdmin
        CanSymlink         = Test-CanSymlink
        DeveloperMode      = [bool] $devMode
        ExecutionPolicy    = [string] (Get-ExecutionPolicy)
        PolicyFromGpo      = [bool] $gpoPolicy
        LanguageMode       = [string] $ExecutionContext.SessionState.LanguageMode
        Winget             = [bool] (Get-Command -Name winget -ErrorAction Ignore)
        Scoop              = [bool] (Get-Command -Name scoop -ErrorAction Ignore)
        Choco              = [bool] (Get-Command -Name choco -ErrorAction Ignore)
        Op                 = [bool] (Get-Command -Name op -ErrorAction Ignore)
        GitHubReachable    = if ($SkipNetwork) { $false } else { Test-UrlReachable -Uri 'https://github.com' }
        PSGalleryReachable = if ($SkipNetwork) { $false } else { Test-UrlReachable -Uri 'https://www.powershellgallery.com/api/v2' }
    }
}

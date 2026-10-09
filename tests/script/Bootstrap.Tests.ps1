BeforeAll {
    . (Join-Path $PSScriptRoot '..\TestHelpers.ps1')
}

Describe 'script/bootstrap.ps1' {
    BeforeAll {
        $repo = Copy-DotfilesRepo -Destination (Join-Path $TestDrive 'repo')
        $profilePath = Join-Path $TestDrive 'Documents\PowerShell\Microsoft.PowerShell_profile.ps1'
        New-Item -ItemType Directory -Path (Split-Path $profilePath) -Force | Out-Null
        Set-Content -Path $profilePath -Value '# old profile'
        $bootstrapArgs = @{
            SkipInstall    = $true
            SkipNetwork    = $true
            ConflictAction = 'Skip'
            TokenMap       = @{ '{PROFILE}' = $profilePath; '~' = (Join-Path $TestDrive 'home') }
        }
        & (Join-Path $repo 'script\bootstrap.ps1') @bootstrapArgs *> $null
        $firstExit = $LASTEXITCODE
    }

    It 'exits 0' {
        $firstExit | Should -Be 0
    }

    It 'writes the $PROFILE stub' {
        Get-Content -Path $profilePath -Raw | Should -Match 'Managed by dotfiles-pwsh'
    }

    It 'backs up the previous profile even though ConflictAction is Skip (OnConflict = Backup)' {
        $backup = @(Get-ChildItem -Path (Split-Path $profilePath) -Filter '*.backup-*')
        $backup | Should -HaveCount 1
        Get-Content -Path $backup[0].FullName | Should -Be '# old profile'
    }

    It 'creates local files from templates' {
        Join-Path $repo 'dotfiles.local.psd1' | Should -Exist
        Join-Path $repo 'powershell\profile.local.ps1' | Should -Exist
    }

    It 'is idempotent and preserves local edits' {
        Add-Content -Path (Join-Path $repo 'powershell\profile.local.ps1') -Value '# my edit'
        & (Join-Path $repo 'script\bootstrap.ps1') @bootstrapArgs *> $null
        $LASTEXITCODE | Should -Be 0
        Get-ChildItem -Path (Split-Path $profilePath) -Filter '*.backup-*' | Should -HaveCount 1
        Get-Content -Path (Join-Path $repo 'powershell\profile.local.ps1') -Raw | Should -Match '# my edit'
    }
}

Describe 'the $PROFILE stub' {
    BeforeAll {
        $repo = Copy-DotfilesRepo -Destination (Join-Path $TestDrive 'stub\repo')
        $stub = (Import-PowerShellDataFile -Path (Join-Path $repo 'powershell\links.psd1')).Links[0].Template
        $profileDir = Join-Path $TestDrive 'stub\Documents\PowerShell'
        New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
        $stubPath = Join-Path $profileDir 'Microsoft.PowerShell_profile.ps1'
        Set-Content -Path $stubPath -Value $stub
        Set-Content -Path (Join-Path $profileDir 'Microsoft.PowerShell_profile.legacy.ps1') -Value 'function Test-LegacyLoaded { }'

        function Invoke-Stub {
            param([string] $DotfilesRoot)
            $command = "`$env:DOTFILES_ROOT = '$DotfilesRoot'; . '$stubPath'; " +
                "[bool] (Get-Command Test-LegacyLoaded -ErrorAction Ignore), [bool] (Get-Variable DotfilesRoot -Scope Global -ErrorAction Ignore)"
            pwsh -NoProfile -NonInteractive -Command $command 2>$null | Select-Object -Last 2
        }
    }

    It 'loads the dotfiles profile when the clone exists' {
        $legacy, $dotfiles = Invoke-Stub -DotfilesRoot $repo
        $legacy | Should -Be 'False'
        $dotfiles | Should -Be 'True'
    }

    It 'falls back to the legacy profile when this machine has no clone (e.g. Ryuujin before Phase 5)' {
        $legacy, $dotfiles = Invoke-Stub -DotfilesRoot (Join-Path $TestDrive 'no-clone-here')
        $legacy | Should -Be 'True'
        $dotfiles | Should -Be 'False'
    }
}

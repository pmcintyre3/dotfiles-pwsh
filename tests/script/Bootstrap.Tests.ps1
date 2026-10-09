BeforeAll {
    . (Join-Path $PSScriptRoot '..\TestHelpers.ps1')
    # Bootstrap runs git/local.ps1, which prompts for a missing identity on an interactive console.
    # Import first: Mock needs the command to exist, and this file may run before any other imports it.
    Import-Module (Join-Path $PSScriptRoot '..\..\lib\DotfilesTools.psm1') -Force
    Mock Test-CanPrompt { $false }
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
            TokenMap       = @{ '{PROFILE}' = $profilePath; '~' = (Join-Path $TestDrive 'home'); '{LOCALAPPDATA}' = (Join-Path $TestDrive 'localappdata') }
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

    It 'seeds Microsoft.PowerShell_profile.legacy.ps1 from the backed-up profile (keeps unmigrated OneDrive machines working)' {
        $legacy = Join-Path (Split-Path $profilePath) 'Microsoft.PowerShell_profile.legacy.ps1'
        $legacy | Should -Exist
        Get-Content -Path $legacy | Should -Be '# old profile'
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

    It 'never overwrites an existing legacy profile' {
        $dir = Join-Path $TestDrive 'existing-legacy'
        $otherProfile = Join-Path $dir 'Microsoft.PowerShell_profile.ps1'
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        Set-Content -Path $otherProfile -Value '# newer profile'
        Set-Content -Path (Join-Path $dir 'Microsoft.PowerShell_profile.legacy.ps1') -Value '# hand-made legacy'
        $args2 = $bootstrapArgs.Clone()
        $args2.TokenMap = @{ '{PROFILE}' = $otherProfile; '~' = (Join-Path $TestDrive 'home'); '{LOCALAPPDATA}' = (Join-Path $TestDrive 'localappdata') }
        & (Join-Path $repo 'script\bootstrap.ps1') @args2 *> $null
        Get-Content -Path (Join-Path $dir 'Microsoft.PowerShell_profile.legacy.ps1') | Should -Be '# hand-made legacy'
    }

    It 'skips Windows Terminal when it is not installed, without creating its folder' {
        Join-Path $TestDrive 'localappdata\Packages' | Should -Not -Exist
    }

    It 'turns ~/.gitconfig into an include of the repo config, seeded into gitconfig.local' {
        $gitconfigStub = Join-Path $TestDrive 'home\.gitconfig'
        Get-Content -Path $gitconfigStub -Raw | Should -Match 'path = ~/.dotfiles/git/gitconfig'
        Join-Path $repo 'git\gitconfig.local' | Should -Exist
    }

    It 'does not silently replace a ~/.gitconfig that tools have written to' {
        $gitconfigStub = Join-Path $TestDrive 'home\.gitconfig'
        Add-Content -Path $gitconfigStub -Value "[credential]`n    helper = manager"
        & (Join-Path $repo 'script\bootstrap.ps1') @bootstrapArgs *> $null
        Get-Content -Path $gitconfigStub -Raw | Should -Match 'helper = manager'
    }
}

Describe 'bootstrap with excluded topics' {
    It 'does not create local files for excluded topics' {
        $repo = Copy-DotfilesRepo -Destination (Join-Path $TestDrive 'excl\repo')
        New-Item -ItemType Directory -Path (Join-Path $repo 'demo') | Out-Null
        Set-Content -Path (Join-Path $repo 'demo\demo.local.ps1.template') -Value '# demo'
        Set-Content -Path (Join-Path $repo 'dotfiles.local.psd1') -Value "@{ ExcludeTopics = 'demo' }"
        $profilePath = Join-Path $TestDrive 'excl\Documents\PowerShell\Microsoft.PowerShell_profile.ps1'
        & (Join-Path $repo 'script\bootstrap.ps1') -SkipInstall -SkipNetwork -ConflictAction Skip `
            -TokenMap @{ '{PROFILE}' = $profilePath; '~' = (Join-Path $TestDrive 'excl\home'); '{LOCALAPPDATA}' = (Join-Path $TestDrive 'localappdata') } *> $null
        Join-Path $repo 'demo\demo.local.ps1' | Should -Not -Exist
        Join-Path $repo 'powershell\profile.local.ps1' | Should -Exist
    }
}

Describe 'bootstrap local.ps1 hooks' {
    BeforeEach {
        $repo = Copy-DotfilesRepo -Destination (Join-Path $TestDrive ([guid]::NewGuid()))
        New-Item -ItemType Directory -Path (Join-Path $repo 'demo') | Out-Null
        Set-Content -Path (Join-Path $repo 'demo\demo.local.ps1.template') -Value '# from template'
        $profilePath = Join-Path $TestDrive "$([guid]::NewGuid())\Microsoft.PowerShell_profile.ps1"
        $hookArgs = @{ SkipInstall = $true; SkipNetwork = $true; ConflictAction = 'Skip'
            TokenMap = @{ '{PROFILE}' = $profilePath; '~' = (Join-Path $TestDrive 'hooks-home'); '{LOCALAPPDATA}' = (Join-Path $TestDrive 'localappdata') } }
    }

    It 'runs a topic local.ps1 (with the TokenMap) instead of copying its templates' {
        Set-Content -Path (Join-Path $repo 'demo\local.ps1') -Value @'
param([hashtable] $TokenMap)
Set-Content -Path (Join-Path $PSScriptRoot 'hook-ran.txt') -Value $TokenMap['~']
'@
        & (Join-Path $repo 'script\bootstrap.ps1') @hookArgs *> $null
        $LASTEXITCODE | Should -Be 0
        Get-Content -Path (Join-Path $repo 'demo\hook-ran.txt') | Should -Be (Join-Path $TestDrive 'hooks-home')
        Join-Path $repo 'demo\demo.local.ps1' | Should -Not -Exist
    }

    It 'reports a failing hook, still links, and exits 1' {
        Set-Content -Path (Join-Path $repo 'demo\local.ps1') -Value 'param([hashtable] $TokenMap) throw "hook broke"'
        & (Join-Path $repo 'script\bootstrap.ps1') @hookArgs *> $null
        $LASTEXITCODE | Should -Be 1
        Get-Content -Path $profilePath -Raw | Should -Match 'Managed by dotfiles-pwsh'
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

    It 'warns instead of silently loading nothing when there is no clone and no legacy profile' {
        $bareDir = Join-Path $TestDrive 'bare\Documents\PowerShell'
        New-Item -ItemType Directory -Path $bareDir -Force | Out-Null
        $bareStub = Join-Path $bareDir 'Microsoft.PowerShell_profile.ps1'
        Set-Content -Path $bareStub -Value $stub
        $command = "`$env:DOTFILES_ROOT = '$(Join-Path $TestDrive 'no-clone-here')'; . '$bareStub'"
        $output = pwsh -NoProfile -NonInteractive -Command $command *>&1 | ForEach-Object { "$_" }
        ($output -join "`n") | Should -Match 'dotfiles: no clone'
    }
}

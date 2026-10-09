BeforeAll {
    $installerPath = Join-Path $PSScriptRoot '..\install.ps1'
    $env:DOTFILES_INSTALL_NOEXEC = '1'
    . $installerPath
}

AfterAll {
    Remove-Item -Path Env:DOTFILES_INSTALL_NOEXEC -ErrorAction Ignore
}

Describe 'install.ps1 (one-liner)' {
    It 'parses under Windows PowerShell 5.1' {
        $resolved = (Resolve-Path $installerPath).Path
        $command = "`$e = `$null; [void] [System.Management.Automation.Language.Parser]::ParseFile('$resolved', [ref] `$null, [ref] `$e); `$e.Count"
        powershell.exe -NoProfile -NonInteractive -Command $command | Should -Be '0'
    }

    It 'pulls an existing clone instead of re-cloning' {
        $DotfilesTarget = Join-Path $TestDrive 'existing\.dotfiles'
        New-Item -ItemType Directory -Path (Join-Path $DotfilesTarget '.git') -Force | Out-Null
        Mock git { $global:LASTEXITCODE = 0 }
        Get-DotfilesSource 6> $null
        Should -Invoke git -Times 1 -Exactly -ParameterFilter { $args -contains 'pull' }
        Should -Invoke git -Times 0 -Exactly -ParameterFilter { $args -contains 'clone' }
    }

    It "refuses to overwrite a folder that isn't a git clone" {
        $DotfilesTarget = Join-Path $TestDrive 'plain\.dotfiles'
        New-Item -ItemType Directory -Path $DotfilesTarget -Force | Out-Null
        { Get-DotfilesSource } | Should -Throw "*isn't a git clone*"
    }

    It 'clones when git is available' {
        $DotfilesTarget = Join-Path $TestDrive 'fresh\.dotfiles'
        Mock Install-DotfilesGit { $true }
        Mock git { $global:LASTEXITCODE = 0 }
        Get-DotfilesSource 6> $null
        Should -Invoke git -Times 1 -Exactly -ParameterFilter { $args -contains 'clone' -and $args -contains $DotfilesRepoUrl }
    }

    It 'falls back to the zip download when git is unavailable' {
        $DotfilesTarget = Join-Path $TestDrive 'zip\.dotfiles'
        Mock Install-DotfilesGit { $false }
        Mock Invoke-WebRequest { }
        Mock Expand-Archive { New-Item -ItemType Directory -Path (Join-Path $DestinationPath 'dotfiles-pwsh-main') -Force | Out-Null }
        Get-DotfilesSource 3> $null 6> $null
        $DotfilesTarget | Should -Exist
        Should -Invoke Invoke-WebRequest -Times 1 -Exactly -ParameterFilter { $Uri -eq $DotfilesZipUrl }
    }
}

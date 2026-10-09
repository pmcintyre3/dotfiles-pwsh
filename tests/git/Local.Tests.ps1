BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..\..\lib\DotfilesTools.psm1') -Force
    $hook = Join-Path $PSScriptRoot '..\..\git\local.ps1'
    function New-TestDir { (New-Item -ItemType Directory -Path (Join-Path $TestDrive ([guid]::NewGuid()))).FullName }
    function Get-LocalValue { param([string] $Path, [string] $Key) git config --file $Path --get $Key }
}

Describe 'git/local.ps1' {
    BeforeEach {
        $home2 = New-TestDir
        $local = Join-Path (New-TestDir) 'gitconfig.local'
        $current = Join-Path $home2 '.gitconfig'
    }

    It 'seeds identity and signing from the current ~/.gitconfig' {
        git config --file $current user.name 'Test User'
        git config --file $current user.email 'test@example.com'
        git config --file $current user.signingkey 'ssh-ed25519 AAAATEST'
        git config --file $current gpg.format ssh
        git config --file $current gpg.ssh.program 'C:/Tools/op-ssh-sign.exe'
        git config --file $current commit.gpgsign true

        & $hook -TokenMap @{ '~' = $home2 } -LocalPath $local 6> $null

        Get-LocalValue $local user.name | Should -Be 'Test User'
        Get-LocalValue $local user.email | Should -Be 'test@example.com'
        Get-LocalValue $local user.signingkey | Should -Be 'ssh-ed25519 AAAATEST'
        Get-LocalValue $local gpg.format | Should -Be 'ssh'
        Get-LocalValue $local gpg.ssh.program | Should -Be 'C:/Tools/op-ssh-sign.exe'
        Get-LocalValue $local commit.gpgsign | Should -Be 'true'
    }

    It 'keeps non-ASCII names intact whatever the console encoding' {
        git config --file $current user.name 'José Müller'
        $saved = [Console]::OutputEncoding
        try {
            [Console]::OutputEncoding = [Text.Encoding]::GetEncoding(437)   # default under pwsh -NoProfile, Task Scheduler
            & $hook -TokenMap @{ '~' = $home2 } -LocalPath $local 6> $null
        } finally {
            [Console]::OutputEncoding = $saved
        }
        [IO.File]::ReadAllText($local, [Text.UTF8Encoding]::new($false)) | Should -Match 'name = José Müller'
    }

    It 'never overwrites an existing gitconfig.local' {
        git config --file $current user.name 'From Current'
        git config --file $local user.name 'Mine'
        & $hook -TokenMap @{ '~' = $home2 } -LocalPath $local 6> $null
        Get-LocalValue $local user.name | Should -Be 'Mine'
    }

    It 'prompts for a missing name and email when interactive' {
        Mock Test-CanPrompt { $true }
        Mock Read-Host { if ($Prompt -match 'name') { 'Prompted Name' } else { 'prompted@example.com' } }
        & $hook -TokenMap @{ '~' = $home2 } -LocalPath $local 6> $null
        Get-LocalValue $local user.name | Should -Be 'Prompted Name'
        Get-LocalValue $local user.email | Should -Be 'prompted@example.com'
    }

    It 'creates gitconfig.local without identity in a non-interactive session' {
        Mock Test-CanPrompt { $false }
        Mock Read-Host { throw 'should not prompt' }
        & $hook -TokenMap @{ '~' = $home2 } -LocalPath $local 6> $null
        $local | Should -Exist
        Get-LocalValue $local user.name | Should -BeNullOrEmpty
    }
}

Describe 'git/gitconfig' {
    It 'includes gitconfig.local last, so machine values win' {
        $gitconfig = Join-Path $PSScriptRoot '..\..\git\gitconfig'
        (git config --file $gitconfig --get-all include.path | Select-Object -Last 1) | Should -Be 'gitconfig.local'
        $lines = Get-Content -Path $gitconfig | Where-Object { $_ -match '^\s*\[' }
        $lines[-1] | Should -Match '^\[include\]'
    }
}

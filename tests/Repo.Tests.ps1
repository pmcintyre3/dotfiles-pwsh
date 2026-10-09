BeforeAll {
    $root = Split-Path -Path $PSScriptRoot -Parent
}

Describe '.gitignore' {
    It 'ignores <Path>' -ForEach @(
        @{ Path = 'dotfiles.local.psd1' }
        @{ Path = 'powershell/profile.local.ps1' }
        @{ Path = 'git/gitconfig.local' }
        @{ Path = 'ssh/config.backup-20260101000000' }
    ) {
        git -C $root check-ignore -q $Path
        $LASTEXITCODE | Should -Be 0
    }

    It 'does not ignore templates' {
        git -C $root check-ignore -q 'powershell/profile.local.ps1.template'
        $LASTEXITCODE | Should -Be 1
    }
}

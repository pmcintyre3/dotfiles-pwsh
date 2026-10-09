BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..\..\lib\DotfilesTools.psm1') -Force
    function New-TestDir { (New-Item -ItemType Directory -Path (Join-Path $TestDrive ([guid]::NewGuid()))).FullName }
}

Describe 'Get-DotfilesRoot' {
    It 'returns the repo root' {
        Get-DotfilesRoot | Should -Be (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
    }
}

Describe 'Resolve-DotPath' {
    It 'expands ~ to the home directory' {
        Resolve-DotPath -Path '~\.gitconfig' | Should -Be (Join-Path $HOME '.gitconfig')
    }
    It 'expands {PROFILE} to the console (Microsoft.PowerShell) profile' {
        Resolve-DotPath -Path '{PROFILE}' |
            Should -Be (Join-Path (Split-Path $PROFILE.CurrentUserAllHosts) 'Microsoft.PowerShell_profile.ps1')
    }
    It 'pins {PROFILE} to the console profile even when run from another host (e.g. VS Code)' {
        $saved = $global:PROFILE
        try {
            $global:PROFILE = 'C:\Docs\PowerShell\Microsoft.VSCode_profile.ps1' |
                Add-Member -NotePropertyName CurrentUserCurrentHost -NotePropertyValue 'C:\Docs\PowerShell\Microsoft.VSCode_profile.ps1' -PassThru |
                Add-Member -NotePropertyName CurrentUserAllHosts -NotePropertyValue 'C:\Docs\PowerShell\profile.ps1' -PassThru
            Resolve-DotPath -Path '{PROFILE}' | Should -Be 'C:\Docs\PowerShell\Microsoft.PowerShell_profile.ps1'
        } finally {
            $global:PROFILE = $saved
        }
    }
    It 'applies TokenMap overrides' {
        Resolve-DotPath -Path '{PROFILE}' -TokenMap @{ '{PROFILE}' = 'X:\p.ps1' } | Should -Be 'X:\p.ps1'
        Resolve-DotPath -Path '~\a\b' -TokenMap @{ '~' = 'X:\home' } | Should -Be 'X:\home\a\b'
    }
    It 'leaves absolute paths alone' {
        Resolve-DotPath -Path 'C:\x\y' | Should -Be 'C:\x\y'
    }
}

Describe 'Read-DotfilesConfig' {
    It 'returns defaults when there is no local file' {
        $config = Read-DotfilesConfig -Root (New-TestDir)
        $config.ExcludeTopics | Should -BeNullOrEmpty
        $config.Elevation | Should -Be 'Never'
        $config.PSRepository | Should -Be 'PSGallery'
    }
    It 'merges values from dotfiles.local.psd1' {
        $root = New-TestDir
        Set-Content -Path (Join-Path $root 'dotfiles.local.psd1') -Value "@{ ExcludeTopics = 'ai'; PSRepository = 'Internal' }"
        $config = Read-DotfilesConfig -Root $root
        $config.ExcludeTopics | Should -Be 'ai'
        $config.PSRepository | Should -Be 'Internal'
        $config.Elevation | Should -Be 'Never'
    }
    It 'names the file when it is malformed' {
        $root = New-TestDir
        Set-Content -Path (Join-Path $root 'dotfiles.local.psd1') -Value '@{ ExcludeTopics = '
        { Read-DotfilesConfig -Root $root } | Should -Throw '*dotfiles.local.psd1*'
    }
    It 'rejects an unknown Elevation value' {
        $root = New-TestDir
        Set-Content -Path (Join-Path $root 'dotfiles.local.psd1') -Value "@{ Elevation = 'Sometimes' }"
        { Read-DotfilesConfig -Root $root } | Should -Throw '*Elevation*'
    }
}

Describe 'Get-DotfilesTopic' {
    BeforeAll {
        $root = New-TestDir
        foreach ($name in 'powershell', 'git', 'ai', 'script', 'lib', 'bin', 'tests', '.github') {
            New-Item -ItemType Directory -Path (Join-Path $root $name) | Out-Null
        }
        New-Item -ItemType File -Path (Join-Path $root 'install.ps1') | Out-Null
    }
    It 'returns only topic folders, sorted' {
        (Get-DotfilesTopic -Root $root).Name | Should -Be @('ai', 'git', 'powershell')
    }
    It 'skips excluded topics' {
        (Get-DotfilesTopic -Root $root -ExcludeTopics 'ai').Name | Should -Be @('git', 'powershell')
    }
}

Describe 'Get-DotfilesProfileScript' {
    BeforeAll {
        $root = New-TestDir
        $files = @(
            'powershell\profile.ps1'
            'powershell\profile.local.ps1'
            'powershell\env.ps1'
            'powershell\path.ps1'
            'powershell\aliases.ps1'
            'powershell\completion.ps1'
            'powershell\install.ps1'
            'powershell\functions\b.ps1'
            'powershell\functions\a.ps1'
            'powershell\functions\a.Tests.ps1'
            'git\aliases.ps1'
            'git\functions\git.ps1'
            'tools\env.ps1'
            'tools\path.ps1'
            'ai\env.ps1'
        )
        foreach ($file in $files) { New-Item -ItemType File -Path (Join-Path $root $file) -Force | Out-Null }
        function Get-Relative { param($Items) $Items | ForEach-Object { $_.FullName.Substring($root.Length + 1) } }
    }
    It 'orders local, env, path, functions, aliases, completion' {
        Get-Relative (Get-DotfilesProfileScript -Root $root -ExcludeTopics 'ai') | Should -Be @(
            'powershell\profile.local.ps1'
            'powershell\env.ps1'
            'tools\env.ps1'
            'powershell\path.ps1'
            'tools\path.ps1'
            'git\functions\git.ps1'
            'powershell\functions\a.ps1'
            'powershell\functions\b.ps1'
            'git\aliases.ps1'
            'powershell\aliases.ps1'
            'powershell\completion.ps1'
        )
    }
    It 'includes topics that are not excluded' {
        Get-Relative (Get-DotfilesProfileScript -Root $root) | Should -Contain 'ai\env.ps1'
    }
}

Describe 'Add-PathEntry' {
    BeforeEach {
        $savedPath = $env:PATH
        $dir = New-TestDir
        $env:PATH = 'C:\Windows'
    }
    AfterEach { $env:PATH = $savedPath }

    It 'prepends an existing folder' {
        Add-PathEntry -Path $dir
        ($env:PATH -split ';')[0] | Should -Be $dir
    }
    It 'appends with -Append' {
        Add-PathEntry -Path $dir -Append
        ($env:PATH -split ';')[-1] | Should -Be $dir
    }
    It 'ignores case and trailing slashes when checking for duplicates' {
        Add-PathEntry -Path $dir
        Add-PathEntry -Path ($dir.ToUpper() + '\')
        @($env:PATH -split ';').Count | Should -Be 2
    }
    It 'ignores folders that do not exist' {
        Add-PathEntry -Path 'Z:\does-not-exist'
        $env:PATH | Should -Be 'C:\Windows'
    }
}

Describe 'New-LocalFileFromTemplate' {
    It 'creates the local file when it is missing' {
        $dir = New-TestDir
        $template = Join-Path $dir 'a.local.ps1.template'
        Set-Content -Path $template -Value 'template'
        New-LocalFileFromTemplate -TemplatePath $template | Should -BeTrue
        Get-Content (Join-Path $dir 'a.local.ps1') | Should -Be 'template'
    }
    It 'never overwrites an existing local file' {
        $dir = New-TestDir
        $template = Join-Path $dir 'b.local.ps1.template'
        Set-Content -Path $template -Value 'template'
        Set-Content -Path (Join-Path $dir 'b.local.ps1') -Value 'mine'
        New-LocalFileFromTemplate -TemplatePath $template | Should -BeFalse
        Get-Content (Join-Path $dir 'b.local.ps1') | Should -Be 'mine'
    }
    It 'rejects files that are not templates' {
        { New-LocalFileFromTemplate -TemplatePath 'C:\x.ps1' } | Should -Throw '*.template*'
    }
}

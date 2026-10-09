BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..\..\lib\DotfilesTools.psm1') -Force
    $installer = Join-Path $PSScriptRoot '..\..\ai\install.ps1'
    $repoSettings = Join-Path $PSScriptRoot '..\..\ai\claude\settings.json'
}

Describe 'ai/install.ps1' {
    BeforeEach {
        $root = Join-Path $TestDrive ([guid]::NewGuid())
        $claudeDir = Join-Path $root 'home\.claude'
        $settings = Join-Path $claudeDir 'settings.json'
    }

    It 'skips when Claude Code is not set up (no ~/.claude), creating nothing' {
        & $installer -Root $root -SettingsPath $settings 6> $null
        $claudeDir | Should -Not -Exist
    }

    It 'merges the managed settings and keeps what Claude Code wrote' {
        New-Item -ItemType Directory -Path $claudeDir -Force | Out-Null
        Set-Content -Path $settings -Value '{ "model": "opus", "enabledPlugins": { "local@m": true } }'
        & $installer -Root $root -SettingsPath $settings 6> $null
        $merged = Get-Content -Path $settings -Raw | ConvertFrom-Json -AsHashtable
        $merged.model | Should -Be 'opus'
        $merged.enabledPlugins['local@m'] | Should -BeTrue
        $merged.enabledPlugins['superpowers@claude-plugins-official'] | Should -BeTrue
        Get-ChildItem -Path (Join-Path $root '.state') -Filter 'settings.json.backup-*' | Should -HaveCount 1
    }

    It 'names the managed keys it put back (e.g. a plugin disabled in the UI)' {
        New-Item -ItemType Directory -Path $claudeDir -Force | Out-Null
        $live = Get-Content -Path $repoSettings -Raw | ConvertFrom-Json -AsHashtable
        $live.enabledPlugins['superpowers@claude-plugins-official'] = $false
        $live | ConvertTo-Json -Depth 10 | Set-Content -Path $settings
        $output = & $installer -Root $root -SettingsPath $settings 6>&1 | Out-String
        $output | Should -Match ([regex]::Escape('enabledPlugins.superpowers@claude-plugins-official'))
    }

    It 'throws, leaving the file alone, when it is not valid JSON' {
        New-Item -ItemType Directory -Path $claudeDir -Force | Out-Null
        Set-Content -Path $settings -Value '{ broken'
        { & $installer -Root $root -SettingsPath $settings 6> $null } | Should -Throw '*left alone*'
        Get-Content -Path $settings -Raw | Should -Match '\{ broken'
    }
}

Describe 'ai/claude/settings.json' {
    It 'holds no credentials or env' {
        $json = Get-Content -Path $repoSettings -Raw
        $parsed = $json | ConvertFrom-Json -AsHashtable
        $parsed.Keys | Should -Not -Contain 'env'
        $parsed.Keys | Should -Not -Contain 'apiKeyHelper'
        $json | Should -Not -Match '(?i)token|secret|password|sk-ant-'
        $parsed.enabledPlugins.Count | Should -BeGreaterThan 0
    }
}

Describe 'ai/links.psd1' {
    It 'links a global CLAUDE.md only once one exists in the repo, and only where Claude Code is set up' {
        $entry = (Import-PowerShellDataFile -Path (Join-Path $PSScriptRoot '..\..\ai\links.psd1')).Links | Select-Object -First 1
        $entry.Source | Should -Be 'claude\CLAUDE.md'
        $entry.Target | Should -Be '~\.claude\CLAUDE.md'
        $entry.Optional | Should -BeTrue
        $entry.RequireParent | Should -BeTrue
    }
}

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..\..\lib\DotfilesTools.psm1') -Force
    function New-TestDir { (New-Item -ItemType Directory -Path (Join-Path $TestDrive ([guid]::NewGuid()))).FullName }
}

Describe 'Merge-JsonSettings' {
    BeforeEach {
        $dir = New-TestDir
        $managed = Join-Path $dir 'managed.json'
        $live = Join-Path $dir 'settings.json'
        $backups = Join-Path $dir 'backups'
        Set-Content -Path $managed -Value '{ "theme": "dark", "enabledPlugins": { "a@m": true, "b@m": true } }'
    }

    It 'creates the live file from the managed one when missing' {
        (Merge-JsonSettings -Path $live -ManagedPath $managed).Action | Should -Be 'Created'
        (Get-Content -Path $live -Raw | ConvertFrom-Json).theme | Should -Be 'dark'
    }

    It 'keeps keys the repo does not manage, including extra plugins' {
        Set-Content -Path $live -Value '{ "theme": "light", "model": "opus", "enabledPlugins": { "a@m": false, "local@m": true } }'
        $r = Merge-JsonSettings -Path $live -ManagedPath $managed -BackupDir $backups
        $r.Action | Should -Be 'Updated'
        $merged = Get-Content -Path $live -Raw | ConvertFrom-Json -AsHashtable
        $merged.theme | Should -Be 'dark'
        $merged.model | Should -Be 'opus'
        $merged.enabledPlugins['a@m'] | Should -BeTrue
        $merged.enabledPlugins['b@m'] | Should -BeTrue
        $merged.enabledPlugins['local@m'] | Should -BeTrue
    }

    It 'backs up the previous file before updating' {
        Set-Content -Path $live -Value '{ "theme": "light" }'
        $r = Merge-JsonSettings -Path $live -ManagedPath $managed -BackupDir $backups
        $r.BackupPath | Should -Exist
        (Get-Content -Path $r.BackupPath -Raw | ConvertFrom-Json).theme | Should -Be 'light'
    }

    It 'does not rewrite a file that already has the managed values' {
        Set-Content -Path $live -Value '{ "model": "opus", "theme": "dark", "enabledPlugins": { "b@m": true, "a@m": true } }'
        $before = Get-Content -Path $live -Raw
        (Merge-JsonSettings -Path $live -ManagedPath $managed -BackupDir $backups).Action | Should -Be 'Unchanged'
        Get-Content -Path $live -Raw | Should -Be $before
        $backups | Should -Not -Exist
    }

    It 'leaves a <Label> file alone and reports it (half-written or not a JSON object)' -ForEach @(
        @{ Label = 'empty'; Content = '' }
        @{ Label = 'whitespace-only'; Content = "   `n" }
        @{ Label = 'null'; Content = 'null' }
        @{ Label = 'array'; Content = '[1, 2]' }
    ) {
        [IO.File]::WriteAllText($live, $Content)
        $r = Merge-JsonSettings -Path $live -ManagedPath $managed
        $r.Action | Should -Be 'Failed'
        $r.Reason | Should -Match 'left alone'
        [IO.File]::ReadAllText($live) | Should -Be $Content
    }

    It 'reports which managed keys it changed' {
        Set-Content -Path $live -Value '{ "theme": "dark", "enabledPlugins": { "a@m": false, "b@m": true }, "model": "opus" }'
        $r = Merge-JsonSettings -Path $live -ManagedPath $managed
        $r.Action | Should -Be 'Updated'
        $r.Changed | Should -Be @('enabledPlugins.a@m')
    }

    It 'leaves a file that is not valid JSON alone and reports it' {
        Set-Content -Path $live -Value '{ "theme": "dark", '
        $r = Merge-JsonSettings -Path $live -ManagedPath $managed
        $r.Action | Should -Be 'Failed'
        $r.Reason | Should -Match 'left alone'
        Get-Content -Path $live -Raw | Should -Match '"theme": "dark", '
    }
}

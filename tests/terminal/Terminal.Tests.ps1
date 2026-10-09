BeforeAll {
    $topic = Join-Path $PSScriptRoot '..\..\terminal'
}

Describe 'terminal topic' {
    It 'ships valid Windows Terminal settings whose default profile exists' {
        $path = Join-Path $topic 'windows-terminal.json'
        $path | Should -Exist
        $settings = Get-Content -Path $path -Raw | ConvertFrom-Json
        $settings.defaultProfile | Should -Not -BeNullOrEmpty
        $settings.profiles.list.guid | Should -Contain $settings.defaultProfile
    }

    It 'copies to the Windows Terminal LocalState folder, only when Terminal is installed' {
        $entry = (Import-PowerShellDataFile -Path (Join-Path $topic 'links.psd1')).Links | Select-Object -First 1
        $entry.Source | Should -Be 'windows-terminal.json'
        $entry.Target | Should -Be '{LOCALAPPDATA}\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json'
        $entry.Method | Should -Be 'Copy'
        $entry.RequireParent | Should -BeTrue
        $entry.OnConflict | Should -BeNullOrEmpty
    }
}

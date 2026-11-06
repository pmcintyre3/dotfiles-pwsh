BeforeAll {
    $topic = Join-Path $PSScriptRoot '..\..\vscode'
}

Describe 'vscode keybindings' {
    It 'ships keybindings.json as a valid array of bindings (comments allowed, as VS Code does)' {
        $path = Join-Path $topic 'keybindings.json'
        $path | Should -Exist
        $bindings = @(Get-Content -Path $path -Raw | ConvertFrom-Json)
        $bindings.Count | Should -BeGreaterThan 0
        foreach ($binding in $bindings) {
            $binding.key | Should -Not -BeNullOrEmpty
            $binding.command | Should -Not -BeNullOrEmpty
        }
    }

    It "copies to VS Code's user folder, only when VS Code is installed" {
        $entry = (Import-PowerShellDataFile -Path (Join-Path $topic 'links.psd1')).Links | Select-Object -First 1
        $entry.Source | Should -Be 'keybindings.json'
        $entry.Target | Should -Be '{APPDATA}\Code\User\keybindings.json'
        $entry.Method | Should -Be 'Copy'
        $entry.RequireParent | Should -BeTrue
    }
}

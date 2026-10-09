BeforeAll {
    $installer = Join-Path $PSScriptRoot '..\..\vscode\install.ps1'
    # A stand-in for the `code` CLI (not installed on CI runners, so it can't be mocked there).
    function global:Invoke-FakeCode {
        $global:FakeCodeCalls.Add(($args -join ' '))
        if ($args[0] -eq '--list-extensions') { $global:FakeCodeInstalled; $global:LASTEXITCODE = 0; return }
        if ($args[0] -eq '--install-extension') { $global:LASTEXITCODE = if ($args[1] -eq 'bad.ext') { 1 } else { 0 }; return }
    }
}

AfterAll {
    Remove-Item -Path Function:\Invoke-FakeCode -ErrorAction Ignore
    Remove-Variable -Name FakeCodeCalls, FakeCodeInstalled -Scope Global -ErrorAction Ignore
}

Describe 'vscode/install.ps1' {
    BeforeEach {
        $global:FakeCodeCalls = [System.Collections.Generic.List[string]]::new()
        $global:FakeCodeInstalled = @('ms-python.python', 'Extra.One')
        $extensions = Join-Path $TestDrive "$([guid]::NewGuid()).txt"
        Set-Content -Path $extensions -Value @('# comment', 'ms-python.python', 'esbenp.prettier-vscode', '')
    }

    It 'installs listed extensions that are missing, and nothing else' {
        & $installer -ExtensionsPath $extensions -CodeCommand 'Invoke-FakeCode' 6> $null
        @($global:FakeCodeCalls | Where-Object { $_ -like '--install-extension*' }) | Should -Be @('--install-extension esbenp.prettier-vscode')
        @($global:FakeCodeCalls | Where-Object { $_ -like '--uninstall-extension*' }) | Should -BeNullOrEmpty
    }

    It 'matches extension IDs case-insensitively' {
        $global:FakeCodeInstalled = @('MS-Python.Python', 'esbenp.prettier-vscode')
        & $installer -ExtensionsPath $extensions -CodeCommand 'Invoke-FakeCode' 6> $null
        @($global:FakeCodeCalls | Where-Object { $_ -like '--install-extension*' }) | Should -BeNullOrEmpty
    }

    It 'skips when the VS Code CLI is not available' {
        { & $installer -ExtensionsPath $extensions -CodeCommand 'definitely-not-the-code-cli' 6> $null } | Should -Not -Throw
        $global:FakeCodeCalls | Should -BeNullOrEmpty
    }

    It 'keeps going after a failed extension install and throws at the end' {
        Set-Content -Path $extensions -Value @('bad.ext', 'good.ext')
        { & $installer -ExtensionsPath $extensions -CodeCommand 'Invoke-FakeCode' 6> $null } | Should -Throw '*1 VS Code extension*'
        $global:FakeCodeCalls | Should -Contain '--install-extension good.ext'
    }
}

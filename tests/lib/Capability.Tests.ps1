BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..\..\lib\DotfilesTools.psm1') -Force
}

Describe 'Test-IsAdmin' {
    It 'returns a bool' {
        Test-IsAdmin | Should -BeOfType [bool]
    }
}

Describe 'Get-MachineCapability' {
    It 'returns every capability with the expected type' {
        $cap = Get-MachineCapability -SkipNetwork
        foreach ($name in 'IsAdmin', 'CanSymlink', 'DeveloperMode', 'PolicyFromGpo', 'Winget', 'Scoop', 'Choco', 'Op', 'GitHubReachable', 'PSGalleryReachable') {
            $cap.$name | Should -BeOfType [bool] -Because $name
        }
        $cap.LanguageMode | Should -Be 'FullLanguage'
        $cap.ExecutionPolicy | Should -Not -BeNullOrEmpty
    }

    It 'makes no network calls with -SkipNetwork' {
        Mock -ModuleName DotfilesTools Invoke-WebRequest { throw 'network used' }
        $cap = Get-MachineCapability -SkipNetwork
        $cap.GitHubReachable | Should -BeFalse
        Should -Invoke -ModuleName DotfilesTools Invoke-WebRequest -Times 0 -Exactly
    }

    It 'reports reachable endpoints' {
        Mock -ModuleName DotfilesTools Invoke-WebRequest { }
        $cap = Get-MachineCapability
        $cap.GitHubReachable | Should -BeTrue
        $cap.PSGalleryReachable | Should -BeTrue
    }

    It 'reports unreachable endpoints without throwing' {
        Mock -ModuleName DotfilesTools Invoke-WebRequest { throw 'offline' }
        $cap = Get-MachineCapability
        $cap.GitHubReachable | Should -BeFalse
        $cap.PSGalleryReachable | Should -BeFalse
    }

    It 'leaves no symlink probe folders behind' {
        Get-MachineCapability -SkipNetwork | Out-Null
        Get-ChildItem -Path ([IO.Path]::GetTempPath()) -Filter 'dotfiles-symlink-probe-*' | Should -BeNullOrEmpty
    }
}

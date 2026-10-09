BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..\..\lib\DotfilesTools.psm1') -Force
    . (Join-Path $PSScriptRoot '..\..\packages\package-tools.ps1')
    $noApplicableInstaller = -1978335216
    $updateNotApplicable = -1978335189
    function New-Item2 { param([hashtable] $Fields) [pscustomobject]@{ Name = $Fields.Name; Group = 'core'; Winget = $Fields.Winget; Scoop = $Fields.Scoop; Choco = $Fields.Choco; Installed = $false } }
}

Describe 'Get-PackagePlan' {
    It 'keeps only enabled groups, in manifest order' {
        Mock Test-ScoopPackageInstalled { $false }
        $packages = @(
            @{ Name = 'A'; Group = 'core'; Winget = 'Vendor.A' }
            @{ Name = 'B'; Group = 'personal'; Winget = 'Vendor.B' }
            @{ Name = 'C'; Group = 'dev'; Winget = 'Vendor.C' }
        )
        (Get-PackagePlan -Packages $packages -Groups 'core', 'dev' -InstalledWinget @()).Name | Should -Be @('A', 'C')
    }

    It 'marks winget- and Scoop-installed packages as installed' {
        Mock Test-ScoopPackageInstalled { $Name -eq 'nvm' }
        $packages = @(
            @{ Name = 'Git'; Group = 'core'; Winget = 'Git.Git' }
            @{ Name = 'NVM'; Group = 'core'; Winget = 'CoreyButler.NVMforWindows'; Scoop = 'nvm' }
            @{ Name = 'Gh'; Group = 'core'; Winget = 'GitHub.cli'; Scoop = 'gh' }
        )
        $plan = Get-PackagePlan -Packages $packages -Groups 'core' -InstalledWinget @('git.git')
        ($plan | Where-Object Installed).Name | Should -Be @('Git', 'NVM')
    }
}

Describe 'Install-ManagedPackage' {
    BeforeEach {
        Mock Test-PackageManager { $Name -eq 'winget' }
        Mock Invoke-Winget { 0 }
        Mock Invoke-Scoop { }
        Mock Install-Scoop { }
        Mock Invoke-Choco { 0 }
        Mock Test-ScoopPackageInstalled { $true }
    }

    It 'installs per-user with winget first' {
        $r = Install-ManagedPackage -Package (New-Item2 @{ Name = 'Git'; Winget = 'Git.Git' }) -MachineAllowed $false
        $r.Action | Should -Be 'Installed'
        $r.Via | Should -Be 'winget (user)'
        Should -Invoke Invoke-Winget -Times 1 -Exactly -ParameterFilter { $Arguments -contains 'user' -and $Arguments -contains 'Git.Git' }
    }

    It 'reports NeedsAdmin instead of installing machine-wide when not allowed' {
        Mock Invoke-Winget { $noApplicableInstaller }
        $r = Install-ManagedPackage -Package (New-Item2 @{ Name = 'VS'; Winget = 'Microsoft.VisualStudio.Community' }) -MachineAllowed $false
        $r.Action | Should -Be 'NeedsAdmin'
        Should -Invoke Invoke-Winget -Times 0 -Exactly -ParameterFilter { $Arguments -contains 'machine' }
    }

    It 'falls back to Scoop (installing Scoop first) when there is no per-user winget installer' {
        Mock Test-PackageManager { $Name -eq 'winget' }   # scoop not present yet
        Mock Invoke-Winget { $noApplicableInstaller }
        $r = Install-ManagedPackage -Package (New-Item2 @{ Name = 'AWS'; Winget = 'Amazon.AWSCLI'; Scoop = 'aws' }) -MachineAllowed $false
        $r.Action | Should -Be 'Installed'
        $r.Via | Should -Be 'scoop'
        Should -Invoke Install-Scoop -Times 1 -Exactly
        Should -Invoke Invoke-Scoop -Times 1 -Exactly -ParameterFilter { $Arguments -contains 'aws' }
    }

    It 'installs machine-wide with winget when allowed' {
        Mock Invoke-Winget { if ($Arguments -contains 'user') { $noApplicableInstaller } else { 0 } }
        $r = Install-ManagedPackage -Package (New-Item2 @{ Name = 'VS'; Winget = 'Microsoft.VisualStudio.Community' }) -MachineAllowed $true
        $r.Action | Should -Be 'Installed'
        $r.Via | Should -Be 'winget (machine)'
    }

    It 'uses Chocolatey for Choco-only entries when machine-wide installs are allowed' {
        Mock Test-PackageManager { $Name -in 'winget', 'choco' }
        $r = Install-ManagedPackage -Package (New-Item2 @{ Name = 'Tool'; Choco = 'sometool' }) -MachineAllowed $true
        $r.Action | Should -Be 'Installed'
        $r.Via | Should -Be 'choco'
        Should -Invoke Invoke-Choco -Times 1 -Exactly -ParameterFilter { $Arguments -contains 'sometool' }
    }

    It 'reports other winget failures as Failed with the exit code' {
        Mock Invoke-Winget { 1 }
        $r = Install-ManagedPackage -Package (New-Item2 @{ Name = 'Git'; Winget = 'Git.Git' }) -MachineAllowed $false
        $r.Action | Should -Be 'Failed'
        $r.Reason | Should -Match '1'
    }

    It '-MachineOnly installs only machine-wide (never per-user or Scoop)' {
        $r = Install-ManagedPackage -Package (New-Item2 @{ Name = 'Git'; Winget = 'Git.Git'; Scoop = 'git' }) -MachineAllowed $true -MachineOnly
        $r.Via | Should -Be 'winget (machine)'
        Should -Invoke Invoke-Winget -Times 0 -Exactly -ParameterFilter { $Arguments -contains 'user' }
        Should -Invoke Invoke-Scoop -Times 0 -Exactly
    }

    It 'skips when no package manager can install it' {
        Mock Test-PackageManager { $false }
        (Install-ManagedPackage -Package (New-Item2 @{ Name = 'Git'; Winget = 'Git.Git' }) -MachineAllowed $false).Action | Should -Be 'Skipped'
    }
}

Describe 'Update-ManagedPackage' {
    It 'maps winget upgrade results' {
        Mock Invoke-Winget { 0 }
        (Update-ManagedPackage -Package (New-Item2 @{ Name = 'Git'; Winget = 'Git.Git' })).Action | Should -Be 'Upgraded'
        Mock Invoke-Winget { $updateNotApplicable }
        (Update-ManagedPackage -Package (New-Item2 @{ Name = 'Git'; Winget = 'Git.Git' })).Action | Should -Be 'UpToDate'
        Mock Invoke-Winget { 5 }
        (Update-ManagedPackage -Package (New-Item2 @{ Name = 'Git'; Winget = 'Git.Git' })).Action | Should -Be 'Failed'
    }
}

Describe 'packages/packages.psd1' {
    It 'has a group and a package manager ID for every entry' {
        $packages = (Import-PowerShellDataFile -Path (Join-Path $PSScriptRoot '..\..\packages\packages.psd1')).Packages
        $packages.Count | Should -BeGreaterThan 30
        foreach ($p in $packages) {
            $p.Group | Should -BeIn @('core', 'dev', 'apps', 'personal') -Because $p.Name
            ($p.Winget -or $p.Scoop -or $p.Choco) | Should -BeTrue -Because $p.Name
        }
    }
}

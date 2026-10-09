BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..\..\lib\DotfilesTools.psm1') -Force
    . (Join-Path $PSScriptRoot '..\..\packages\package-tools.ps1')   # so the wrapper commands exist to mock
    $installer = Join-Path $PSScriptRoot '..\..\packages\install.ps1'
}

Describe 'packages/install.ps1' {
    BeforeEach {
        $root = Join-Path $TestDrive ([guid]::NewGuid())
        New-Item -ItemType Directory -Path $root | Out-Null
        Set-Content -Path (Join-Path $root 'dotfiles.local.psd1') -Value "@{ PackageGroups = 'core'; Elevation = 'Auto' }"
        $manifest = Join-Path $root 'packages.psd1'
        Set-Content -Path $manifest -Value @'
@{
    Packages = @(
        @{ Name = 'Git'; Group = 'core'; Winget = 'Git.Git' }
        @{ Name = 'Broken'; Group = 'core'; Winget = 'Vendor.Broken' }
        @{ Name = 'Tool'; Group = 'core'; Winget = 'Vendor.Tool' }
        @{ Name = 'Game'; Group = 'personal'; Winget = 'Vendor.Game' }
    )
}
'@
        Mock Get-InstalledWingetId { @('Git.Git') }
        Mock Test-ScoopPackageInstalled { $false }
        Mock Test-IsAdmin { $false }
        Mock Install-ManagedPackage {
            $action = if ($Package.Name -eq 'Broken') { 'Failed' } else { 'Installed' }
            [pscustomobject]@{ Name = $Package.Name; Action = $action; Via = 'winget (user)'; Reason = 'test' }
        }
        Mock Update-ManagedPackage { [pscustomobject]@{ Name = $Package.Name; Action = 'UpToDate'; Via = $null; Reason = $null } }
    }

    It 'installs only missing packages in enabled groups, keeps going after a failure, and throws at the end' {
        { & $installer -Root $root -ManifestPath $manifest 6> $null } | Should -Throw '*1 package(s) failed*'
        Should -Invoke Install-ManagedPackage -Times 1 -Exactly -ParameterFilter { $Package.Name -eq 'Tool' }
        Should -Invoke Install-ManagedPackage -Times 0 -Exactly -ParameterFilter { $Package.Name -in 'Git', 'Game' }
        Should -Invoke Update-ManagedPackage -Times 0 -Exactly
    }

    It 'upgrades installed packages only with -Upgrade' {
        { & $installer -Root $root -ManifestPath $manifest -Upgrade 6> $null } | Should -Throw
        Should -Invoke Update-ManagedPackage -Times 1 -Exactly -ParameterFilter { $Package.Name -eq 'Git' }
    }

    It 'allows machine-wide installs inline only when elevated and Elevation is Auto' {
        Mock Test-IsAdmin { $true }
        { & $installer -Root $root -ManifestPath $manifest 6> $null } | Should -Throw
        Should -Invoke Install-ManagedPackage -ParameterFilter { $MachineAllowed -eq $true -and $Package.Name -eq 'Tool' } -Times 1 -Exactly

        Set-Content -Path (Join-Path $root 'dotfiles.local.psd1') -Value "@{ PackageGroups = 'core'; Elevation = 'Prompt' }"
        { & $installer -Root $root -ManifestPath $manifest 6> $null } | Should -Throw
        Should -Invoke Install-ManagedPackage -ParameterFilter { $MachineAllowed -eq $false -and $Package.Name -eq 'Tool' } -Times 1 -Exactly
    }

    It '-MachineOnly passes MachineOnly and allows machine-wide installs (elevated.ps1 already checked Elevation)' {
        Mock Test-IsAdmin { $true }
        Set-Content -Path (Join-Path $root 'dotfiles.local.psd1') -Value "@{ PackageGroups = 'core'; Elevation = 'Prompt' }"
        { & $installer -Root $root -ManifestPath $manifest -MachineOnly 6> $null } | Should -Throw
        Should -Invoke Install-ManagedPackage -ParameterFilter { $MachineOnly -and $MachineAllowed -eq $true -and $Package.Name -eq 'Tool' } -Times 1 -Exactly
    }
}

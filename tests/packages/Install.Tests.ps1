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
        $stateDir = Join-Path $root '.state'
        $needsAdminFile = Join-Path $stateDir 'needs-admin-packages.json'
        Mock Get-InstalledWingetId { [pscustomobject]@{ Ok = $true; Ids = @('Git.Git'); Reason = $null } }
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

    It 'keeps going when installing one package throws (bootstrap runs with ErrorActionPreference Stop)' {
        Mock Install-ManagedPackage {
            if ($Package.Name -eq 'Broken') { throw 'boom' }
            [pscustomobject]@{ Name = $Package.Name; Action = 'Installed'; Via = 'winget (user)'; Reason = $null }
        }
        $ErrorActionPreference = 'Stop'
        { & $installer -Root $root -ManifestPath $manifest 6> $null } | Should -Throw '*1 package(s) failed*'
        Should -Invoke Install-ManagedPackage -Times 1 -Exactly -ParameterFilter { $Package.Name -eq 'Tool' }
    }

    It 'skips package installs, without failing, when winget is unusable' {
        Mock Get-InstalledWingetId { [pscustomobject]@{ Ok = $false; Ids = @(); Reason = 'winget export exited 1' } }
        { & $installer -Root $root -ManifestPath $manifest 6> $null } | Should -Not -Throw
        Should -Invoke Install-ManagedPackage -Times 0 -Exactly
    }

    It 'upgrades installed packages only with -Upgrade, per-user only when machine-wide changes are not allowed' {
        { & $installer -Root $root -ManifestPath $manifest -Upgrade 6> $null } | Should -Throw
        Should -Invoke Update-ManagedPackage -Times 1 -Exactly -ParameterFilter { $Package.Name -eq 'Git' -and $Scope -eq 'user' }
    }

    It 'upgrades without a scope filter when elevated and Elevation is Auto' {
        Mock Test-IsAdmin { $true }
        { & $installer -Root $root -ManifestPath $manifest -Upgrade 6> $null } | Should -Throw
        Should -Invoke Update-ManagedPackage -Times 1 -Exactly -ParameterFilter { $Package.Name -eq 'Git' -and -not $Scope }
    }

    It 'allows machine-wide installs inline only when elevated and Elevation is Auto' {
        Mock Test-IsAdmin { $true }
        { & $installer -Root $root -ManifestPath $manifest 6> $null } | Should -Throw
        Should -Invoke Install-ManagedPackage -ParameterFilter { $MachineAllowed -eq $true -and $Package.Name -eq 'Tool' } -Times 1 -Exactly

        Set-Content -Path (Join-Path $root 'dotfiles.local.psd1') -Value "@{ PackageGroups = 'core'; Elevation = 'Prompt' }"
        { & $installer -Root $root -ManifestPath $manifest 6> $null } | Should -Throw
        Should -Invoke Install-ManagedPackage -ParameterFilter { $MachineAllowed -eq $false -and $Package.Name -eq 'Tool' } -Times 1 -Exactly
    }

    It 'records packages that need admin, for dot -Elevated' {
        Mock Install-ManagedPackage {
            $action = if ($Package.Name -eq 'Tool') { 'NeedsAdmin' } else { 'Installed' }
            [pscustomobject]@{ Name = $Package.Name; Action = $action; Via = $null; Reason = 'test' }
        }
        & $installer -Root $root -ManifestPath $manifest 6> $null
        @(Get-Content -Path $needsAdminFile -Raw | ConvertFrom-Json) | Should -Be @('Vendor.Tool')
    }

    It '-MachineOnly installs only the recorded packages, without detection (it may be another account)' {
        Mock Test-IsAdmin { $true }
        New-Item -ItemType Directory -Path $stateDir -Force | Out-Null
        ConvertTo-Json -InputObject @('Vendor.Tool') | Set-Content -Path $needsAdminFile
        & $installer -Root $root -ManifestPath $manifest -MachineOnly 6> $null
        Should -Invoke Install-ManagedPackage -Times 1 -Exactly
        Should -Invoke Install-ManagedPackage -Times 1 -Exactly -ParameterFilter { $MachineOnly -and $MachineAllowed -and $Package.Name -eq 'Tool' }
        Should -Invoke Get-InstalledWingetId -Times 0 -Exactly
        @(Get-Content -Path $needsAdminFile -Raw | ConvertFrom-Json) | Should -BeNullOrEmpty
    }

    It '-MachineOnly -Upgrade upgrades machine-scope packages only' {
        Mock Test-IsAdmin { $true }
        { & $installer -Root $root -ManifestPath $manifest -MachineOnly -Upgrade 6> $null } | Should -Not -Throw
        Should -Invoke Update-ManagedPackage -Times 3 -Exactly -ParameterFilter { $Scope -eq 'machine' }
        Should -Invoke Get-InstalledWingetId -Times 0 -Exactly
    }
}

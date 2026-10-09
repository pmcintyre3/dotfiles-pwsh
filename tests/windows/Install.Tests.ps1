BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..\..\lib\DotfilesTools.psm1') -Force
    $installer = Join-Path $PSScriptRoot '..\..\windows\install.ps1'
}

Describe 'windows/install.ps1' {
    BeforeEach {
        $root = Join-Path $TestDrive ([guid]::NewGuid())
        New-Item -ItemType Directory -Path $root | Out-Null
        $settingsPath = Join-Path $root 'defaults.psd1'
        $userKey = "TestRegistry:\$([guid]::NewGuid())\User"
        $machineKey = "TestRegistry:\$([guid]::NewGuid())\Machine"
        New-Item -Path $userKey -Force | Out-Null
        Set-ItemProperty -Path $userKey -Name 'HideFileExt' -Value 1
        Set-Content -Path $settingsPath -Value @"
@{
    Settings = @(
        @{ Scope = 'User'; Path = '$userKey'; Name = 'HideFileExt'; Value = 0; Description = 'Show file extensions' }
        @{ Scope = 'Machine'; Path = '$machineKey'; Name = 'LongPathsEnabled'; Value = 1; Description = 'Long paths' }
    )
}
"@
        function Set-Elevation { param([string] $Value) Set-Content -Path (Join-Path $root 'dotfiles.local.psd1') -Value "@{ Elevation = '$Value' }" }
        function Get-Value { param([string] $Key, [string] $Name) (Get-ItemProperty -Path $Key -Name $Name -ErrorAction Ignore).$Name }
    }

    It 'applies user settings and leaves machine settings for dot -Elevated when not admin' {
        Mock Test-IsAdmin { $false }
        Set-Elevation 'Auto'
        & $installer -Root $root -SettingsPath $settingsPath 6> $null
        Get-Value $userKey 'HideFileExt' | Should -Be 0
        Get-Value $machineKey 'LongPathsEnabled' | Should -BeNullOrEmpty
    }

    It 'applies machine settings inline only when elevated and Elevation is Auto' {
        Mock Test-IsAdmin { $true }
        Set-Elevation 'Prompt'
        & $installer -Root $root -SettingsPath $settingsPath 6> $null
        Get-Value $machineKey 'LongPathsEnabled' | Should -BeNullOrEmpty

        Set-Elevation 'Auto'
        & $installer -Root $root -SettingsPath $settingsPath 6> $null
        Get-Value $machineKey 'LongPathsEnabled' | Should -Be 1
    }

    It '-MachineOnly applies only machine settings (never HKCU)' {
        Mock Test-IsAdmin { $true }
        Set-Elevation 'Prompt'
        & $installer -Root $root -SettingsPath $settingsPath -MachineOnly 6> $null
        Get-Value $machineKey 'LongPathsEnabled' | Should -Be 1
        Get-Value $userKey 'HideFileExt' | Should -Be 1
    }

    It 'never applies machine settings when Elevation is Never' {
        Mock Test-IsAdmin { $true }
        Set-Elevation 'Never'
        & $installer -Root $root -SettingsPath $settingsPath -MachineOnly 6> $null
        Get-Value $machineKey 'LongPathsEnabled' | Should -BeNullOrEmpty
    }

    It 'leaves settings that already match alone' {
        Mock Test-IsAdmin { $false }
        Set-ItemProperty -Path $userKey -Name 'HideFileExt' -Value 0
        Mock New-ItemProperty { throw 'should not write' }
        { & $installer -Root $root -SettingsPath $settingsPath 6> $null } | Should -Not -Throw
        Should -Invoke New-ItemProperty -Times 0 -Exactly
    }
}

Describe 'windows/install.ps1 folder-type view overrides' {
    BeforeEach {
        $root = Join-Path $TestDrive ([guid]::NewGuid())
        New-Item -ItemType Directory -Path $root | Out-Null
        Set-Content -Path (Join-Path $root 'dotfiles.local.psd1') -Value "@{ Elevation = 'Prompt' }"
        $base = "TestRegistry:\$([guid]::NewGuid())"
        $source = "$base\HKLM\FolderTypes"
        $target = "$base\HKCU\FolderTypes"
        $guid = '{885a186e-a440-4ada-812b-db871b942259}'
        $view = "$source\$guid\TopViews\{00000000-0000-0000-0000-000000000000}"
        New-Item -Path $view -Force | Out-Null
        Set-ItemProperty -Path "$source\$guid" -Name 'CanonicalName' -Value 'Downloads'
        Set-ItemProperty -Path $view -Name 'GroupBy' -Value 'System.DateModified'
        Set-ItemProperty -Path $view -Name 'SortByList' -Value 'prop:System.DateModified'
        $settingsPath = Join-Path $root 'defaults.psd1'
        Set-Content -Path $settingsPath -Value @"
@{
    Settings = @()
    FolderTypes = @(
        @{ Guid = '$guid'; GroupBy = ''; Description = 'Downloads folders not grouped by date' }
        @{ Guid = '{00000000-1111-2222-3333-444444444444}'; GroupBy = ''; Description = 'A folder type this Windows lacks' }
    )
}
"@
        $runArgs = @{ Root = $root; SettingsPath = $settingsPath; FolderTypesSource = $source; FolderTypesTarget = $target }
        Mock Test-IsAdmin { $false }
    }

    It 'copies the Windows definition to the per-user key once and clears GroupBy' {
        & $installer @runArgs 6> $null
        $copiedView = "$target\$guid\TopViews\{00000000-0000-0000-0000-000000000000}"
        (Get-ItemProperty -Path $copiedView).GroupBy | Should -Be ''
        (Get-ItemProperty -Path $copiedView).SortByList | Should -Be 'prop:System.DateModified'
        (Get-ItemProperty -Path "$target\$guid").CanonicalName | Should -Be 'Downloads'
        (Get-ItemProperty -Path $view).GroupBy | Should -Be 'System.DateModified'   # the Windows definition is untouched
    }

    It 'keeps an existing per-user copy (and its other values), only fixing GroupBy' {
        & $installer @runArgs 6> $null
        $copiedView = "$target\$guid\TopViews\{00000000-0000-0000-0000-000000000000}"
        Set-ItemProperty -Path $copiedView -Name 'LogicalViewMode' -Value 4
        Set-ItemProperty -Path $copiedView -Name 'GroupBy' -Value 'System.DateModified'
        & $installer @runArgs 6> $null
        (Get-ItemProperty -Path $copiedView).GroupBy | Should -Be ''
        (Get-ItemProperty -Path $copiedView).LogicalViewMode | Should -Be 4
    }

    It 'skips folder types this Windows version does not have' {
        { & $installer @runArgs 6> $null } | Should -Not -Throw
        Test-Path -Path "$target\{00000000-1111-2222-3333-444444444444}" | Should -BeFalse
    }

    It '-MachineOnly never touches per-user folder types' {
        Mock Test-IsAdmin { $true }
        & $installer @runArgs -MachineOnly 6> $null
        Test-Path -Path $target | Should -BeFalse
    }
}

Describe 'windows/defaults.psd1' {
    It 'turns off group-by-date for the Downloads folder type with a per-user folder-type override' {
        $definitions = Import-PowerShellDataFile -Path (Join-Path $PSScriptRoot '..\..\windows\defaults.psd1')
        $downloads = $definitions.FolderTypes | Where-Object { $_.Guid -eq '{885a186e-a440-4ada-812b-db871b942259}' }
        $downloads.GroupBy | Should -Be ''
        $definitions.Settings.Name | Should -Not -Contain 'GroupView'
    }

    It 'mirrors Raijin: extensions shown, hidden files shown, Explorer to This PC, dark mode; long paths and Developer Mode machine-wide' {
        $settings = (Import-PowerShellDataFile -Path (Join-Path $PSScriptRoot '..\..\windows\defaults.psd1')).Settings
        ($settings | Where-Object { $_.Scope -eq 'User' }).Name | Should -Be @('HideFileExt', 'Hidden', 'LaunchTo', 'AppsUseLightTheme', 'SystemUsesLightTheme')
        ($settings | Where-Object { $_.Scope -eq 'Machine' }).Name | Should -Be @('LongPathsEnabled', 'AllowDevelopmentWithoutDevLicense')
        $settings | ForEach-Object { $_.Path | Should -Match '^HK(CU|LM):\\' }
    }
}

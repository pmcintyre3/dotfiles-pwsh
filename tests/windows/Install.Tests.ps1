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

Describe 'windows/defaults.psd1' {
    It 'turns off group-by-date for the Downloads folder type, per user' {
        $settings = (Import-PowerShellDataFile -Path (Join-Path $PSScriptRoot '..\..\windows\defaults.psd1')).Settings
        $grouping = $settings | Where-Object { $_.Name -eq 'GroupView' }
        $grouping.Scope | Should -Be 'User'
        $grouping.Path | Should -Be 'HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\Shell\Bags\AllFolders\Shell\{885A186E-A440-4ADA-812B-DB871B942259}'
        $grouping.Value | Should -Be 0
    }

    It 'mirrors Raijin: extensions shown, hidden files shown, Explorer to This PC, dark mode, no Downloads grouping; long paths and Developer Mode machine-wide' {
        $settings = (Import-PowerShellDataFile -Path (Join-Path $PSScriptRoot '..\..\windows\defaults.psd1')).Settings
        ($settings | Where-Object { $_.Scope -eq 'User' }).Name | Should -Be @('HideFileExt', 'Hidden', 'LaunchTo', 'AppsUseLightTheme', 'SystemUsesLightTheme', 'GroupView')
        ($settings | Where-Object { $_.Scope -eq 'Machine' }).Name | Should -Be @('LongPathsEnabled', 'AllowDevelopmentWithoutDevLicense')
        $settings | ForEach-Object { $_.Path | Should -Match '^HK(CU|LM):\\' }
    }
}

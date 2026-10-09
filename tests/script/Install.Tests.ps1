Describe 'script/install.ps1' {
    It 'runs every topic installer, continues past failures, and skips excluded topics and the root installer' {
        $installScript = Join-Path $PSScriptRoot '..\..\script\install.ps1'
        $root = Join-Path $TestDrive 'root'
        foreach ($topic in 'alpha', 'beta', 'gamma', 'skipme') {
            New-Item -ItemType Directory -Path (Join-Path $root $topic) -Force | Out-Null
        }
        $marker = Join-Path $TestDrive 'ran.txt'
        Set-Content -Path (Join-Path $root 'install.ps1') -Value "Add-Content -Path '$marker' -Value 'root'"
        Set-Content -Path (Join-Path $root 'alpha\install.ps1') -Value "Add-Content -Path '$marker' -Value 'alpha'"
        Set-Content -Path (Join-Path $root 'beta\install.ps1') -Value "throw 'beta broke'"
        Set-Content -Path (Join-Path $root 'gamma\install.ps1') -Value "Add-Content -Path '$marker' -Value 'gamma'"
        Set-Content -Path (Join-Path $root 'skipme\install.ps1') -Value "Add-Content -Path '$marker' -Value 'skipme'"
        Set-Content -Path (Join-Path $root 'dotfiles.local.psd1') -Value "@{ ExcludeTopics = 'skipme' }"

        $results = & $installScript -Root $root 6> $null

        Get-Content -Path $marker | Should -Be @('alpha', 'gamma')
        ($results | Where-Object Topic -eq 'beta').Succeeded | Should -BeFalse
        ($results | Where-Object Topic -eq 'beta').Error | Should -Be 'beta broke'
        ($results | Where-Object Succeeded).Topic | Should -Be @('alpha', 'gamma')
    }

    It 'passes -Upgrade only to installers that declare it' {
        $installScript = Join-Path $PSScriptRoot '..\..\script\install.ps1'
        $root = Join-Path $TestDrive 'upgrade-root'
        foreach ($topic in 'plain', 'up') { New-Item -ItemType Directory -Path (Join-Path $root $topic) -Force | Out-Null }
        $marker = Join-Path $TestDrive 'upgrade-ran.txt'
        Set-Content -Path (Join-Path $root 'plain\install.ps1') -Value "Add-Content -Path '$marker' -Value 'plain'"
        Set-Content -Path (Join-Path $root 'up\install.ps1') -Value "param([switch] `$Upgrade) Add-Content -Path '$marker' -Value ""up:`$Upgrade"""

        & $installScript -Root $root -Upgrade 6> $null | Out-Null

        Get-Content -Path $marker | Should -Be @('plain', 'up:True')
    }
}

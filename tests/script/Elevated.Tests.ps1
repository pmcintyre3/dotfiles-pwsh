BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..\..\lib\DotfilesTools.psm1') -Force
    $elevated = Join-Path $PSScriptRoot '..\..\script\elevated.ps1'

    function New-ElevatedRoot {
        param([string] $Elevation)
        $root = Join-Path $TestDrive ([guid]::NewGuid())
        foreach ($topic in 'machine', 'useronly') { New-Item -ItemType Directory -Path (Join-Path $root $topic) -Force | Out-Null }
        $marker = Join-Path $root 'ran.txt'
        Set-Content -Path (Join-Path $root 'machine\install.ps1') -Value "param([switch] `$MachineOnly) Add-Content -Path '$marker' -Value ""machine:`$MachineOnly"""
        Set-Content -Path (Join-Path $root 'useronly\install.ps1') -Value "Add-Content -Path '$marker' -Value 'useronly'"
        Set-Content -Path (Join-Path $root 'dotfiles.local.psd1') -Value "@{ Elevation = '$Elevation' }"
        return $root
    }
}

Describe 'script/elevated.ps1' {
    It 'refuses to run without admin rights' {
        Mock Test-IsAdmin { $false }
        $root = New-ElevatedRoot -Elevation 'Prompt'
        { & $elevated -Root $root 6> $null } | Should -Throw '*dot -Elevated*'
        Join-Path $root 'ran.txt' | Should -Not -Exist
    }

    It 'does nothing when Elevation is Never' {
        Mock Test-IsAdmin { $true }
        $root = New-ElevatedRoot -Elevation 'Never'
        & $elevated -Root $root 6> $null
        $LASTEXITCODE | Should -Be 0
        Join-Path $root 'ran.txt' | Should -Not -Exist
    }

    It 'runs only installers that declare -MachineOnly (never per-user steps)' {
        Mock Test-IsAdmin { $true }
        $root = New-ElevatedRoot -Elevation 'Prompt'
        & $elevated -Root $root 6> $null
        $LASTEXITCODE | Should -Be 0
        Get-Content -Path (Join-Path $root 'ran.txt') | Should -Be 'machine:True'
    }

    It 'passes -Upgrade to machine installers that declare it' {
        Mock Test-IsAdmin { $true }
        $root = New-ElevatedRoot -Elevation 'Prompt'
        $marker = Join-Path $root 'ran.txt'
        Set-Content -Path (Join-Path $root 'machine\install.ps1') -Value "param([switch] `$MachineOnly, [switch] `$Upgrade) Add-Content -Path '$marker' -Value ""both `$MachineOnly `$Upgrade"""
        & $elevated -Root $root -Upgrade 6> $null
        Get-Content -Path $marker | Should -Be 'both True True'
    }

    It 'exits 1 when a machine installer fails' {
        Mock Test-IsAdmin { $true }
        $root = New-ElevatedRoot -Elevation 'Auto'
        Set-Content -Path (Join-Path $root 'machine\install.ps1') -Value 'param([switch] $MachineOnly) throw "boom"'
        & $elevated -Root $root 6> $null
        $LASTEXITCODE | Should -Be 1
    }
}

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..\..\lib\DotfilesTools.psm1') -Force
    $reset = Join-Path $PSScriptRoot '..\..\windows\reset-explorer-views.ps1'
}

Describe 'windows/reset-explorer-views.ps1' {
    BeforeEach {
        $base = "TestRegistry:\$([guid]::NewGuid())"
        $bags = "$base\Bags"
        $mru = "$base\BagMRU"
        New-Item -Path "$bags\1\Shell" -Force | Out-Null
        New-Item -Path $mru -Force | Out-Null
        $marker = Join-Path $TestDrive "$([guid]::NewGuid()).txt"
        $fakeInstall = Join-Path $TestDrive "$([guid]::NewGuid()).ps1"
        Set-Content -Path $fakeInstall -Value "Set-Content -Path '$marker' -Value defaults"
        $resetArgs = @{
            ViewKeys      = @($mru, $bags, "$base\Missing")
            BackupDir     = (Join-Path $TestDrive ([guid]::NewGuid()))
            InstallScript = $fakeInstall
            NoRestart     = $true
        }
    }

    It 'backs up every existing key, then clears them and re-applies the defaults' {
        Mock reg { $global:LASTEXITCODE = 0 }
        & $reset @resetArgs 6> $null
        Should -Invoke reg -Times 2 -Exactly -ParameterFilter { $args[0] -eq 'export' }
        Test-Path -Path $bags | Should -BeFalse
        Test-Path -Path $mru | Should -BeFalse
        Get-Content -Path $marker | Should -Be 'defaults'
    }

    It 'does not delete anything when the backup fails' {
        Mock reg { $global:LASTEXITCODE = 1 }
        { & $reset @resetArgs 6> $null } | Should -Throw '*nothing was deleted*'
        Test-Path -Path $bags | Should -BeTrue
        Test-Path -Path $mru | Should -BeTrue
        $marker | Should -Not -Exist
    }

    It 'restarts Explorer unless -NoRestart' {
        Mock reg { $global:LASTEXITCODE = 0 }
        Mock Stop-Process { }
        Mock Start-Sleep { }
        Mock Get-Process { [pscustomobject]@{ Name = 'explorer' } }
        $resetArgs.NoRestart = $false
        & $reset @resetArgs 6> $null
        Should -Invoke Stop-Process -Times 1 -Exactly -ParameterFilter { $Name -eq 'explorer' }
    }
}

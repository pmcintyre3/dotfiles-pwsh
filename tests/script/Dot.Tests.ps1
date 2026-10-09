BeforeAll {
    . (Join-Path $PSScriptRoot '..\TestHelpers.ps1')
}

Describe 'bin/dot.ps1' {
    BeforeEach {
        $repo = Copy-DotfilesRepo -Destination (Join-Path $TestDrive ([guid]::NewGuid()))
        New-Item -ItemType Directory -Path (Join-Path $repo '.git') | Out-Null
        $marker = Join-Path $repo 'bootstrap-ran.txt'
        # Replace bootstrap so the test can never touch the real $PROFILE.
        Set-Content -Path (Join-Path $repo 'script\bootstrap.ps1') -Value "Set-Content -Path '$marker' -Value ran; exit 0"
        $dot = Join-Path $repo 'bin\dot.ps1'
    }

    It 'stops before bootstrap when git pull fails' {
        Mock git { $global:LASTEXITCODE = 1 }
        & $dot *> $null
        $LASTEXITCODE | Should -Be 1
        $marker | Should -Not -Exist
    }

    It 'pulls with --ff-only, then runs bootstrap' {
        Mock git { $global:LASTEXITCODE = 0 }
        & $dot *> $null
        Should -Invoke git -Times 1 -Exactly -ParameterFilter { $args -contains 'pull' -and $args -contains '--ff-only' }
        $marker | Should -Exist
        $LASTEXITCODE | Should -Be 0
    }

    It 'skips the pull for a zip install (no .git folder)' {
        Remove-Item -Path (Join-Path $repo '.git')
        Mock git { throw 'git should not run' }
        & $dot *> $null
        $marker | Should -Exist
    }

    It 'passes -Upgrade to bootstrap' {
        Set-Content -Path (Join-Path $repo 'script\bootstrap.ps1') -Value "param([switch] `$Upgrade) Set-Content -Path '$marker' -Value ""upgrade=`$Upgrade""; exit 0"
        Mock git { $global:LASTEXITCODE = 0 }
        & $dot -Upgrade *> $null
        Get-Content -Path $marker | Should -Be 'upgrade=True'
    }

    It '-Elevated runs script\elevated.ps1 elevated, returns its exit code, and skips pull and bootstrap' {
        Mock git { throw 'git should not run' }
        Mock Start-Process { [pscustomobject]@{ ExitCode = 3 } }
        & $dot -Elevated *> $null
        $LASTEXITCODE | Should -Be 3
        Should -Invoke Start-Process -Times 1 -Exactly -ParameterFilter { $Verb -eq 'RunAs' -and "$ArgumentList" -like '*script\elevated.ps1*' }
        $marker | Should -Not -Exist
    }

    It 'dot -ResetExplorerViews runs the reset and nothing else' {
        $resetMarker = Join-Path $repo 'reset-ran.txt'
        Set-Content -Path (Join-Path $repo 'windows\reset-explorer-views.ps1') -Value "Set-Content -Path '$resetMarker' -Value ran"
        Mock git { throw 'git should not run' }
        & $dot -ResetExplorerViews *> $null
        $LASTEXITCODE | Should -Be 0
        $resetMarker | Should -Exist
        $marker | Should -Not -Exist
    }

    It '-Elevated -Upgrade forwards -Upgrade to the elevated run' {
        Mock Start-Process { [pscustomobject]@{ ExitCode = 0 } }
        & $dot -Elevated -Upgrade *> $null
        Should -Invoke Start-Process -Times 1 -Exactly -ParameterFilter { "$ArgumentList" -like '*elevated.ps1*-Upgrade*' }
    }

    It '-Elevated reports a declined UAC prompt and exits 1' {
        Mock Start-Process { throw 'The operation was canceled by the user.' }
        & $dot -Elevated *> $null
        $LASTEXITCODE | Should -Be 1
    }
}

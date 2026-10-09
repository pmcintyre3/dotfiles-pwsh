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
}

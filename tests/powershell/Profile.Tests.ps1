BeforeAll {
    . (Join-Path $PSScriptRoot '..\TestHelpers.ps1')
}

Describe 'powershell/profile.ps1' {
    It 'loads cleanly with default values' {
        $repo = Copy-DotfilesRepo -Destination (Join-Path $TestDrive 'clean\repo')
        $probe = Invoke-ProfileProbe -RepoRoot $repo
        $probe.Result.LoadErrors | Should -Be 0 -Because ($probe.Output -join "`n")
        $probe.Result.Source | Should -Be 'C:\Projects'
        $probe.Result.BinOnPath | Should -BeTrue
        $probe.Result.Commands | Should -Contain 'Add-PathEntry'
    }

    It 'lets profile.local.ps1 override defaults' {
        $repo = Copy-DotfilesRepo -Destination (Join-Path $TestDrive 'local\repo')
        Set-Content -Path (Join-Path $repo 'powershell\profile.local.ps1') -Value "`$env:ProjectHome = 'D:\Work'"
        (Invoke-ProfileProbe -RepoRoot $repo).Result.Source | Should -Be 'D:\Work'
    }

    It 'keeps loading when one file throws, and names the file' {
        $repo = Copy-DotfilesRepo -Destination (Join-Path $TestDrive 'broken\repo')
        New-Item -ItemType Directory -Path (Join-Path $repo 'powershell\functions') -Force | Out-Null
        Set-Content -Path (Join-Path $repo 'powershell\functions\aa-broken.ps1') -Value 'throw "boom"'
        Set-Content -Path (Join-Path $repo 'powershell\functions\ab-fine.ps1') -Value 'function Test-StillLoaded { }'

        $probe = Invoke-ProfileProbe -RepoRoot $repo -CommandName 'Test-StillLoaded'
        ($probe.Output -join "`n") | Should -Match 'aa-broken\.ps1'
        $probe.Result.Commands | Should -Contain 'Test-StillLoaded'
        $probe.Result.BinOnPath | Should -BeTrue
    }

    It 'skips topics listed in ExcludeTopics' {
        $repo = Copy-DotfilesRepo -Destination (Join-Path $TestDrive 'exclude\repo')
        New-Item -ItemType Directory -Path (Join-Path $repo 'demo\functions') -Force | Out-Null
        Set-Content -Path (Join-Path $repo 'demo\functions\demo.ps1') -Value 'function Test-DemoLoaded { }'
        Set-Content -Path (Join-Path $repo 'dotfiles.local.psd1') -Value "@{ ExcludeTopics = 'demo' }"

        (Invoke-ProfileProbe -RepoRoot $repo -CommandName 'Test-DemoLoaded').Result.Commands | Should -BeNullOrEmpty
    }

    It 'still loads, with a warning, when dotfiles.local.psd1 is malformed' {
        $repo = Copy-DotfilesRepo -Destination (Join-Path $TestDrive 'badconfig\repo')
        Set-Content -Path (Join-Path $repo 'dotfiles.local.psd1') -Value '@{ ExcludeTopics = '
        $probe = Invoke-ProfileProbe -RepoRoot $repo
        ($probe.Output -join "`n") | Should -Match 'dotfiles\.local\.psd1'
        $probe.Result.BinOnPath | Should -BeTrue
    }

    It 'leaves user variables alone that share names with profile temporaries' {
        $repo = Copy-DotfilesRepo -Destination (Join-Path $TestDrive 'vars\repo')
        $script = Join-Path $TestDrive 'vars\check.ps1'
        Set-Content -Path $script -Value @'
param([string] $ProfilePath)
$tool = 'mine'; $newest = 'mine'; $toolsRoot = 'mine'; $opensslConf = 'mine'; $moduleManifest = 'mine'
. $ProfilePath
"$tool|$newest|$toolsRoot|$opensslConf|$moduleManifest"
'@
        $out = pwsh -NoProfile -NonInteractive -File $script -ProfilePath (Join-Path $repo 'powershell\profile.ps1') 2>$null |
            Select-Object -Last 1
        $out | Should -Be 'mine|mine|mine|mine|mine'
    }

    It 'keeps a PYTHONIOENCODING set in profile.local.ps1' {
        $repo = Copy-DotfilesRepo -Destination (Join-Path $TestDrive 'pyenc\repo')
        Set-Content -Path (Join-Path $repo 'powershell\profile.local.ps1') -Value "`$env:PYTHONIOENCODING = 'latin-1'"
        $command = "`$env:PYTHONIOENCODING = `$null; . '$(Join-Path $repo 'powershell\profile.ps1')'; `$env:PYTHONIOENCODING"
        pwsh -NoProfile -NonInteractive -Command $command 2>$null | Select-Object -Last 1 | Should -Be 'latin-1'
    }

    It 'warns, naming the module, when an eager module is not installed' {
        $repo = Copy-DotfilesRepo -Destination (Join-Path $TestDrive 'eager\repo')
        Set-Content -Path (Join-Path $repo 'powershell\modules.psd1') -Value "@{ Modules = @( @{ Name = 'Not.A.Real.Module'; Import = 'Eager' } ) }"
        $probe = Invoke-ProfileProbe -RepoRoot $repo
        ($probe.Output -join "`n") | Should -Match 'Not\.A\.Real\.Module'
        $probe.Result.LoadErrors | Should -Be 0 -Because ($probe.Output -join "`n")
    }
}

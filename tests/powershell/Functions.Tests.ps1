BeforeDiscovery {
    # Defined at discovery time because the -ForEach below needs it before any BeforeAll runs.
    $expected = @(
        # powershell/functions/navigation.ps1 + powershell/aliases.ps1
        'Initialize-Profile', 'Open-ExplorerViaII', 'Set-ParentLocation', 'Set-GrandParentLocation'
        'Set-LocationAndGetChildItem', 'Get-AllChildItems', 'New-ItemAndSetLocation', 'cdp', 'cdposh'
        'initp', '..', '...', 'iii', 'gui', 'cl', 'la', 'mkcd'
        # network.ps1, menu.ps1
        'Get-NetworkDeviceInfo', 'Get-MenuSelection', 'Get-KeyValueMenuSelection', 'Get-KeyCodeFromKeyPress'
        # git/functions/git.ps1 + git/aliases.ps1
        'Invoke-MispelledGitCommand', 'Get-LocalGitBranches', 'Invoke-GitUnsetUpstream', 'Invoke-GitRebase'
        'Invoke-GitRebaseFromOrigin', 'Merge-UpdatedGitBranch', 'Merge-UpdatedGitBranchFromOrigin'
        'Get-ReferencesForAllGitBranches', 'Get-LatestFromGitBranch', 'Get-GitRepositoryName'
        'Get-CurrentlyInGitRepository', 'Get-GitDefaultBranchName', 'Get-GitCurrentBranchName', 'Remove-LocalMergedBranches'
        'gti', 'glsb', 'gfix', 'gmg', 'gmerge', 'grb', 'grebase', 'grepo'
    )
}

BeforeAll {
    . (Join-Path $PSScriptRoot '..\TestHelpers.ps1')
}

Describe 'migrated commands' -ForEach @{ Expected = $expected } {
    BeforeAll {
        $repo = Copy-DotfilesRepo -Destination (Join-Path $TestDrive 'migrated\repo')
        $probe = Invoke-ProfileProbe -RepoRoot $repo -CommandName ($Expected + 'gfc')
    }

    It 'loads without errors' {
        $probe.Result.LoadErrors | Should -Be 0 -Because ($probe.Output -join "`n")
    }

    It 'defines <_>' -ForEach $Expected {
        $probe.Result.Commands | Should -Contain $_
    }

    It 'does not define gfc (its function was commented out in the legacy profile)' {
        $probe.Result.Commands | Should -Not -Contain 'gfc'
    }
}

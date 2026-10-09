@{
    Severity     = @('Error', 'Warning')
    ExcludeRules = @(
        # Status output and interactive menus write to the host by design.
        'PSAvoidUsingWriteHost'
        # Profile state ($ProjectPaths, $DotfilesRoot) is global by design.
        'PSAvoidGlobalVars'
        # New-DotLink takes an explicit -ConflictAction instead of ShouldProcess.
        'PSUseShouldProcessForStateChangingFunctions'
        # Migrated names (Get-LocalGitBranches, Invoke-DotLinks) are kept for muscle memory.
        'PSUseSingularNouns'
    )
}

@{
    Links = @(
        @{
            # $PROFILE (OneDrive-synced) becomes a stub; the real profile stays in the clone.
            Source     = 'profile.ps1'
            Target     = '{PROFILE}'
            Method     = 'Include'
            OnConflict = 'Backup'
            Template   = @'
# Managed by dotfiles-pwsh. Edit ~\.dotfiles\powershell\profile.ps1, not this file.
# This file syncs through OneDrive, so machines without a clone fall back to the legacy profile.
# (Don't name a variable here $dotfilesRoot: names are case-insensitive and the profile sets $DotfilesRoot.)
$dotfilesClone = if ($env:DOTFILES_ROOT) { $env:DOTFILES_ROOT } else { Join-Path $HOME '.dotfiles' }
$dotfilesProfile = Join-Path $dotfilesClone 'powershell\profile.ps1'
$legacyProfile = Join-Path $PSScriptRoot 'Microsoft.PowerShell_profile.legacy.ps1'
if (Test-Path -Path $dotfilesProfile) {
    . $dotfilesProfile
} elseif (Test-Path -Path $legacyProfile) {
    . $legacyProfile
}
Remove-Variable -Name dotfilesClone, dotfilesProfile, legacyProfile -ErrorAction Ignore
'@
        }
    )
}

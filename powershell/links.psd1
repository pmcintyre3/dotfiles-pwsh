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
} else {
    Write-Warning "dotfiles: no clone at $dotfilesClone and no legacy profile next to this file; nothing loaded. Run the dotfiles-pwsh one-liner to set up this machine."
}
Remove-Variable -Name dotfilesClone, dotfilesProfile, legacyProfile -ErrorAction Ignore
'@
        }
    )
}

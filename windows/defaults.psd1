# Windows defaults applied by windows/install.ps1. Settings are DWORD values mirroring Raijin as of 2026-10-08.
# User = HKCU, applied on every run. Machine = HKLM, applied only by `dot -Elevated` (or inline with Elevation = 'Auto').
@{
    Settings = @(
        @{ Scope = 'User'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name = 'HideFileExt'; Value = 0; Description = 'Explorer shows file extensions' }
        @{ Scope = 'User'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name = 'Hidden'; Value = 1; Description = 'Explorer shows hidden files' }
        @{ Scope = 'User'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name = 'LaunchTo'; Value = 1; Description = 'Explorer opens to This PC' }
        @{ Scope = 'User'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'; Name = 'AppsUseLightTheme'; Value = 0; Description = 'Dark mode for apps' }
        @{ Scope = 'User'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'; Name = 'SystemUsesLightTheme'; Value = 0; Description = 'Dark mode for Windows' }
        @{ Scope = 'Machine'; Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem'; Name = 'LongPathsEnabled'; Value = 1; Description = 'Paths longer than 260 characters' }
        @{ Scope = 'Machine'; Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock'; Name = 'AllowDevelopmentWithoutDevLicense'; Value = 1; Description = 'Developer Mode (lets dotfiles create symlinks without admin)' }
    )

    # Per-user folder-type view overrides (always User scope). windows/install.ps1 copies the Windows definition
    # (HKLM\...\Explorer\FolderTypes\{Guid}) to HKCU once, then sets GroupBy on its views; Explorer prefers the
    # HKCU copy. Same approach as WinSetView. Folders already opened change after `dot -ResetExplorerViews`.
    # Downloads ships with GroupBy = System.DateModified. Verified on Raijin 2026-10-09: Downloads and its
    # subfolders ungrouped; Documents and Pictures unaffected.
    FolderTypes = @(
        @{ Guid = '{885a186e-a440-4ada-812b-db871b942259}'; GroupBy = ''; Description = 'Downloads folders not grouped by date' }
    )
}

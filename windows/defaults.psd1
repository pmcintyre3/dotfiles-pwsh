# Windows defaults applied by windows/install.ps1 (DWORD values). Values mirror Raijin as of 2026-10-08,
# except GroupView (new: Raijin's Downloads still groups by date).
# User = HKCU, applied on every run. Machine = HKLM, applied only by `dot -Elevated` (or inline with Elevation = 'Auto').
@{
    Settings = @(
        @{ Scope = 'User'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name = 'HideFileExt'; Value = 0; Description = 'Explorer shows file extensions' }
        @{ Scope = 'User'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name = 'Hidden'; Value = 1; Description = 'Explorer shows hidden files' }
        @{ Scope = 'User'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name = 'LaunchTo'; Value = 1; Description = 'Explorer opens to This PC' }
        @{ Scope = 'User'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'; Name = 'AppsUseLightTheme'; Value = 0; Description = 'Dark mode for apps' }
        @{ Scope = 'User'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'; Name = 'SystemUsesLightTheme'; Value = 0; Description = 'Dark mode for Windows' }
        # Downloads folder type ({885A186E-...}) defaults to "group by date". This is the per-user view template for that
        # folder type (where Explorer's "Apply to Folders" saves), with grouping off. Folders already opened keep their
        # remembered view until `dot -ResetExplorerViews`. If Downloads still groups after that, add Mode/LogicalViewMode
        # here, or use HKCU Explorer\FolderTypes\...\TopViews GroupBy = '' instead (what WinSetView does).
        @{ Scope = 'User'; Path = 'HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\Shell\Bags\AllFolders\Shell\{885A186E-A440-4ADA-812B-DB871B942259}'; Name = 'GroupView'; Value = 0; Description = 'Downloads folders not grouped by date' }
        @{ Scope = 'Machine'; Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem'; Name = 'LongPathsEnabled'; Value = 1; Description = 'Paths longer than 260 characters' }
        @{ Scope = 'Machine'; Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock'; Name = 'AllowDevelopmentWithoutDevLicense'; Value = 1; Description = 'Developer Mode (lets dotfiles create symlinks without admin)' }
    )
}

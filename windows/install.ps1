#Requires -Version 7.4
<#
.SYNOPSIS
    windows topic installer: apply windows/defaults.psd1. User (HKCU) settings every run; Machine (HKLM)
    settings only when elevated and allowed by Elevation (-MachineOnly from `dot -Elevated`, or 'Auto').
#>
[CmdletBinding()]
param(
    [string] $Root = (Split-Path -Path $PSScriptRoot -Parent),
    [string] $SettingsPath = (Join-Path $PSScriptRoot 'defaults.psd1'),
    [string] $FolderTypesSource = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FolderTypes',
    [string] $FolderTypesTarget = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\FolderTypes',
    [switch] $MachineOnly
)

Import-Module (Join-Path $PSScriptRoot '..\lib\DotfilesTools.psm1')

$config = Read-DotfilesConfig -Root $Root
$machineAllowed = $config.Elevation -ne 'Never' -and (Test-IsAdmin) -and ($MachineOnly -or $config.Elevation -eq 'Auto')
$definitions = Import-PowerShellDataFile -Path $SettingsPath
$settings = $definitions.Settings

$changed = 0
foreach ($setting in $settings) {
    if ($MachineOnly -and $setting.Scope -ne 'Machine') { continue }

    $current = (Get-ItemProperty -Path $setting.Path -Name $setting.Name -ErrorAction Ignore).($setting.Name)
    if ($null -ne $current -and $current -eq $setting.Value) { continue }

    if ($setting.Scope -eq 'Machine' -and -not $machineAllowed) {
        Write-Status -Level Skip -Message "$($setting.Description): needs admin; run dot -Elevated"
        continue
    }

    if (-not (Test-Path -Path $setting.Path)) { New-Item -Path $setting.Path -Force | Out-Null }
    New-ItemProperty -Path $setting.Path -Name $setting.Name -Value $setting.Value -PropertyType DWord -Force | Out-Null
    $changed++
    Write-Status -Level Success -Message $setting.Description
}

# Per-user folder-type view overrides: Explorer prefers HKCU\...\Explorer\FolderTypes\{type} over the Windows
# definition in HKLM. Copy the definition once (keeping any later tweaks to the copy), then set GroupBy.
if (-not $MachineOnly) {
    foreach ($folderType in $definitions.FolderTypes) {
        $target = Join-Path $FolderTypesTarget $folderType.Guid
        if (-not (Test-Path -Path $target)) {
            $source = Join-Path $FolderTypesSource $folderType.Guid
            if (-not (Test-Path -Path $source)) {
                Write-Status -Level Skip -Message "$($folderType.Description): this Windows version has no folder type $($folderType.Guid)"
                continue
            }
            if (-not (Test-Path -Path $FolderTypesTarget)) { New-Item -Path $FolderTypesTarget -Force | Out-Null }
            Copy-Item -Path $source -Destination $FolderTypesTarget -Recurse
        }

        $updated = $false
        foreach ($view in Get-ChildItem -Path (Join-Path $target 'TopViews') -ErrorAction Ignore) {
            if ((Get-ItemProperty -Path $view.PSPath -Name 'GroupBy' -ErrorAction Ignore).GroupBy -ne $folderType.GroupBy) {
                Set-ItemProperty -Path $view.PSPath -Name 'GroupBy' -Value $folderType.GroupBy
                $updated = $true
            }
        }
        if ($updated) {
            $changed++
            Write-Status -Level Success -Message "$($folderType.Description) (folders already opened change after dot -ResetExplorerViews)"
        }
    }
}

if ($changed) {
    Write-Status -Level User -Message 'Some Windows settings take effect after you restart Explorer or sign out.'
} else {
    Write-Status -Level Skip -Message 'Windows settings already as configured'
}

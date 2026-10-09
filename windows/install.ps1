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
    [switch] $MachineOnly
)

Import-Module (Join-Path $PSScriptRoot '..\lib\DotfilesTools.psm1')

$config = Read-DotfilesConfig -Root $Root
$machineAllowed = $config.Elevation -ne 'Never' -and (Test-IsAdmin) -and ($MachineOnly -or $config.Elevation -eq 'Auto')
$settings = (Import-PowerShellDataFile -Path $SettingsPath).Settings

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

if ($changed) {
    Write-Status -Level User -Message 'Some Windows settings take effect after you restart Explorer or sign out.'
} else {
    Write-Status -Level Skip -Message 'Windows settings already as configured'
}

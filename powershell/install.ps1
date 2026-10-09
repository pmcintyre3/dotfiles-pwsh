#Requires -Version 7.4
<#
.SYNOPSIS
    powershell topic installer: CurrentUser execution policy, gallery modules, and scripts. No admin needed.
#>
[CmdletBinding()]
param(
    [string] $Root = (Split-Path -Path $PSScriptRoot -Parent),
    [string] $ManifestPath = (Join-Path $PSScriptRoot 'modules.psd1')
)

Import-Module (Join-Path $PSScriptRoot '..\lib\DotfilesTools.psm1') -Force
$config = Read-DotfilesConfig -Root $Root

# Only set a policy when the user has none; never loosen or tighten one they chose.
if ((Get-ExecutionPolicy -Scope CurrentUser) -in 'Undefined', 'Restricted') {
    try {
        Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force -ErrorAction Stop
        Write-Status -Level Success -Message 'Execution policy: RemoteSigned (CurrentUser)'
    } catch {
        Write-Status -Level Skip -Message "Execution policy not changed: $($_.Exception.Message)"
    }
}

$manifest = Import-PowerShellDataFile -Path $ManifestPath
$failed = 0

foreach ($module in $manifest.Modules) {
    if (Get-Module -ListAvailable -Name $module.Name) {
        Write-Status -Level Skip -Message "Module $($module.Name) already installed"
        continue
    }
    try {
        Install-PSResource -Name $module.Name -Repository $config.PSRepository -Scope CurrentUser -TrustRepository -Quiet -ErrorAction Stop
        Write-Status -Level Success -Message "Installed module $($module.Name)"
    } catch {
        $failed++
        Write-Status -Level Fail -Message "Module $($module.Name): $($_.Exception.Message)"
    }
}

$scriptsDir = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'PowerShell\Scripts'
foreach ($scriptName in $manifest.Scripts) {
    if (Test-Path -Path (Join-Path $scriptsDir "$scriptName.ps1")) {
        Write-Status -Level Skip -Message "Script $scriptName already installed"
        continue
    }
    try {
        Install-PSResource -Name $scriptName -Repository $config.PSRepository -Scope CurrentUser -TrustRepository -Quiet -ErrorAction Stop
        Write-Status -Level Success -Message "Installed script $scriptName"
    } catch {
        $failed++
        Write-Status -Level Fail -Message "Script ${scriptName}: $($_.Exception.Message)"
    }
}

if ($failed) { throw "$failed install(s) failed" }

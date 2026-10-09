#Requires -Version 7.4
<#
.SYNOPSIS
    Machine-wide steps only, for `dot -Elevated`. The elevated process may run as a different account
    (a standard user typing admin credentials), so this never touches HKCU, $HOME, links, or the profile:
    it runs only topic installers that declare -MachineOnly, passing -MachineOnly.
#>
[CmdletBinding()]
param(
    [string] $Root = (Split-Path -Path $PSScriptRoot -Parent),
    [string] $LogPath,
    [switch] $Upgrade
)

Import-Module (Join-Path $PSScriptRoot '..\lib\DotfilesTools.psm1') -Force

if (-not (Test-IsAdmin)) { throw 'script\elevated.ps1 must run elevated. Use: dot -Elevated' }

if ($LogPath) { Start-Transcript -Path $LogPath -Force | Out-Null }
$exitCode = 0
try {
    $config = Read-DotfilesConfig -Root $Root
    if ($config.Elevation -eq 'Never') {
        Write-Status -Level Skip -Message "Elevation is 'Never' in dotfiles.local.psd1, so nothing machine-wide was changed."
    } else {
        foreach ($topic in Get-DotfilesTopic -Root $Root -ExcludeTopics $config.ExcludeTopics) {
            $installer = Join-Path $topic.FullName 'install.ps1'
            if (-not (Test-Path -Path $installer)) { continue }
            $parameters = (Get-Command -Name $installer).Parameters
            if (-not $parameters.ContainsKey('MachineOnly')) { continue }
            $installerParams = @{ MachineOnly = $true }
            if ($Upgrade -and $parameters.ContainsKey('Upgrade')) { $installerParams.Upgrade = $true }

            Write-Status -Level Info -Message "Running $($topic.Name)\install.ps1 -MachineOnly$(if ($installerParams.Upgrade) { ' -Upgrade' })"
            try {
                & $installer @installerParams | Out-Host
            } catch {
                $exitCode = 1
                Write-Status -Level Fail -Message "$($topic.Name)\install.ps1 -MachineOnly: $($_.Exception.Message)"
            }
        }
    }
} finally {
    if ($LogPath) { Stop-Transcript | Out-Null }
}
exit $exitCode

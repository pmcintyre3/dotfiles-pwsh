#Requires -Version 7.4
<#
.SYNOPSIS
    Run every enabled topic's install.ps1 (Haacked's script/install). One failure doesn't stop the rest.
    -Upgrade is passed only to installers that declare an Upgrade parameter.
#>
[CmdletBinding()]
param(
    [string] $Root = (Split-Path -Path $PSScriptRoot -Parent),
    [switch] $Upgrade
)

Import-Module (Join-Path $PSScriptRoot '..\lib\DotfilesTools.psm1') -Force
$config = Read-DotfilesConfig -Root $Root

foreach ($topic in Get-DotfilesTopic -Root $Root -ExcludeTopics $config.ExcludeTopics) {
    $installer = Join-Path $topic.FullName 'install.ps1'
    if (-not (Test-Path -Path $installer)) { continue }

    $installerParams = @{}
    if ($Upgrade -and (Get-Command -Name $installer).Parameters.ContainsKey('Upgrade')) { $installerParams.Upgrade = $true }

    Write-Status -Level Info -Message "Running $($topic.Name)\install.ps1"
    try {
        & $installer @installerParams | Out-Host
        [pscustomobject]@{ Topic = $topic.Name; Succeeded = $true; Error = $null }
    } catch {
        Write-Status -Level Fail -Message "$($topic.Name)\install.ps1: $($_.Exception.Message)"
        [pscustomobject]@{ Topic = $topic.Name; Succeeded = $false; Error = $_.Exception.Message }
    }
}

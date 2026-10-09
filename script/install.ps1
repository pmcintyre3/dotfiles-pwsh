#Requires -Version 7.4
<#
.SYNOPSIS
    Run every enabled topic's install.ps1 (Haacked's script/install). One failure doesn't stop the rest.
#>
[CmdletBinding()]
param([string] $Root = (Split-Path -Path $PSScriptRoot -Parent))

Import-Module (Join-Path $PSScriptRoot '..\lib\DotfilesTools.psm1') -Force
$config = Read-DotfilesConfig -Root $Root

foreach ($topic in Get-DotfilesTopic -Root $Root -ExcludeTopics $config.ExcludeTopics) {
    $installer = Join-Path $topic.FullName 'install.ps1'
    if (-not (Test-Path -Path $installer)) { continue }

    Write-Status -Level Info -Message "Running $($topic.Name)\install.ps1"
    try {
        & $installer | Out-Host
        [pscustomobject]@{ Topic = $topic.Name; Succeeded = $true; Error = $null }
    } catch {
        Write-Status -Level Fail -Message "$($topic.Name)\install.ps1: $($_.Exception.Message)"
        [pscustomobject]@{ Topic = $topic.Name; Succeeded = $false; Error = $_.Exception.Message }
    }
}

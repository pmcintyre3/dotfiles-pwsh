#Requires -Version 7.4
<#
.SYNOPSIS
    ai topic installer: merge the managed Claude Code settings (ai/claude/settings.json) into ~/.claude/settings.json.
    Only managed keys are set; everything else Claude Code writes is kept. Never touches credentials, ~/.claude.json,
    plugins, projects (memory), or claude.ai-synced skills. Exclude the topic on machines that shouldn't get it.
#>
[CmdletBinding()]
param(
    [string] $Root = (Split-Path -Path $PSScriptRoot -Parent),
    [string] $SettingsPath = (Join-Path $HOME '.claude\settings.json'),
    [string] $ManagedPath = (Join-Path $PSScriptRoot 'claude\settings.json')
)

Import-Module (Join-Path $PSScriptRoot '..\lib\DotfilesTools.psm1')

$claudeDir = Split-Path -Path $SettingsPath -Parent
if (-not (Test-Path -Path $claudeDir)) {
    Write-Status -Level Skip -Message "Claude Code isn't set up here ($claudeDir doesn't exist); skipping"
    return
}

$result = Merge-JsonSettings -Path $SettingsPath -ManagedPath $ManagedPath -BackupDir (Join-Path $Root '.state')
switch ($result.Action) {
    'Created'   { Write-Status -Level Success -Message "Created $SettingsPath from ai\claude\settings.json" }
    'Updated'   { Write-Status -Level Success -Message "Updated managed Claude Code settings (previous copy: $($result.BackupPath))" }
    'Unchanged' { Write-Status -Level Skip -Message 'Claude Code settings already as configured' }
    'Failed'    { throw $result.Reason }
}

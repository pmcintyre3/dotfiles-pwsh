#Requires -Version 7.4
<#
.SYNOPSIS
    Set up this machine: probe, create *.local files from templates, link files, run installers.
    Safe to re-run. Never requires admin. See design.md section 4.
.PARAMETER TokenMap
    Overrides for link target tokens (~, {PROFILE}, ...). Tests use it to stay out of the real $HOME and $PROFILE.
#>
[CmdletBinding()]
param(
    [ValidateSet('Prompt', 'Skip', 'Overwrite', 'Backup')] [string] $ConflictAction = 'Prompt',
    [switch] $SkipInstall,
    [switch] $SkipNetwork,
    [hashtable] $TokenMap = @{},
    [string] $Root = (Split-Path -Path $PSScriptRoot -Parent)
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '..\lib\DotfilesTools.psm1') -Force
Reset-DotLinkPrompt

Write-Status -Level Info -Message "dotfiles root: $Root"
$expectedRoot = Join-Path $HOME '.dotfiles'
if ($TokenMap.Count -eq 0 -and $Root.TrimEnd('\') -ne $expectedRoot) {
    Write-Status -Level User -Message "This clone isn't at $expectedRoot. The `$PROFILE stub only finds it there (or via `$env:DOTFILES_ROOT)."
}

# 1. Probe.
$capability = Get-MachineCapability -SkipNetwork:$SkipNetwork
Write-Status -Level Info -Message ('Admin: {0} | Symlinks: {1} | Developer Mode: {2} | Language: {3} | Execution policy: {4}{5}' -f
    $capability.IsAdmin, $capability.CanSymlink, $capability.DeveloperMode, $capability.LanguageMode,
    $capability.ExecutionPolicy, $(if ($capability.PolicyFromGpo) { ' (Group Policy)' } else { '' }))
if ($capability.LanguageMode -ne 'FullLanguage') {
    Write-Status -Level Fail -Message "PowerShell is in $($capability.LanguageMode) mode (AppLocker/WDAC). Much of the profile won't work."
}
if ($capability.PolicyFromGpo -and $capability.ExecutionPolicy -in 'AllSigned', 'Restricted') {
    Write-Status -Level Fail -Message "Group Policy sets the execution policy to $($capability.ExecutionPolicy). Unsigned profile scripts won't run."
}

# 2. Machine-local files from templates (never overwritten).
Get-ChildItem -Path $Root -Filter '*.template' -File -Recurse | ForEach-Object {
    if (New-LocalFileFromTemplate -TemplatePath $_.FullName) {
        Write-Status -Level Success -Message "Created $($_.FullName.Substring($Root.Length + 1) -replace '\.template$', '')"
    }
}

# 3. Links.
$config = Read-DotfilesConfig -Root $Root
$topics = @(Get-DotfilesTopic -Root $Root -ExcludeTopics $config.ExcludeTopics)
$links = @(Invoke-DotLinks -Topic $topics -ConflictAction $ConflictAction -TokenMap $TokenMap -Capability $capability)
foreach ($link in $links) {
    switch ($link.Action) {
        'AlreadyLinked' { Write-Status -Level Skip -Message "$($link.Target) already linked" }
        'Skipped'       { Write-Status -Level Skip -Message "$($link.Target): $($link.Reason)" }
        'Failed'        { Write-Status -Level Fail -Message "$($link.Target): $($link.Reason)" }
        default         { Write-Status -Level Success -Message "$($link.Target) ($($link.Method), $($link.Action))" }
    }
}

# 4. Topic installers.
$installs = @()
if (-not $SkipInstall) {
    $installs = @(& (Join-Path $PSScriptRoot 'install.ps1') -Root $Root)
}

# 5. Summary.
$failedLinks = @($links | Where-Object { $_.Action -eq 'Failed' }).Count
$failedInstalls = @($installs | Where-Object { -not $_.Succeeded }).Count
if ($failedLinks + $failedInstalls -gt 0) {
    Write-Status -Level Fail -Message "Done with problems: $failedLinks link(s) and $failedInstalls installer(s) failed. Fix them and re-run (safe to repeat)."
    exit 1
}
Write-Status -Level Success -Message 'Done. Open a new terminal to load the profile.'
exit 0

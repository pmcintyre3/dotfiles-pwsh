#Requires -Version 7.4
<#
.SYNOPSIS
    Create git/gitconfig.local (this machine's identity and commit signing) if it doesn't exist.
    Run by script/bootstrap.ps1 before linking, so the current ~/.gitconfig values can seed it.
#>
[CmdletBinding()]
param(
    [hashtable] $TokenMap = @{},
    [string] $LocalPath = (Join-Path $PSScriptRoot 'gitconfig.local')
)

Import-Module (Join-Path $PSScriptRoot '..\lib\DotfilesTools.psm1')

if (Test-Path -Path $LocalPath) { return }

$currentConfig = Resolve-DotPath -Path '~\.gitconfig' -TokenMap $TokenMap
$values = [ordered]@{}
foreach ($key in 'user.name', 'user.email', 'user.signingkey', 'gpg.format', 'gpg.ssh.program', 'commit.gpgsign') {
    if (-not (Test-Path -Path $currentConfig)) { break }
    $value = git config --file $currentConfig --get $key 2>$null
    if ($LASTEXITCODE -eq 0 -and $value) { $values[$key] = $value }
}

foreach ($key in 'user.name', 'user.email') {
    if ($values.Contains($key) -or -not (Test-CanPrompt)) { continue }
    $answer = Read-Host "git $key for this machine"
    if ($answer) { $values[$key] = $answer }
}

Set-Content -Path $LocalPath -Value "# This machine's git identity and commit signing. Not committed. Created by git/local.ps1."
foreach ($key in $values.Keys) {
    git config --file $LocalPath $key $values[$key]
}
Write-Status -Level Success -Message "Created git\gitconfig.local ($(if ($values.Count) { @($values.Keys) -join ', ' } else { 'empty' }))"

foreach ($key in 'user.name', 'user.email') {
    if (-not $values.Contains($key)) {
        Write-Status -Level User -Message "git $key isn't set. Run: git config --file `"$LocalPath`" $key <value>"
    }
}

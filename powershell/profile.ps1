# dotfiles-pwsh profile loader. Dot-sourced by the $PROFILE stub (see powershell/links.psd1).
# Load order and rules: design.md section 3. Keep this file small; behavior belongs in topic files.

$global:DotfilesRoot = Split-Path -Path $PSScriptRoot -Parent
Import-Module (Join-Path $global:DotfilesRoot 'lib\DotfilesTools.psm1')

try {
    $dotfilesConfig = Read-DotfilesConfig -Root $global:DotfilesRoot
} catch {
    Write-Warning "dotfiles: $($_.Exception.Message). Loading every topic."
    $dotfilesConfig = @{ ExcludeTopics = @() }
}

foreach ($dotfilesScript in Get-DotfilesProfileScript -Root $global:DotfilesRoot -ExcludeTopics $dotfilesConfig.ExcludeTopics) {
    try {
        . $dotfilesScript.FullName
    } catch {
        Write-Warning "dotfiles: failed to load '$($dotfilesScript.FullName)': $($_.Exception.Message)"
    }
}

Remove-Variable -Name dotfilesConfig, dotfilesScript -ErrorAction Ignore

#Requires -Version 7.4
<#
.SYNOPSIS
    Lint (PSScriptAnalyzer) and test (Pester) the repo. Exits 1 on any finding or failure.
#>
[CmdletBinding()]
param(
    [switch] $Lint,
    [switch] $Test
)

$root = Split-Path -Path $PSScriptRoot -Parent
if (-not $Lint -and -not $Test) { $Lint = $true; $Test = $true }
$failed = $false

if ($Lint) {
    Import-Module PSScriptAnalyzer -ErrorAction Stop
    $settings = Join-Path $root 'PSScriptAnalyzerSettings.psd1'
    $files = Get-ChildItem -Path $root -Recurse -File -Include '*.ps1', '*.psm1', '*.psd1' |
        Where-Object { $_.FullName -notmatch '\tests\' }
    $issues = $files | ForEach-Object { Invoke-ScriptAnalyzer -Path $_.FullName -Settings $settings }
    if ($issues) {
        $issues | Format-Table RuleName, Severity, ScriptName, Line, Message -AutoSize -Wrap | Out-Host
        $failed = $true
    } else {
        Write-Host 'PSScriptAnalyzer: no findings'
    }
}

if ($Test) {
    Import-Module Pester -MinimumVersion 5.5 -ErrorAction Stop
    $config = New-PesterConfiguration
    $config.Run.Path = Join-Path $root 'tests'
    $config.Run.PassThru = $true
    $config.Output.Verbosity = 'Detailed'
    $result = Invoke-Pester -Configuration $config
    if ($result.FailedCount -gt 0) { $failed = $true }
}

if ($failed) { exit 1 }

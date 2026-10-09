#Requires -Version 7.4
<#
.SYNOPSIS
    vscode topic installer: install extensions listed in extensions.txt that aren't installed yet.
    Never uninstalls. VS Code Settings Sync owns settings and keybindings; this covers machines without it.
#>
[CmdletBinding()]
param(
    [string] $ExtensionsPath = (Join-Path $PSScriptRoot 'extensions.txt'),
    [string] $CodeCommand = 'code'
)

Import-Module (Join-Path $PSScriptRoot '..\lib\DotfilesTools.psm1')

if (-not (Get-Command -Name $CodeCommand -ErrorAction Ignore)) {
    Write-Status -Level Skip -Message "VS Code CLI ($CodeCommand) not found; skipping extensions"
    return
}

$wanted = @(Get-Content -Path $ExtensionsPath | ForEach-Object { $_.Trim() } | Where-Object { $_ -and -not $_.StartsWith('#') })
$installed = @(& $CodeCommand --list-extensions 2>$null)
$missing = @($wanted | Where-Object { $_ -notin $installed })
$extra = @($installed | Where-Object { $_ -notin $wanted })

$failed = 0
foreach ($id in $missing) {
    & $CodeCommand --install-extension $id 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-Status -Level Success -Message "Installed VS Code extension $id"
    } else {
        $failed++
        Write-Status -Level Fail -Message "VS Code extension $id failed to install (exit $LASTEXITCODE)"
    }
}

if ($extra) {
    Write-Status -Level User -Message "$($extra.Count) installed VS Code extension(s) aren't in vscode\extensions.txt. To save them: code --list-extensions | Set-Content `"$ExtensionsPath`""
}
if (-not $missing -and -not $extra) {
    Write-Status -Level Skip -Message "VS Code extensions up to date ($($wanted.Count))"
}
if ($failed) { throw "$failed VS Code extension install(s) failed" }

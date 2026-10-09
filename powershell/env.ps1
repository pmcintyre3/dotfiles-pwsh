# Defaults for anything powershell/profile.local.ps1 didn't set. Use ??= so local values win.
# ($env:ProfileName is the exception: it always reflects this machine's host name.)

$env:ProjectHome ??= 'C:\Projects'
$env:ProfileName = [System.Net.Dns]::GetHostName()
$env:PYTHONIOENCODING ??= 'utf-8'

$global:ProjectPaths ??= @{}
$global:ProjectPaths['Source']         ??= $env:ProjectHome
$global:ProjectPaths['PowerShellHome'] ??= $global:DotfilesRoot
$global:ProjectPaths['Workspace']      ??= $env:ProjectHome
$global:ProjectPaths['Credentials']    ??= Join-Path $env:ProjectHome 'Credentials'
$global:ProjectPaths['Tools']          ??= 'C:\Tools'
# $true puts every Tools subfolder on PATH (legacy Ryuujin behavior); otherwise only versioned tools.
$global:ProjectPaths['AllToolsOnPath'] ??= $false

# Defaults for anything powershell/profile.local.ps1 didn't set. Only use ??= here, so local values win.

$env:ProjectHome ??= 'C:\Projects'
$env:ProfileName = [System.Net.Dns]::GetHostName()
$env:PYTHONIOENCODING = 'utf-8'

$global:ProjectPaths ??= @{}
$global:ProjectPaths['Source']         ??= $env:ProjectHome
$global:ProjectPaths['PowerShellHome'] ??= $global:DotfilesRoot
$global:ProjectPaths['Workspace']      ??= $env:ProjectHome
$global:ProjectPaths['Credentials']    ??= Join-Path $env:ProjectHome 'Credentials'
$global:ProjectPaths['Tools']          ??= 'C:\Tools'

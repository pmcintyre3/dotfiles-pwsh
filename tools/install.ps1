#Requires -Version 7.4
<#
.SYNOPSIS
    tools topic installer: give OpenSSL a config file when OpenSSL is installed. tools/env.ps1 points
    OPENSSL_CONF at it. Does nothing on machines without OpenSSL; never replaces an existing config.
#>
[CmdletBinding()]
param(
    [string[]] $OpenSslRoots = @('C:\Program Files\OpenSSL-Win64', 'C:\Program Files\OpenSSL'),
    [string] $ConfPath = 'C:\certs\openssl.cnf',
    [string] $ConfUrl = 'https://raw.githubusercontent.com/openssl/openssl/master/apps/openssl.cnf'
)

Import-Module (Join-Path $PSScriptRoot '..\lib\DotfilesTools.psm1')

if (-not ($OpenSslRoots | Where-Object { Test-Path -Path $_ })) {
    Write-Status -Level Skip -Message 'OpenSSL not installed; no openssl.cnf needed'
    return
}
if (Test-Path -Path $ConfPath) {
    Write-Status -Level Skip -Message "$ConfPath already exists"
    return
}

New-Item -ItemType Directory -Path (Split-Path -Path $ConfPath -Parent) -Force | Out-Null
Invoke-WebRequest -Uri $ConfUrl -OutFile $ConfPath -UseBasicParsing
Write-Status -Level Success -Message "Downloaded $ConfPath"

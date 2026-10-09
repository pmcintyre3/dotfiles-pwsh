# OpenSSL config (written once by tools/install.ps1 in Phase 2; picked up here if present).
$opensslConf = 'C:\certs\openssl.cnf'
if (Test-Path -Path $opensslConf) {
    $env:OPENSSL_CONF = $opensslConf
    $global:ProjectPaths['SSLCredentials'] = $opensslConf
}
Remove-Variable -Name opensslConf

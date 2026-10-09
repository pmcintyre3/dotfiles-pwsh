# OpenSSL config (written once by tools/install.ps1 in Phase 2; picked up here if present).
# Wrapped in a script block so its temporaries never touch the user's variables.
& {
    $opensslConf = 'C:\certs\openssl.cnf'
    if (Test-Path -Path $opensslConf) {
        $env:OPENSSL_CONF = $opensslConf
        $global:ProjectPaths['SSLCredentials'] = $opensslConf
    }
}

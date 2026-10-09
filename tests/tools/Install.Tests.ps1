BeforeAll {
    $installer = Join-Path $PSScriptRoot '..\..\tools\install.ps1'
}

Describe 'tools/install.ps1' {
    BeforeEach {
        $dir = Join-Path $TestDrive ([guid]::NewGuid())
        $openssl = Join-Path $dir 'OpenSSL-Win64'
        $conf = Join-Path $dir 'certs\openssl.cnf'
        Mock Invoke-WebRequest { Set-Content -Path $OutFile -Value '# downloaded' }
    }

    It 'does nothing when OpenSSL is not installed' {
        & $installer -OpenSslRoots $openssl -ConfPath $conf 6> $null
        Should -Invoke Invoke-WebRequest -Times 0 -Exactly
        $conf | Should -Not -Exist
    }

    It 'downloads openssl.cnf over HTTPS when OpenSSL is installed and no config exists' {
        New-Item -ItemType Directory -Path $openssl -Force | Out-Null
        & $installer -OpenSslRoots $openssl -ConfPath $conf 6> $null
        Should -Invoke Invoke-WebRequest -Times 1 -Exactly -ParameterFilter { $Uri -like 'https://*' }
        Get-Content -Path $conf | Should -Be '# downloaded'
    }

    It 'never replaces an existing config' {
        New-Item -ItemType Directory -Path $openssl -Force | Out-Null
        New-Item -ItemType Directory -Path (Split-Path $conf) -Force | Out-Null
        Set-Content -Path $conf -Value '# mine'
        & $installer -OpenSslRoots $openssl -ConfPath $conf 6> $null
        Should -Invoke Invoke-WebRequest -Times 0 -Exactly
        Get-Content -Path $conf | Should -Be '# mine'
    }
}

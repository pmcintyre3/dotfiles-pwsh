BeforeAll {
    $installer = Join-Path $PSScriptRoot '..\..\powershell\install.ps1'
}

Describe 'powershell/install.ps1' {
    BeforeEach {
        $root = Join-Path $TestDrive ([guid]::NewGuid())
        New-Item -ItemType Directory -Path $root | Out-Null
        Set-Content -Path (Join-Path $root 'dotfiles.local.psd1') -Value "@{ PSRepository = 'InternalFeed' }"
        $manifest = Join-Path $root 'modules.psd1'
        Set-Content -Path $manifest -Value @'
@{
    Modules = @(
        @{ Name = 'Broken';  Import = 'Auto' }
        @{ Name = 'Present'; Import = 'Auto' }
        @{ Name = 'Missing'; Import = 'Auto' }
    )
}
'@
        Mock Get-ExecutionPolicy { 'RemoteSigned' }
        Mock Set-ExecutionPolicy { }
        Mock Get-Module { [pscustomobject]@{ Name = 'Present' } } -ParameterFilter { $ListAvailable -and $Name -eq 'Present' }
        Mock Get-Module { } -ParameterFilter { $ListAvailable -and $Name -ne 'Present' }
        Mock Install-PSResource { if ($Name -eq 'Broken') { throw 'gallery unreachable' } }
    }

    It 'installs only missing modules, from the configured repository, at CurrentUser scope' {
        { & $installer -Root $root -ManifestPath $manifest 6> $null } | Should -Throw '*1 install(s) failed*'
        Should -Invoke Install-PSResource -Times 1 -Exactly -ParameterFilter {
            $Name -eq 'Missing' -and $Repository -eq 'InternalFeed' -and $Scope -eq 'CurrentUser'
        }
        Should -Invoke Install-PSResource -Times 0 -Exactly -ParameterFilter { $Name -eq 'Present' }
    }

    It 'keeps going after a failed install' {
        { & $installer -Root $root -ManifestPath $manifest 6> $null } | Should -Throw
        Should -Invoke Install-PSResource -Times 1 -Exactly -ParameterFilter { $Name -eq 'Missing' }
    }

    It 'leaves an existing CurrentUser execution policy alone' {
        Set-Content -Path $manifest -Value '@{ Modules = @() }'
        & $installer -Root $root -ManifestPath $manifest 6> $null
        Should -Invoke Set-ExecutionPolicy -Times 0 -Exactly
    }

    It 'sets RemoteSigned when the CurrentUser policy is undefined' {
        Mock Get-ExecutionPolicy { 'Undefined' }
        Set-Content -Path $manifest -Value '@{ Modules = @() }'
        & $installer -Root $root -ManifestPath $manifest 6> $null
        Should -Invoke Set-ExecutionPolicy -Times 1 -Exactly -ParameterFilter {
            $ExecutionPolicy -eq 'RemoteSigned' -and $Scope -eq 'CurrentUser'
        }
    }

    It 'reports, without failing, when Group Policy blocks the change' {
        Mock Get-ExecutionPolicy { 'Undefined' }
        Mock Set-ExecutionPolicy { throw 'overridden by a policy defined at a more specific scope' }
        Set-Content -Path $manifest -Value '@{ Modules = @() }'
        { & $installer -Root $root -ManifestPath $manifest 6> $null } | Should -Not -Throw
    }
}

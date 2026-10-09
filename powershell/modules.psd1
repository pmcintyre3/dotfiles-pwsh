# Gallery modules for every machine. Eager = imported by the profile; Auto = installed only,
# loaded on first use by PowerShell's module autoloader (no startup cost).
@{
    Modules = @(
        @{ Name = 'posh-git';                Import = 'Eager' }   # prompt + git tab completion
        @{ Name = 'Microsoft.WinGet.Client'; Import = 'Auto' }
        @{ Name = 'BurntToast';              Import = 'Auto' }
        @{ Name = 'psInlineProgress';        Import = 'Auto' }
        @{ Name = '7Zip4Powershell';         Import = 'Auto' }
        @{ Name = 'ImportExcel';             Import = 'Auto' }
        @{ Name = 'PSWriteHTML';             Import = 'Auto' }
        @{ Name = 'Configuration';           Import = 'Auto' }
        @{ Name = 'ModuleBuilder';           Import = 'Auto' }
        @{ Name = 'Mdbc';                    Import = 'Auto' }   # was Ryuujin-only
        @{ Name = 'chocolatey';              Import = 'Auto' }   # kept for parity; revisit in Phase 3
    )

    # Gallery scripts (installed to Documents\PowerShell\Scripts).
    Scripts = @(
        'Mdbc.ArgumentCompleters'
    )
}

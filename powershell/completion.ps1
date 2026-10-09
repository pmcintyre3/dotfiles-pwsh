# Eager module imports (modules.psd1, Import = 'Eager') and argument completers.
# Wrapped in a script block so its temporaries never touch the user's variables.
& {
    $moduleManifest = Import-PowerShellDataFile -Path (Join-Path $PSScriptRoot 'modules.psd1')
    foreach ($eagerModule in ($moduleManifest.Modules | Where-Object { $_.Import -eq 'Eager' })) {
        Import-Module -Name $eagerModule.Name -Global -ErrorAction Ignore
        if (-not (Get-Module -Name $eagerModule.Name)) {
            Write-Warning "dotfiles: module '$($eagerModule.Name)' isn't installed. Run 'dot' to install it."
        }
    }

    # Chocolatey tab completion (ships with Chocolatey; https://ch0.co/tab-completion).
    if ($env:ChocolateyInstall) {
        $chocolateyProfile = Join-Path $env:ChocolateyInstall 'helpers\chocolateyProfile.psm1'
        if (Test-Path -Path $chocolateyProfile) { Import-Module $chocolateyProfile -Global }
    }

    # Mdbc argument completers (gallery script, installed by powershell/install.ps1).
    $mdbcCompleter = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'PowerShell\Scripts\Mdbc.ArgumentCompleters.ps1'
    if (Test-Path -Path $mdbcCompleter) { . $mdbcCompleter }
}

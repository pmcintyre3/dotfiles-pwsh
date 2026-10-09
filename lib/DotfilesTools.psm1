# Shared helpers for bootstrap, installers, dot, and the profile loader.
# Each file in DotfilesTools\ holds one area; only the functions listed below are public.
foreach ($file in Get-ChildItem -Path (Join-Path $PSScriptRoot 'DotfilesTools') -Filter '*.ps1') {
    . $file.FullName
}

Export-ModuleMember -Function @(
    'Write-Status'
    'Get-DotfilesRoot'
    'Resolve-DotPath'
    'Read-DotfilesConfig'
    'Get-DotfilesTopic'
    'Get-DotfilesProfileScript'
    'Add-PathEntry'
    'New-LocalFileFromTemplate'
    'Test-IsAdmin'
    'Get-MachineCapability'
    'New-DotLink'
    'Invoke-DotLinks'
    'Reset-DotLinkPrompt'
)

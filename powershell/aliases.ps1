# Explorer / navigation aliases. Functions live in functions/navigation.ps1.
Set-Alias -Name initp -Value Initialize-Profile
Set-Alias -Name '..'  -Value Set-ParentLocation
Set-Alias -Name '...' -Value Set-GrandParentLocation
Set-Alias -Name iii   -Value Open-ExplorerViaII
Set-Alias -Name gui   -Value Open-ExplorerViaII
Set-Alias -Name cl    -Value Set-LocationAndGetChildItem
Set-Alias -Name la    -Value Get-AllChildItems
Set-Alias -Name mkcd  -Value New-ItemAndSetLocation

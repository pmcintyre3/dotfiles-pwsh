# Git helper aliases. Functions live in functions/git.ps1.
# (Legacy `gfc` -> Invoke-GitFullClean is gone: that function was commented out.)
Set-Alias -Name gti     -Value Invoke-MispelledGitCommand
Set-Alias -Name glsb    -Value Get-LocalGitBranches
Set-Alias -Name gfix    -Value Invoke-GitUnsetUpstream
Set-Alias -Name gmg     -Value Merge-UpdatedGitBranch
Set-Alias -Name gmerge  -Value Merge-UpdatedGitBranchFromOrigin
Set-Alias -Name grb     -Value Invoke-GitRebase
Set-Alias -Name grebase -Value Invoke-GitRebaseFromOrigin
Set-Alias -Name grepo   -Value Get-GitRepositoryName

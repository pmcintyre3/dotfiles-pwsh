@{
    Links = @(
        @{
            # No OnConflict: if tools have written to ~/.gitconfig (git config --global), dot asks
            # before replacing it ([b]ackup keeps their lines), and fails rather than guessing when it can't ask.
            Source   = 'gitconfig'
            Target   = '~\.gitconfig'
            Method   = 'Include'
            Template = @'
# Managed by dotfiles-pwsh. Shared: ~/.dotfiles/git/gitconfig. This machine: ~/.dotfiles/git/gitconfig.local
[include]
    path = ~/.dotfiles/git/gitconfig
'@
        }
    )
}

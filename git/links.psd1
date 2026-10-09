@{
    Links = @(
        @{
            # No OnConflict: if tools have written to ~/.gitconfig (git config --global), dot asks
            # before replacing it ([b]ackup keeps their lines), and fails rather than guessing when it can't ask.
            Source   = 'gitconfig'
            Target   = '~\.gitconfig'
            Method   = 'Include'
            # {SourcePosix} is this clone's git/gitconfig with forward slashes, so the include always points
            # at the clone that ran bootstrap (git silently ignores a missing include file).
            Template = @'
# Managed by dotfiles-pwsh. Shared settings: the file below. This machine: gitconfig.local next to it.
[include]
    path = {SourcePosix}
'@
        }
    )
}

@{
    Links = @(
        @{
            # Copied, not linked (no symlinks without admin). dot refreshes it when the repo changes and
            # asks (with [p]ull into repo) when it was edited in VS Code's Keyboard Shortcuts editor.
            Source        = 'keybindings.json'
            Target        = '{APPDATA}\Code\User\keybindings.json'
            Method        = 'Copy'
            RequireParent = $true
        }
    )
}

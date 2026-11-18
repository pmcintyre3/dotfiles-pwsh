@{
    Links = @(
        @{
            # Copied, not linked (no symlinks without admin). dot refreshes it when the repo changes and
            # asks (with [p]ull into repo) when it was edited in Terminal's Settings UI.
            Source        = 'windows-terminal.json'
            Target        = '{LOCALAPPDATA}\Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json'
            Method        = 'Copy'
            RequireParent = $true
        }
    )
}

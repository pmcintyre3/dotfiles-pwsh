@{
    Links = @(
        @{
            # Global Claude Code instructions. Optional: nothing happens until ai/claude/CLAUDE.md exists.
            # Symlink where possible (edits through /memory land in the repo), else copy with the drift check.
            Source        = 'claude\CLAUDE.md'
            Target        = '~\.claude\CLAUDE.md'
            Method        = 'Symlink', 'Copy'
            Optional      = $true
            RequireParent = $true
        }
    )
}

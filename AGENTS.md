# AGENTS.md

Guidance for AI coding agents working in this repo.

## What this is

Windows / PowerShell 7 dotfiles, organized like haacked/dotfiles (topic folders). Each machine clones to
`~\.dotfiles`; `$PROFILE` is a stub that dot-sources `powershell/profile.ps1`.

## Conventions

- A topic is any top-level folder except `script`, `lib`, `bin`, `tests`, and dot-folders. Topics opt in
  only through well-known files: `install.ps1`, `links.psd1`, `env.ps1`, `path.ps1`, `functions/*.ps1`,
  `aliases.ps1`, `completion.ps1`.
- Profile load order: `powershell/profile.local.ps1` → `*/env.ps1` → `*/path.ps1` → `*/functions/*.ps1`
  → `*/aliases.ps1` → `*/completion.ps1`. Within a stage, topics load alphabetically.
- `env.ps1` only sets defaults with `??=`; machine values belong in the gitignored `profile.local.ps1`.
- Profile files never install, hit the network, or prompt. Guard every external tool with `Test-Path` /
  `Get-Command`, and use `-ErrorAction Ignore` for expected misses.
- Shared helpers live in `lib/DotfilesTools/`. Public functions must be added to the
  `Export-ModuleMember` list in `lib/DotfilesTools.psm1`.
- Installers must be idempotent, work without admin, report via `Write-Status`, and throw on failure
  (after trying everything) so `script/install.ps1` records it.
- Never commit `*.local.*` files, `dotfiles.local.psd1`, `gitconfig.local`, backups, or secrets.
  Secrets come from `op read` at call time.
- `install.ps1` at the root must stay Windows PowerShell 5.1 compatible.

## Testing

`./script/test.ps1` runs PSScriptAnalyzer and Pester. Tests must never touch the real `$PROFILE`, `$HOME`,
or machine settings: use `TestDrive`, `Copy-DotfilesRepo` / `Invoke-ProfileProbe` from
`tests/TestHelpers.ps1`, bootstrap's `-TokenMap`, and mocks.

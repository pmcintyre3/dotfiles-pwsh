# dotfiles-pwsh

My Windows / PowerShell 7 dotfiles. They're organized after
[haacked/dotfiles](https://github.com/haacked/dotfiles), which borrowed the approach from
[holman/dotfiles](https://github.com/holman/dotfiles): every concern lives in its own topic folder.

## Install

On a new machine, from Windows PowerShell or PowerShell 7 (no admin needed):

```powershell
irm https://raw.githubusercontent.com/pmcintyre3/dotfiles-pwsh/main/install.ps1 | iex
```

This installs git and PowerShell 7 for the current user if they're missing, clones this repo to
`~\.dotfiles`, and runs `script\bootstrap.ps1`.

By hand:

```powershell
git clone https://github.com/pmcintyre3/dotfiles-pwsh.git $HOME\.dotfiles
& $HOME\.dotfiles\script\bootstrap.ps1
```

To push over SSH afterwards:

```powershell
git -C $HOME\.dotfiles remote set-url origin git@github.com:pmcintyre3/dotfiles-pwsh.git
```

## How it works

- **`$PROFILE` is a stub.** Bootstrap replaces it (after backing it up) with a few lines that dot-source
  `~\.dotfiles\powershell\profile.ps1`. `$PROFILE` lives in OneDrive, so the stub syncs. A machine
  without a clone falls back to `Microsoft.PowerShell_profile.legacy.ps1` next to it, if present.
- **Topics.** Each top-level folder (except `script`, `lib`, `bin`, `tests`) is a topic. A topic opts in
  through well-known file names:

  | File | Purpose |
  |------|---------|
  | `install.ps1` | Run by `script\install.ps1` (bootstrap and `dot`) |
  | `links.psd1` | Files to link into place (include stub, junction, symlink, or copy) |
  | `env.ps1` | Environment defaults (use `??=` so local values win) |
  | `path.ps1` | PATH additions (`Add-PathEntry`) |
  | `functions\*.ps1` | Functions (`*.Tests.ps1` skipped) |
  | `aliases.ps1` | Aliases |
  | `completion.ps1` | Argument completers and eager module imports |

  The profile loads, in order: `powershell\profile.local.ps1`, then every `env.ps1`, `path.ps1`,
  `functions\*.ps1`, `aliases.ps1`, `completion.ps1`. A file that throws is skipped with a warning.
- **Machine-local settings** (gitignored, created from `*.template` by bootstrap):
  - `dotfiles.local.psd1`: `ExcludeTopics`, `Elevation`, `PSRepository`
  - `powershell\profile.local.ps1`: `$env:ProjectHome`, `$ProjectPaths` overrides
- **Secrets** never live in this repo. Fetch them with `op read` inside the function that needs them.
- **No admin required.** Bootstrap probes the machine (admin, symlink rights, execution policy,
  language mode) and picks methods that work. On a locked-down machine it reports what it skipped.

## `dot`

`bin\` is on PATH, so:

```powershell
dot        # git pull --ff-only, then re-run bootstrap (links + installers). Safe to repeat.
dot -e     # open ~\.dotfiles in VS Code
```

## Topics

| Topic | What it does |
|-------|--------------|
| `powershell` | Profile loader, navigation and menu helpers, gallery modules (`modules.psd1`) |
| `git` | Git helper functions and aliases |
| `tools` | PATH entries for OpenSSL, Python, MongoDB, and the `C:\Tools` folder |

## Commands

| Alias | Command | Topic |
|-------|---------|-------|
| `initp` | `Initialize-Profile` | powershell |
| `..` / `...` | `Set-ParentLocation` / `Set-GrandParentLocation` | powershell |
| `cl` | `Set-LocationAndGetChildItem` | powershell |
| `la` | `Get-AllChildItems` | powershell |
| `mkcd` | `New-ItemAndSetLocation` | powershell |
| `iii` / `gui` | `Open-ExplorerViaII` | powershell |
| — | `cdp` (workspace), `cdposh` (this repo) | powershell |
| — | `Get-NetworkDeviceInfo`, `Get-MenuSelection`, `Get-KeyValueMenuSelection` | powershell |
| `gti` | `Invoke-MispelledGitCommand` | git |
| `glsb` | `Get-LocalGitBranches` | git |
| `gfix` | `Invoke-GitUnsetUpstream` | git |
| `gmg` / `gmerge` | `Merge-UpdatedGitBranch` / `Merge-UpdatedGitBranchFromOrigin` | git |
| `grb` / `grebase` | `Invoke-GitRebase` / `Invoke-GitRebaseFromOrigin` | git |
| `grepo` | `Get-GitRepositoryName` | git |

## Development

```powershell
Install-PSResource Pester -Version '[5.5.0,6.0.0)' -Scope CurrentUser -TrustRepository
Install-PSResource PSScriptAnalyzer -Scope CurrentUser -TrustRepository
./script/test.ps1          # lint + tests (CI runs the same on windows-latest)
```

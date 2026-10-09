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
  | `local.ps1` | Creates the topic's machine-local files; run by bootstrap before linking |
  | `links.psd1` | Files to link into place (include stub, junction, symlink, or copy) |
  | `env.ps1` | Environment defaults (use `??=` so local values win) |
  | `path.ps1` | PATH additions (`Add-PathEntry`) |
  | `functions\*.ps1` | Functions (`*.Tests.ps1` skipped) |
  | `aliases.ps1` | Aliases |
  | `completion.ps1` | Argument completers and eager module imports |

  The profile loads, in order: `powershell\profile.local.ps1`, then every `env.ps1`, `path.ps1`,
  `functions\*.ps1`, `aliases.ps1`, `completion.ps1`. A file that throws is skipped with a warning.
- **Machine-local settings** (gitignored, created from `*.template` by bootstrap):
  - `dotfiles.local.psd1`: `ExcludeTopics`, `Elevation`, `PSRepository`, `PackageGroups`
    - `PackageGroups` (`core`, `dev`, `apps`, `personal`) picks which packages this machine gets.
    - `Elevation`: `Never` (no machine-wide changes), `Prompt` (only via `dot -Elevated`),
      `Auto` (also inline when dot already runs elevated).
  - `powershell\profile.local.ps1`: `$env:ProjectHome`, `$ProjectPaths` overrides
- **Copied files and drift.** Files that can't be linked without admin (Windows Terminal settings) are
  copied. Bootstrap remembers what it copied (`.state\`, gitignored): if only the repo changed it
  refreshes the copy; if the live file was edited (e.g. in Terminal's Settings UI) it asks, offering
  **[p]ull into repo** so you can commit the change.
- **`local.ps1` hooks.** A topic with `local.ps1` creates its own machine-local files before linking.
  `git/local.ps1` seeds `gitconfig.local` (name, email, 1Password signing) from your existing `~/.gitconfig`.
- **Secrets** never live in this repo. Fetch them with `op read` inside the function that needs them.
- **No admin required.** Bootstrap probes the machine (admin, symlink rights, execution policy,
  language mode) and picks methods that work. On a locked-down machine it reports what it skipped.

## `dot`

`bin\` is on PATH, so:

```powershell
dot             # git pull --ff-only, then re-run bootstrap (links + installers). Safe to repeat.
dot -Upgrade    # same, and upgrade managed packages
dot -Elevated   # machine-wide steps skipped for lack of admin (one UAC prompt; see Elevation below)
dot -ResetExplorerViews   # forget remembered folder views (backed up to .state\) so defaults apply; restarts Explorer
dot -e          # open ~\.dotfiles in VS Code
```

## Topics

| Topic | What it does |
|-------|--------------|
| `powershell` | Profile loader, navigation and menu helpers, gallery modules (`modules.psd1`) |
| `git` | `~/.gitconfig` → shared `gitconfig` + per-machine `gitconfig.local`; global gitignore; git helper functions and aliases |
| `terminal` | Windows Terminal `settings.json` (copied, with drift check; skipped if Terminal isn't installed) |
| `tools` | PATH entries for OpenSSL, Python, MongoDB, `C:\Tools`; `openssl.cnf` when OpenSSL is installed |
| `packages` | Curated apps and tools (`packages.psd1`): per-user winget first, Scoop fallback, machine-wide only via `dot -Elevated`; groups chosen per machine |
| `vscode` | Installs missing extensions from `extensions.txt` (Settings Sync owns settings and keybindings) |
| `windows` | Explorer and theme defaults, no group-by-date in Downloads (HKCU) every run; long paths and Developer Mode (HKLM) via `dot -Elevated` |

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

### Git config tips

- Change this machine's settings with `git config --file ~/.dotfiles/git/gitconfig.local <key> <value>`.
- Shared settings go in `git/gitconfig` (committed).
- `git config --global` writes into the `~/.gitconfig` stub; `dot` will then ask before replacing it.

## Development

```powershell
Install-PSResource Pester -Version '[5.5.0,6.0.0)' -Scope CurrentUser -TrustRepository
Install-PSResource PSScriptAnalyzer -Scope CurrentUser -TrustRepository
./script/test.ps1          # lint + tests (CI runs the same on windows-latest)
```

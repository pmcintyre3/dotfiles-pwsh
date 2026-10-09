# dotfiles-pwsh

My Windows / PowerShell 7 dotfiles. They're organized after
[haacked/dotfiles](https://github.com/haacked/dotfiles), which borrowed the approach from
[holman/dotfiles](https://github.com/holman/dotfiles): every concern lives in its own topic folder.

## Install on a new machine

Use a normal PowerShell window (Windows PowerShell or PowerShell 7). No admin is needed.

### Option A: one-liner

```powershell
irm https://raw.githubusercontent.com/pmcintyre3/dotfiles-pwsh/main/install.ps1 | iex
```

This installs git and PowerShell 7 for the current user if they're missing, clones this repo to
`~\.dotfiles`, and runs `script\bootstrap.ps1`. That first run installs the **default package groups
(`core` and `dev`)** right away. To choose different groups first, use option B.

### Option B: choose settings before anything installs

Use this on a work machine, or anywhere you don't want the defaults:

```powershell
git clone https://github.com/pmcintyre3/dotfiles-pwsh.git $HOME\.dotfiles
Copy-Item $HOME\.dotfiles\dotfiles.local.psd1.template $HOME\.dotfiles\dotfiles.local.psd1
notepad $HOME\.dotfiles\dotfiles.local.psd1   # set PackageGroups, Elevation, ExcludeTopics
& $HOME\.dotfiles\script\bootstrap.ps1
```

Typical settings:

| Machine | `PackageGroups` | `Elevation` | `ExcludeTopics` |
|---|---|---|---|
| Home | `core`, `dev`, `apps`, `personal` | `Prompt` | none |
| Work laptop | `core`, `dev` | `Never` or `Prompt` | `ai` (and anything else personal) |

### What bootstrap asks and does

- **Git identity:** copies name, email, and 1Password commit signing from the machine's existing
  `~\.gitconfig`. If there's nothing to copy, it asks for your name and email.
- **Existing files** (`~\.gitconfig`, Windows Terminal settings): asks whether to skip, overwrite,
  or back up each one. Back up is the safe choice. `$PROFILE` is always backed up before it becomes the stub.
- **Anything that needs admin** (machine-wide packages, long paths, Developer Mode) is skipped and
  listed, ready for `dot -Elevated`.

### After the first run

1. Edit `~\.dotfiles\powershell\profile.local.ps1` for this machine's paths, for example
   `$env:ProjectHome`, `$global:ProjectPaths.Tools`, and `$global:ProjectPaths.AllToolsOnPath`.
2. Open a new terminal and run `dot`. This also installs VS Code extensions if VS Code was
   installed during the first run.
3. Run `dot -Elevated` once (one UAC prompt) for whatever was skipped for admin. Skip this on
   machines that shouldn't change anything machine-wide.
4. Optional: run `dot -ResetExplorerViews` so already-opened folders lose the group-by-date view.

### Good to know

- **OneDrive:** `$PROFILE` lives in OneDrive, so on a machine that shares OneDrive with one already
  set up, `$PROFILE` is already the stub. Until `~\.dotfiles` exists there, the stub loads
  `Microsoft.PowerShell_profile.legacy.ps1` (the old profile); once you install, it switches over automatically.
- **Pushing changes from a new machine:** commits are signed with 1Password, and the clone uses
  HTTPS. Switch it to SSH once:

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
| `ai` | Claude Code: merges managed keys from `ai/claude/settings.json` (plugins, theme, notifications) into `~/.claude/settings.json`. Managed keys always win (a plugin turned off in Claude Code is turned back on; set it to `false` in the repo instead); every other key Claude Code writes is kept. Links `ai/claude/CLAUDE.md` once it exists. Never touches credentials, `~/.claude.json`, plugins, memory, or synced skills. Exclude it on work machines with `ExcludeTopics = @('ai')` |

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

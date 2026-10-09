# Curated packages (Phase 3, from Raijin's winget export on 2026-10-08). Machines choose groups with
# PackageGroups in dotfiles.local.psd1. Scoop names are fallbacks when winget has no per-user installer.
# Left out on purpose: runtimes/redistributables, drivers, vendor (HP) tools, and preinstalled Windows apps.
@{
    Packages = @(
        # core: every machine
        @{ Name = 'Git';               Group = 'core'; Winget = 'Git.Git';                    Scoop = 'git' }
        @{ Name = 'GitHub CLI';        Group = 'core'; Winget = 'GitHub.cli';                 Scoop = 'gh' }
        @{ Name = 'PowerShell 7';      Group = 'core'; Winget = 'Microsoft.PowerShell';       Scoop = 'pwsh' }
        @{ Name = 'Windows Terminal';  Group = 'core'; Winget = 'Microsoft.WindowsTerminal' }
        @{ Name = '1Password';         Group = 'core'; Winget = 'AgileBits.1Password' }
        @{ Name = '1Password CLI';     Group = 'core'; Winget = 'AgileBits.1Password.CLI';    Scoop = '1password-cli' }
        @{ Name = '7-Zip';             Group = 'core'; Winget = '7zip.7zip';                  Scoop = '7zip' }
        @{ Name = 'Notepad++';         Group = 'core'; Winget = 'Notepad++.Notepad++' }

        # dev: development machines
        @{ Name = 'VS Code';           Group = 'dev'; Winget = 'Microsoft.VisualStudioCode' }
        @{ Name = 'Visual Studio';     Group = 'dev'; Winget = 'Microsoft.VisualStudio.Community' }
        @{ Name = 'Docker Desktop';    Group = 'dev'; Winget = 'Docker.DockerDesktop' }
        @{ Name = 'WSL';               Group = 'dev'; Winget = 'Microsoft.WSL' }
        @{ Name = '.NET 8 SDK';        Group = 'dev'; Winget = 'Microsoft.DotNet.SDK.8' }
        @{ Name = '.NET 9 SDK';        Group = 'dev'; Winget = 'Microsoft.DotNet.SDK.9' }
        @{ Name = 'Temurin JDK 25';    Group = 'dev'; Winget = 'EclipseAdoptium.Temurin.25.JDK' }
        @{ Name = 'NVM for Windows';   Group = 'dev'; Winget = 'CoreyButler.NVMforWindows';  Scoop = 'nvm' }
        @{ Name = 'AWS CLI';           Group = 'dev'; Winget = 'Amazon.AWSCLI';              Scoop = 'aws' }
        @{ Name = 'doctl';             Group = 'dev'; Winget = 'DigitalOcean.Doctl';         Scoop = 'doctl' }
        @{ Name = 'LINQPad 8';         Group = 'dev'; Winget = 'LINQPad.LINQPad.8' }
        @{ Name = 'Claude Code';       Group = 'dev'; Winget = 'Anthropic.ClaudeCode' }
        @{ Name = 'GitHub Copilot CLI'; Group = 'dev'; Winget = 'GitHub.Copilot' }

        # apps: everyday desktop apps
        @{ Name = 'Claude';            Group = 'apps'; Winget = 'Anthropic.Claude' }
        @{ Name = 'Slack';             Group = 'apps'; Winget = 'SlackTechnologies.Slack' }
        @{ Name = 'Teams';             Group = 'apps'; Winget = 'Microsoft.Teams' }
        @{ Name = 'Zoom';              Group = 'apps'; Winget = 'Zoom.Zoom.EXE' }
        @{ Name = 'Telegram';          Group = 'apps'; Winget = 'Telegram.TelegramDesktop' }
        @{ Name = 'Dropbox';           Group = 'apps'; Winget = 'Dropbox.Dropbox' }
        @{ Name = 'Bitwarden';         Group = 'apps'; Winget = 'Bitwarden.Bitwarden' }
        @{ Name = 'Spotify';           Group = 'apps'; Winget = 'Spotify.Spotify' }
        @{ Name = 'Surfshark';         Group = 'apps'; Winget = 'Surfshark.Surfshark' }

        # personal: home machines only
        @{ Name = 'Steam';             Group = 'personal'; Winget = 'Valve.Steam' }
        @{ Name = 'Audacity';          Group = 'personal'; Winget = 'Audacity.Audacity' }
        @{ Name = 'MuseScore';         Group = 'personal'; Winget = 'Musescore.Musescore' }
        @{ Name = 'Muse Hub';          Group = 'personal'; Winget = 'Muse.MuseHub' }
        @{ Name = 'Guitar Pro 8';      Group = 'personal'; Winget = 'ArobasMusic.GuitarPro.8' }
        @{ Name = 'RetroArch';         Group = 'personal'; Winget = 'Libretro.RetroArch' }
        @{ Name = 'PCSX2';             Group = 'personal'; Winget = 'PCSX2Team.PCSX2' }
        @{ Name = 'PS Remote Play';    Group = 'personal'; Winget = 'PlayStation.PSRemotePlay' }
        @{ Name = 'Parsec';            Group = 'personal'; Winget = 'Parsec.Parsec' }
    )
}

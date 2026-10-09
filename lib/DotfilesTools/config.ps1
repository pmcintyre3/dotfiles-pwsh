# Folders at the repo root that are never topics (dot-folders are skipped separately).
$script:NonTopicFolders = 'script', 'lib', 'bin', 'tests'

function Get-DotfilesRoot {
    [CmdletBinding()]
    [OutputType([string])]
    param()

    # This file lives in <root>\lib\DotfilesTools\.
    Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
}

function Resolve-DotPath {
    <#
    .SYNOPSIS
        Expand a links.psd1 target: ~, {PROFILE}, {LOCALAPPDATA}, {APPDATA}. TokenMap overrides (used by tests).
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)] [string] $Path,
        [hashtable] $TokenMap = @{}
    )

    $tokens = @{
        '~'              = $HOME
        # The console host's profile, even when dot runs from another host (VS Code's is Microsoft.VSCode_profile.ps1).
        '{PROFILE}'      = Join-Path (Split-Path -Path $PROFILE.CurrentUserAllHosts -Parent) 'Microsoft.PowerShell_profile.ps1'
        '{LOCALAPPDATA}' = $env:LOCALAPPDATA
        '{APPDATA}'      = $env:APPDATA
    }
    foreach ($key in $TokenMap.Keys) { $tokens[$key] = $TokenMap[$key] }

    foreach ($key in $tokens.Keys) {
        if ($Path -eq $key) { return $tokens[$key] }
        if ($Path.StartsWith("$key\") -or $Path.StartsWith("$key/")) {
            # Path.Combine, not Join-Path: the base may be on a drive that doesn't exist here.
            return [IO.Path]::Combine($tokens[$key], $Path.Substring($key.Length + 1))
        }
    }
    return $Path
}

function Read-DotfilesConfig {
    <#
    .SYNOPSIS
        Install-time settings: defaults merged with the gitignored dotfiles.local.psd1.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param([string] $Root = (Get-DotfilesRoot))

    $config = @{
        ExcludeTopics = @()
        Elevation     = 'Never'
        PSRepository  = 'PSGallery'
    }

    $localPath = Join-Path $Root 'dotfiles.local.psd1'
    if (Test-Path -Path $localPath) {
        try {
            $local = Import-PowerShellDataFile -Path $localPath -ErrorAction Stop
        } catch {
            throw "Invalid dotfiles config '$localPath': $($_.Exception.Message)"
        }
        foreach ($key in $local.Keys) { $config[$key] = $local[$key] }
    }

    if ($config.Elevation -notin 'Never', 'Prompt', 'Auto') {
        throw "Invalid Elevation '$($config.Elevation)' in '$localPath'. Use Never, Prompt, or Auto."
    }
    $config.ExcludeTopics = @($config.ExcludeTopics)
    return $config
}

function Get-DotfilesTopic {
    [CmdletBinding()]
    [OutputType([System.IO.DirectoryInfo])]
    param(
        [string] $Root = (Get-DotfilesRoot),
        [string[]] $ExcludeTopics = @()
    )

    Get-ChildItem -Path $Root -Directory |
        Where-Object {
            $_.Name -notlike '.*' -and
            $_.Name -notin $script:NonTopicFolders -and
            $_.Name -notin $ExcludeTopics
        } |
        Sort-Object -Property Name
}

function Get-DotfilesProfileScript {
    <#
    .SYNOPSIS
        Files the profile dot-sources, in order:
        powershell\profile.local.ps1, */env.ps1, */path.ps1, */functions/*.ps1, */aliases.ps1, */completion.ps1.
    #>
    [CmdletBinding()]
    [OutputType([System.IO.FileInfo])]
    param(
        [string] $Root = (Get-DotfilesRoot),
        [string[]] $ExcludeTopics = @()
    )

    $topics = @(Get-DotfilesTopic -Root $Root -ExcludeTopics $ExcludeTopics)

    $localProfile = Join-Path $Root 'powershell\profile.local.ps1'
    if (Test-Path -Path $localProfile) { Get-Item -Path $localProfile }

    foreach ($name in 'env.ps1', 'path.ps1') {
        foreach ($topic in $topics) {
            $file = Join-Path $topic.FullName $name
            if (Test-Path -Path $file) { Get-Item -Path $file }
        }
    }

    foreach ($topic in $topics) {
        $functionsDir = Join-Path $topic.FullName 'functions'
        if (Test-Path -Path $functionsDir) {
            Get-ChildItem -Path $functionsDir -Filter '*.ps1' -Recurse |
                Where-Object { $_.Name -notlike '*.Tests.ps1' } |
                Sort-Object -Property FullName
        }
    }

    foreach ($name in 'aliases.ps1', 'completion.ps1') {
        foreach ($topic in $topics) {
            $file = Join-Path $topic.FullName $name
            if (Test-Path -Path $file) { Get-Item -Path $file }
        }
    }
}

# Remembered answer from an "all" choice ([S]kip all, [O]verwrite all, [B]ackup all) for this run.
$script:StickyConflictAction = $null

function Reset-DotLinkPrompt {
    [CmdletBinding()]
    param()
    $script:StickyConflictAction = $null
}

function Get-NormalizedText {
    # Private. Compare text ignoring CRLF/LF differences and surrounding whitespace.
    param([string] $Text)
    if ($null -eq $Text) { return '' }
    return ($Text -replace "`r`n", "`n").Trim()
}

function Select-DotLinkMethod {
    # Private. First allowed method this machine and source type support.
    param([string[]] $Allowed, [bool] $SourceIsDirectory, [pscustomobject] $Capability)

    foreach ($method in $Allowed) {
        switch ($method) {
            'Include'  { return 'Include' }
            'Junction' { if ($SourceIsDirectory) { return 'Junction' } }
            'Symlink'  { if ($Capability.CanSymlink) { return 'Symlink' } }
            'Copy'     { if (-not $SourceIsDirectory) { return 'Copy' } }
        }
    }
    return $null
}

function Test-DotLinkCurrent {
    # Private. Is the target already exactly what this link would produce?
    param([string] $Method, [string] $Source, [string] $Target, [string] $Content)

    $item = Get-Item -LiteralPath $Target -Force -ErrorAction Ignore
    if (-not $item) { return $false }

    switch ($Method) {
        'Include' {
            if ($item.PSIsContainer) { return $false }
            return (Get-NormalizedText (Get-Content -LiteralPath $Target -Raw)) -eq (Get-NormalizedText $Content)
        }
        'Symlink' {
            return $item.LinkType -eq 'SymbolicLink' -and "$($item.LinkTarget)".TrimEnd('\') -eq $Source.TrimEnd('\')
        }
        'Junction' {
            return $item.LinkType -eq 'Junction' -and "$($item.LinkTarget)".TrimEnd('\') -eq $Source.TrimEnd('\')
        }
        'Copy' {
            if ($item.PSIsContainer -or $item.LinkType) { return $false }
            return (Get-FileHash -LiteralPath $Target).Hash -eq (Get-FileHash -LiteralPath $Source).Hash
        }
    }
    return $false
}

function Test-CanPrompt {
    # Private. Read-Host returns '' forever on redirected/EOF stdin (Task Scheduler, piped runs),
    # which would spin the conflict prompt; only prompt on a real interactive console.
    return [Environment]::UserInteractive -and -not [Console]::IsInputRedirected
}

function Get-DotLinkConflictAction {
    # Private. Haacked's link_file prompt: [s]kip, [S]kip all, [o]verwrite, [O]verwrite all, [b]ackup, [B]ackup all.
    param([string] $Target, [string] $Requested)

    if ($Requested -ne 'Prompt') { return $Requested }
    if ($script:StickyConflictAction) { return $script:StickyConflictAction }
    if (-not (Test-CanPrompt)) {
        throw "Target exists and this is a non-interactive session, so I can't ask what to do. Re-run interactively or pass -ConflictAction."
    }

    while ($true) {
        $answer = Read-Host "File already exists: $Target. [s]kip, [S]kip all, [o]verwrite, [O]verwrite all, [b]ackup, [B]ackup all"
        switch -CaseSensitive ($answer) {
            's' { return 'Skip' }
            'S' { $script:StickyConflictAction = 'Skip'; return 'Skip' }
            'o' { return 'Overwrite' }
            'O' { $script:StickyConflictAction = 'Overwrite'; return 'Overwrite' }
            'b' { return 'Backup' }
            'B' { $script:StickyConflictAction = 'Backup'; return 'Backup' }
        }
    }
}

function New-DotLink {
    <#
    .SYNOPSIS
        Point Target at Source using the first allowed method this machine supports. Never throws;
        failures come back as Action = 'Failed' with a Reason. See design.md section 5.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)] [string] $Source,
        [Parameter(Mandatory)] [string] $Target,
        [Parameter(Mandatory)] [ValidateSet('Include', 'Junction', 'Symlink', 'Copy')] [string[]] $Method,
        [string] $Template,
        [ValidateSet('Prompt', 'Skip', 'Overwrite', 'Backup')] [string] $ConflictAction = 'Prompt',
        [pscustomobject] $Capability = (Get-MachineCapability -SkipNetwork)
    )

    $result = [pscustomobject]@{ Source = $Source; Target = $Target; Method = $null; Action = $null; Reason = $null; BackupPath = $null }
    try {
        if (-not (Test-Path -LiteralPath $Source)) { throw "Source not found: $Source" }
        $isDirectory = Test-Path -LiteralPath $Source -PathType Container

        $chosen = Select-DotLinkMethod -Allowed $Method -SourceIsDirectory $isDirectory -Capability $Capability
        if (-not $chosen) { throw "None of the allowed methods ($($Method -join ', ')) work on this machine" }
        $result.Method = $chosen

        $content = $null
        if ($chosen -eq 'Include') {
            if (-not $Template) { throw 'Method Include requires a Template' }
            $content = $Template.Replace('{Source}', $Source)
        }

        if (Test-DotLinkCurrent -Method $chosen -Source $Source -Target $Target -Content $content) {
            $result.Action = 'AlreadyLinked'
            return $result
        }

        $action = 'Linked'
        $existing = Get-Item -LiteralPath $Target -Force -ErrorAction Ignore
        if ($existing) {
            switch (Get-DotLinkConflictAction -Target $Target -Requested $ConflictAction) {
                'Skip' {
                    $result.Action = 'Skipped'
                    $result.Reason = 'Target exists'
                    return $result
                }
                'Backup' {
                    $result.BackupPath = "$Target.backup-$(Get-Date -Format yyyyMMddHHmmss)"
                    Move-Item -LiteralPath $Target -Destination $result.BackupPath
                    $action = 'BackedUp'
                }
                'Overwrite' {
                    # Delete a link itself, never what it points to.
                    if ($existing.LinkType) { $existing.Delete() } else { Remove-Item -LiteralPath $Target -Recurse -Force }
                    $action = 'Overwritten'
                }
            }
        }

        $parent = Split-Path -Path $Target -Parent
        if ($parent -and -not (Test-Path -LiteralPath $parent)) {
            New-Item -ItemType Directory -Path $parent -Force | Out-Null
        }

        switch ($chosen) {
            'Include'  { Set-Content -LiteralPath $Target -Value $content }
            'Junction' { New-Item -ItemType Junction -Path $Target -Target $Source | Out-Null }
            'Symlink'  { New-Item -ItemType SymbolicLink -Path $Target -Target $Source | Out-Null }
            'Copy'     { Copy-Item -LiteralPath $Source -Destination $Target }
        }
        $result.Action = $action
    } catch {
        $result.Action = 'Failed'
        $result.Reason = $_.Exception.Message
    }
    return $result
}

function Invoke-DotLinks {
    <#
    .SYNOPSIS
        Apply every entry in each topic's links.psd1. Entry OnConflict overrides -ConflictAction.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)] [System.IO.DirectoryInfo[]] $Topic,
        [ValidateSet('Prompt', 'Skip', 'Overwrite', 'Backup')] [string] $ConflictAction = 'Prompt',
        [hashtable] $TokenMap = @{},
        [pscustomobject] $Capability = (Get-MachineCapability -SkipNetwork)
    )

    foreach ($t in $Topic) {
        $manifest = Join-Path $t.FullName 'links.psd1'
        if (-not (Test-Path -Path $manifest)) { continue }

        foreach ($entry in (Import-PowerShellDataFile -Path $manifest).Links) {
            $action = if ($entry.OnConflict) { $entry.OnConflict } else { $ConflictAction }
            New-DotLink -Source (Join-Path $t.FullName $entry.Source) `
                -Target (Resolve-DotPath -Path $entry.Target -TokenMap $TokenMap) `
                -Method $entry.Method `
                -Template $entry.Template `
                -ConflictAction $action `
                -Capability $Capability
        }
    }
}

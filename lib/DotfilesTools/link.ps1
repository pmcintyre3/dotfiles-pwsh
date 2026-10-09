# Remembered answer from an "all" choice ([S]kip all, [O]verwrite all, [B]ackup all) for this run.
$script:StickyConflictAction = $null

function Reset-DotLinkPrompt {
    [CmdletBinding()]
    param()
    $script:StickyConflictAction = $null
}

function Test-CanPrompt {
    <#
    .SYNOPSIS
        True only on a real interactive console. Read-Host returns '' forever on redirected/EOF stdin
        (Task Scheduler, piped runs), so callers must not prompt when this is false.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()
    return [Environment]::UserInteractive -and -not [Console]::IsInputRedirected
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

function Read-CopyState {
    # Private. Recorded hashes of copied files, keyed by lowercase target path. Missing or corrupt = empty.
    param([string] $StatePath)
    if (-not $StatePath -or -not (Test-Path -LiteralPath $StatePath)) { return @{} }
    try {
        $state = Get-Content -LiteralPath $StatePath -Raw | ConvertFrom-Json -AsHashtable -ErrorAction Stop
        if ($state -is [System.Collections.IDictionary]) { return $state }
    } catch {
        Write-Verbose "Ignoring unreadable copy state '$StatePath': $($_.Exception.Message)"
    }
    return @{}
}

function Save-CopyHash {
    # Private. Record the hash of what the target now holds.
    param([string] $StatePath, [string] $Target, [string] $Hash)
    if (-not $StatePath) { return }
    $state = Read-CopyState -StatePath $StatePath
    $state[$Target.ToLowerInvariant()] = $Hash
    $dir = Split-Path -Path $StatePath -Parent
    if ($dir -and -not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $state | ConvertTo-Json | Set-Content -LiteralPath $StatePath
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

function Get-DotLinkConflictAction {
    # Private. Haacked's link_file prompt: [s]kip, [S]kip all, [o]verwrite, [O]verwrite all, [b]ackup, [B]ackup all,
    # plus [p]ull into repo when the target is a copy edited outside the repo.
    param([string] $Target, [string] $Requested, [switch] $AllowPull)

    if ($Requested -ne 'Prompt') { return $Requested }
    if ($script:StickyConflictAction) { return $script:StickyConflictAction }
    if (-not (Test-CanPrompt)) {
        throw "Target exists and this is a non-interactive session, so I can't ask what to do. Re-run interactively or pass -ConflictAction."
    }

    $choices = '[s]kip, [S]kip all, [o]verwrite, [O]verwrite all, [b]ackup, [B]ackup all'
    if ($AllowPull) { $choices = "[p]ull into repo, $choices" }
    while ($true) {
        $answer = Read-Host "File already exists: $Target. $choices"
        switch -CaseSensitive ($answer) {
            'p' { if ($AllowPull) { return 'Pull' } }
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
    .PARAMETER StatePath
        Copy method only: JSON file of recorded hashes, used to tell repo changes from edits made outside the repo.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)] [string] $Source,
        [Parameter(Mandatory)] [string] $Target,
        [Parameter(Mandatory)] [ValidateSet('Include', 'Junction', 'Symlink', 'Copy')] [string[]] $Method,
        [string] $Template,
        [ValidateSet('Prompt', 'Skip', 'Overwrite', 'Backup')] [string] $ConflictAction = 'Prompt',
        [pscustomobject] $Capability = (Get-MachineCapability -SkipNetwork),
        [string] $StatePath
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
            if ($chosen -eq 'Copy') { Save-CopyHash -StatePath $StatePath -Target $Target -Hash (Get-FileHash -LiteralPath $Source).Hash }
            $result.Action = 'AlreadyLinked'
            return $result
        }

        $action = 'Linked'
        $existing = Get-Item -LiteralPath $Target -Force -ErrorAction Ignore
        if ($existing) {
            # Copies we made before: tell "the repo changed" from "someone edited the live file".
            $recorded = $null
            $targetHash = $null
            if ($chosen -eq 'Copy' -and -not $existing.PSIsContainer -and -not $existing.LinkType) {
                $recorded = (Read-CopyState -StatePath $StatePath)[$Target.ToLowerInvariant()]
                if ($recorded) { $targetHash = (Get-FileHash -LiteralPath $Target).Hash }
            }

            if ($recorded -and $targetHash -eq $recorded) {
                Copy-Item -LiteralPath $Source -Destination $Target -Force
                Save-CopyHash -StatePath $StatePath -Target $Target -Hash (Get-FileHash -LiteralPath $Source).Hash
                $result.Action = 'Updated'
                return $result
            }

            if ($recorded) {
                try {
                    $conflict = Get-DotLinkConflictAction -Target $Target -Requested $ConflictAction -AllowPull
                } catch {
                    throw "$Target was edited outside the repo since it was last copied. $($_.Exception.Message)"
                }
            } else {
                $conflict = Get-DotLinkConflictAction -Target $Target -Requested $ConflictAction
            }

            switch ($conflict) {
                'Pull' {
                    Copy-Item -LiteralPath $Target -Destination $Source -Force
                    Save-CopyHash -StatePath $StatePath -Target $Target -Hash $targetHash
                    $result.Action = 'Pulled'
                    return $result
                }
                'Skip' {
                    $result.Action = 'Skipped'
                    $result.Reason = if ($recorded) { 'Edited outside the repo; left as is' } else { 'Target exists' }
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
            'Copy'     {
                Copy-Item -LiteralPath $Source -Destination $Target
                Save-CopyHash -StatePath $StatePath -Target $Target -Hash (Get-FileHash -LiteralPath $Source).Hash
            }
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
        Apply every entry in each topic's links.psd1. Entry OnConflict overrides -ConflictAction;
        entry RequireParent = $true skips targets whose folder doesn't exist (app not installed).
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)] [System.IO.DirectoryInfo[]] $Topic,
        [ValidateSet('Prompt', 'Skip', 'Overwrite', 'Backup')] [string] $ConflictAction = 'Prompt',
        [hashtable] $TokenMap = @{},
        [pscustomobject] $Capability = (Get-MachineCapability -SkipNetwork),
        [string] $StatePath
    )

    foreach ($t in $Topic) {
        $manifest = Join-Path $t.FullName 'links.psd1'
        if (-not (Test-Path -Path $manifest)) { continue }

        # A bad manifest or entry is one Failed result, not the end of the whole run.
        try {
            $entries = (Import-PowerShellDataFile -Path $manifest -ErrorAction Stop).Links
        } catch {
            [pscustomobject]@{ Source = $manifest; Target = $null; Method = $null; Action = 'Failed'
                Reason = "Invalid $($manifest): $($_.Exception.Message)"; BackupPath = $null }
            continue
        }

        foreach ($entry in $entries) {
            try {
                $target = Resolve-DotPath -Path $entry.Target -TokenMap $TokenMap
                if ($entry.RequireParent -and -not (Test-Path -LiteralPath (Split-Path -Path $target -Parent))) {
                    [pscustomobject]@{ Source = (Join-Path $t.FullName $entry.Source); Target = $target; Method = $null
                        Action = 'Skipped'; Reason = "Not installed ($(Split-Path -Path $target -Parent) doesn't exist)"; BackupPath = $null }
                    continue
                }
                $action = if ($entry.OnConflict) { $entry.OnConflict } else { $ConflictAction }
                New-DotLink -Source (Join-Path $t.FullName $entry.Source) `
                    -Target $target `
                    -Method $entry.Method `
                    -Template $entry.Template `
                    -ConflictAction $action `
                    -Capability $Capability `
                    -StatePath $StatePath
            } catch {
                [pscustomobject]@{ Source = $entry.Source; Target = $entry.Target; Method = $null; Action = 'Failed'
                    Reason = "Invalid entry in $($manifest): $($_.Exception.Message)"; BackupPath = $null }
            }
        }
    }
}

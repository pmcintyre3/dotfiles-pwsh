function Merge-JsonObject {
    # Private. Managed keys win; when both sides hold an object, merge key by key; other keys are kept.
    # Arrays and scalars are replaced wholesale. Adds the dotted path of every key it changes to $Changed.
    param(
        [System.Collections.IDictionary] $Target,
        [System.Collections.IDictionary] $Managed,
        [System.Collections.Generic.List[string]] $Changed,
        [string] $Prefix = ''
    )
    foreach ($key in $Managed.Keys) {
        $keyPath = "$Prefix$key"
        if ($Managed[$key] -is [System.Collections.IDictionary] -and $Target[$key] -is [System.Collections.IDictionary]) {
            Merge-JsonObject -Target $Target[$key] -Managed $Managed[$key] -Changed $Changed -Prefix "$keyPath."
            continue
        }
        $same = $Target.Contains($key) -and
            ((ConvertTo-Json -InputObject $Target[$key] -Depth 50 -Compress) -eq (ConvertTo-Json -InputObject $Managed[$key] -Depth 50 -Compress))
        if (-not $same) {
            $Target[$key] = $Managed[$key]
            $Changed.Add($keyPath)
        }
    }
}

function Merge-JsonSettings {
    <#
    .SYNOPSIS
        Merge a repo-managed JSON file into a live JSON file that an app also writes (e.g. ~/.claude/settings.json).
        Managed keys always win (changes made in the app to those keys are put back); every other key is kept.
        Arrays are replaced wholesale, so don't manage lists the app appends to (e.g. permissions.allow).
        Writes only when something changes, after an optional backup. A live file that isn't a JSON object
        (corrupt, empty, half-written) is left alone. Never throws; failures come back as Action = 'Failed'.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)] [string] $Path,
        [Parameter(Mandatory)] [string] $ManagedPath,
        [string] $BackupDir
    )

    $result = [pscustomobject]@{ Path = $Path; Action = $null; Reason = $null; BackupPath = $null; Changed = @() }
    try {
        $managed = Get-Content -LiteralPath $ManagedPath -Raw | ConvertFrom-Json -AsHashtable -ErrorAction Stop
        if (-not (Test-Path -LiteralPath $Path)) {
            $managed | ConvertTo-Json -Depth 50 | Set-Content -LiteralPath $Path
            $result.Action = 'Created'
            return $result
        }

        $raw = Get-Content -LiteralPath $Path -Raw
        try {
            $live = if ([string]::IsNullOrWhiteSpace($raw)) { $null } else { $raw | ConvertFrom-Json -AsHashtable -ErrorAction Stop }
        } catch {
            throw "Can't read $Path as JSON, so it was left alone: $($_.Exception.Message)"
        }
        if ($live -isnot [System.Collections.IDictionary]) {
            throw "$Path is empty or isn't a JSON object (half-written?), so it was left alone."
        }

        $changed = [System.Collections.Generic.List[string]]::new()
        Merge-JsonObject -Target $live -Managed $managed -Changed $changed
        $result.Changed = @($changed)
        if ($changed.Count -eq 0) {
            $result.Action = 'Unchanged'
            return $result
        }

        if ($BackupDir) {
            New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
            $result.BackupPath = Join-Path $BackupDir "$(Split-Path -Path $Path -Leaf).backup-$(Get-Date -Format yyyyMMddHHmmss)"
            Copy-Item -LiteralPath $Path -Destination $result.BackupPath
        }
        $live | ConvertTo-Json -Depth 50 | Set-Content -LiteralPath $Path
        $result.Action = 'Updated'
    } catch {
        $result.Action = 'Failed'
        $result.Reason = $_.Exception.Message
    }
    return $result
}

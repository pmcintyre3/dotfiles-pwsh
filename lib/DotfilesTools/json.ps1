function Merge-JsonObject {
    # Private. Managed keys win; when both sides hold an object, merge key by key; other keys are kept.
    param([System.Collections.IDictionary] $Target, [System.Collections.IDictionary] $Managed)
    foreach ($key in $Managed.Keys) {
        if ($Managed[$key] -is [System.Collections.IDictionary] -and $Target[$key] -is [System.Collections.IDictionary]) {
            Merge-JsonObject -Target $Target[$key] -Managed $Managed[$key]
        } else {
            $Target[$key] = $Managed[$key]
        }
    }
}

function Merge-JsonSettings {
    <#
    .SYNOPSIS
        Merge a repo-managed JSON file into a live JSON file that an app also writes (e.g. ~/.claude/settings.json).
        Writes only when something changes, after an optional backup. Never throws; failures come back as Action = 'Failed'.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)] [string] $Path,
        [Parameter(Mandatory)] [string] $ManagedPath,
        [string] $BackupDir
    )

    $result = [pscustomobject]@{ Path = $Path; Action = $null; Reason = $null; BackupPath = $null }
    try {
        $managed = Get-Content -LiteralPath $ManagedPath -Raw | ConvertFrom-Json -AsHashtable -ErrorAction Stop
        if (-not (Test-Path -LiteralPath $Path)) {
            $managed | ConvertTo-Json -Depth 50 | Set-Content -LiteralPath $Path
            $result.Action = 'Created'
            return $result
        }

        try {
            $live = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json -AsHashtable -ErrorAction Stop
        } catch {
            throw "Can't read $Path as JSON, so it was left alone: $($_.Exception.Message)"
        }
        if ($null -eq $live) { $live = [ordered]@{} }

        $before = $live | ConvertTo-Json -Depth 50 -Compress
        Merge-JsonObject -Target $live -Managed $managed
        if (($live | ConvertTo-Json -Depth 50 -Compress) -eq $before) {
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

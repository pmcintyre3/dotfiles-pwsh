# Optional tool locations. Each is skipped when not installed (Add-PathEntry ignores missing folders).

foreach ($opensslBin in 'C:\Program Files\OpenSSL-Win64\bin', 'C:\Program Files\OpenSSL\bin') {
    if (Test-Path -Path $opensslBin) {
        Add-PathEntry -Path $opensslBin -Append
        break
    }
}

# Newest per-user Python 3 Scripts folder (pip-installed CLIs).
$pythonDir = Get-ChildItem -Path (Join-Path $env:APPDATA 'Python') -Directory -Filter 'Python3*' -ErrorAction Ignore |
    Sort-Object -Property { [int] ($_.Name -replace '\D', '') } -Descending |
    Select-Object -First 1
if ($pythonDir) { Add-PathEntry -Path (Join-Path $pythonDir.FullName 'Scripts') -Append }

# Newest MongoDB server bin.
$mongoDir = Get-ChildItem -Path 'C:\Program Files\MongoDB\Server' -Directory -ErrorAction Ignore |
    Sort-Object -Property { $_.Name -as [version] } -Descending |
    Select-Object -First 1
if ($mongoDir) { Add-PathEntry -Path (Join-Path $mongoDir.FullName 'bin') -Append }

# Tools folder: each subfolder on PATH; versioned tools contribute their newest version subfolder.
$toolsRoot = $global:ProjectPaths['Tools']
if ($toolsRoot -and (Test-Path -Path $toolsRoot)) {
    $versionedTools = 'Terraform', 'doctl'
    foreach ($tool in $versionedTools) {
        $newest = Get-ChildItem -Path (Join-Path $toolsRoot $tool) -Directory -ErrorAction Ignore |
            Sort-Object -Property Name -Descending |
            Select-Object -First 1
        if ($newest) { Add-PathEntry -Path $newest.FullName }
    }
    Get-ChildItem -Path $toolsRoot -Directory |
        Where-Object { $_.Name -notin $versionedTools } |
        ForEach-Object { Add-PathEntry -Path $_.FullName }
}

Remove-Variable -Name opensslBin, pythonDir, mongoDir, toolsRoot, versionedTools, tool, newest -ErrorAction Ignore

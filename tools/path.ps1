# Optional tool locations. Each is skipped when not installed (Add-PathEntry ignores missing folders).
# Wrapped in a script block so its temporaries never touch the user's variables.
& {
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

    $toolsRoot = $global:ProjectPaths['Tools']
    if ($toolsRoot -and (Test-Path -Path $toolsRoot)) {
        # Versioned tools contribute their newest version folder, compared as versions (1.15.5 beats 1.9.0).
        $versionedTools = 'Terraform', 'doctl'
        foreach ($tool in $versionedTools) {
            $newest = Get-ChildItem -Path (Join-Path $toolsRoot $tool) -Directory -ErrorAction Ignore |
                Sort-Object -Descending -Property {
                    $version = [regex]::Match($_.Name, '\d+(\.\d+){1,3}').Value
                    if ($version) { [version] $version } else { [version] '0.0' }
                } |
                Select-Object -First 1
            if ($newest) { Add-PathEntry -Path $newest.FullName }
        }

        # Every other Tools subfolder only where profile.local.ps1 opts in.
        if ($global:ProjectPaths['AllToolsOnPath']) {
            Get-ChildItem -Path $toolsRoot -Directory |
                Where-Object { $_.Name -notin $versionedTools } |
                ForEach-Object { Add-PathEntry -Path $_.FullName }
        }
    }
}

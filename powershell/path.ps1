# Repo scripts (dot, and anything else in bin\) are callable by name.
Add-PathEntry -Path (Join-Path $global:DotfilesRoot 'bin')

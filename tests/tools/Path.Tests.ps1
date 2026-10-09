BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..\..\lib\DotfilesTools.psm1') -Force
    $pathScript = Join-Path $PSScriptRoot '..\..\tools\path.ps1'

    function Invoke-ToolsPath {
        param([hashtable] $Paths)
        $global:ProjectPaths = $Paths
        $env:PATH = 'C:\Windows'
        . $pathScript
        @($env:PATH -split ';')
    }
}

Describe 'tools/path.ps1' {
    BeforeEach {
        $savedPath = $env:PATH
        $savedProjectPaths = $global:ProjectPaths
        $tools = Join-Path $TestDrive ([guid]::NewGuid())
        foreach ($dir in 'Terraform\1.9.0', 'Terraform\1.15.5', 'doctl\1.99.0-windows-amd64', 'doctl\1.139.0-windows-amd64', 'SomeTool') {
            New-Item -ItemType Directory -Path (Join-Path $tools $dir) -Force | Out-Null
        }
    }
    AfterEach {
        $env:PATH = $savedPath
        $global:ProjectPaths = $savedProjectPaths
    }

    It 'adds the newest version folder by version number, not by name' {
        $entries = Invoke-ToolsPath @{ Tools = $tools }
        $entries | Should -Contain (Join-Path $tools 'Terraform\1.15.5')
        $entries | Should -Not -Contain (Join-Path $tools 'Terraform\1.9.0')
        $entries | Should -Contain (Join-Path $tools 'doctl\1.139.0-windows-amd64')
        $entries | Should -Not -Contain (Join-Path $tools 'doctl\1.99.0-windows-amd64')
    }

    It 'adds other Tools subfolders only when AllToolsOnPath is set' {
        Invoke-ToolsPath @{ Tools = $tools } | Should -Not -Contain (Join-Path $tools 'SomeTool')
        Invoke-ToolsPath @{ Tools = $tools; AllToolsOnPath = $true } | Should -Contain (Join-Path $tools 'SomeTool')
    }
}

BeforeAll {
    . (Join-Path $PSScriptRoot '..\..\git\functions\git.ps1')
}

Describe 'Invoke-MispelledGitCommand (gti)' {
    It 'forwards arguments to git without re-parsing them' {
        Mock git { $args }
        $output = Invoke-MispelledGitCommand commit -m 'two words'
        $output[0] | Should -Be 'Vrooom!'
        $output[1..3] | Should -Be @('commit', '-m', 'two words')
    }
}

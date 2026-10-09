function Write-Status {
    <#
    .SYNOPSIS
        Haacked-style status line: "  [ OK ] message".
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [ValidateSet('Info', 'User', 'Success', 'Skip', 'Fail')] [string] $Level,
        [Parameter(Mandatory)] [string] $Message
    )

    $tag, $color = switch ($Level) {
        'Info'    { '..', 'Cyan' }
        'User'    { '??', 'Yellow' }
        'Success' { 'OK', 'Green' }
        'Skip'    { '--', 'DarkGray' }
        'Fail'    { 'FAIL', 'Red' }
    }
    Write-Host '  [ ' -NoNewline
    Write-Host $tag -ForegroundColor $color -NoNewline
    Write-Host " ] $Message"
}

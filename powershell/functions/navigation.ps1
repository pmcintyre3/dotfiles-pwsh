# Explorer Functions

function Initialize-Profile()
{
    .$PROFILE
}

function Open-ExplorerViaII()
{
    Invoke-Item .
}

function Set-ParentLocation()
{
    Set-Location ..
}

function Set-GrandParentLocation()
{
    Set-Location ..\..
}

# function New-ItemAndSetLocation()
# {
#     $newFolder = mkdir $args; cd $newFolder.FullName
# }

function Set-LocationAndGetChildItem()
{
    Set-Location $args
    Get-ChildItem
}

# Not sure if it should just show hidden files or get ALL
# files in all folders recursively
# Recursive Link: https://community.spiceworks.com/topic/997981-powershell-get-childitem-not-getting-all-child-items
# Hidden Files link: https://www.oreilly.com/library/view/professional-windows-powershell/9780471946939/9780471946939_finding_hidden_files.html
function Get-AllChildItems()
{
    Write-Host "Not sure what to do yet, so here's Get-ChildItem"
    Get-ChildItem
}

function New-ItemAndSetLocation {
    [CmdletBinding()]
    param( 
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $Directory)

    process {
        $newFolder = New-Item $Directory -ItemType Directory
        if($newFolder) {
            Set-Location $newFolder.FullName
        }
    }
}

# Quick navigation (moved from the legacy main profile).
function cdp { Set-Location $global:ProjectPaths.Workspace }
function cdposh { Set-Location $global:DotfilesRoot }

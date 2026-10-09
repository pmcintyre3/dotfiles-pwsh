# Git Helper Functions

### Stolen shamelessly from https://gist.github.com/i-e-b/1767387
function Invoke-MispelledGitCommand()
{
    Write-Output "Vrooom!"
    & git @args
}

function Get-LocalGitBranches()
{
    git branch
}

function Invoke-GitUnsetUpstream()
{
    git branch --unset-upstream
}

function Invoke-GitRebase()
{
    git fetch; git rebase $args;
}

function Invoke-GitRebaseFromOrigin()
{
    git fetch; git rebase origin/develop;
}

function Merge-UpdatedGitBranch()
{
    git fetch; git merge $args;
}

function Merge-UpdatedGitBranchFromOrigin()
{
    git fetch; git merge origin/develop;
}

# function Invoke-GitFullClean()
# {
#     git clean -xdf -e .vs -e **/node_modules -e **/packages <# -e QGenda.Web/dist #>
# }


function Get-ReferencesForAllGitBranches()
{
    git fetch --all
}

function Get-LatestFromGitBranch()
{
    git fetch --all && git pull
}

function Get-GitRepositoryName
{
    param(
        [Parameter(Mandatory = $false,
            HelpMessage = ' (Optional) Path to git repository')]
        $Path)

    if(!$Path) {
        if(!(git branch)) {
            Write-Error "This location is not part of a git repository"
            return
        }
        
        return ((git config --get remote.origin.url) -replace ("(https://)([\w\.]+)(/[\w0-9\%]+)(/_git/)", "$1")).Trim()   
    }
    else {
        if(!(git -C $Path branch)) {
            Write-Error "The location '$Path' is not part of a git repository"
            return
        }
        
        return ((git -C $Path config --get remote.origin.url) -replace ("(https://)([\w\.]+)(/[\w0-9\%]+)(/_git/)", "$1")).Trim()  
    }
}

function Get-CurrentlyInGitRepository
{
    if(!(git branch)) {
        return $false
    }

    return $true
}

function Get-GitDefaultBranchName() {
    if (!(Get-CurrentlyInGitRepository)) {
        Write-Error "This location is not part of a git repository"
        throw "Not a git repository"
    }

    git remote show origin | ForEach-Object {
        if ($_ -match 'HEAD branch: (.+)$') {
            return $matches[1].Trim()
        }
    }
}

function Get-GitCurrentBranchName() {
    if (!(Get-CurrentlyInGitRepository)) {
        Write-Error "This location is not part of a git repository"
        throw "Not a git repository"
    }

    $currentBranch = git branch --show-current
    if (!$currentBranch) {
        Write-Warning "Head is detached. Returning default branch name instead."
        $currentBranch = Get-GitDefaultBranchName
    }

    return $currentBranch.Trim()
}

function Remove-LocalMergedBranches()
{
    git fetch
    git checkout origin/develop

    [array] $mergedBranches = (git branch --merged) |
        Where-Object { $_ -notmatch "develop" } |
        ForEach-Object { $_.substring(2).Trim() }

    foreach($branch in $mergedBranches) {
        git branch -d $branch
    }
}
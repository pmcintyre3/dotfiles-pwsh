BeforeDiscovery {
    Import-Module (Join-Path $PSScriptRoot '..\..\lib\DotfilesTools.psm1') -Force
    $canSymlink = (Get-MachineCapability -SkipNetwork).CanSymlink
}

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..\..\lib\DotfilesTools.psm1') -Force
    $noSymlink = [pscustomobject]@{ CanSymlink = $false }
    $withSymlink = [pscustomobject]@{ CanSymlink = $true }
    function New-TestDir { (New-Item -ItemType Directory -Path (Join-Path $TestDrive ([guid]::NewGuid()))).FullName }
}

Describe 'New-DotLink' {
    BeforeEach {
        Reset-DotLinkPrompt
        $dir = New-TestDir
        $source = Join-Path $dir 'source.txt'
        Set-Content -Path $source -Value 'repo content'
        $target = Join-Path $dir 'home\target.txt'
    }

    Context 'Include' {
        BeforeEach { $template = "# stub`n. '{Source}'" }

        It 'writes the rendered template, creating missing parent folders' {
            $r = New-DotLink -Source $source -Target $target -Method Include -Template $template -Capability $noSymlink
            $r.Action | Should -Be 'Linked'
            $r.Method | Should -Be 'Include'
            Get-Content -Path $target -Raw | Should -Match ([regex]::Escape(". '$source'"))
        }

        It 'reports AlreadyLinked on a re-run and makes no backup' {
            New-DotLink -Source $source -Target $target -Method Include -Template $template -Capability $noSymlink | Out-Null
            $r = New-DotLink -Source $source -Target $target -Method Include -Template $template -Capability $noSymlink -ConflictAction Backup
            $r.Action | Should -Be 'AlreadyLinked'
            Get-ChildItem -Path (Split-Path $target) -Filter '*.backup-*' | Should -BeNullOrEmpty
        }

        It 'treats CRLF and LF copies of the stub as the same' {
            New-Item -ItemType Directory -Path (Split-Path $target) -Force | Out-Null
            Set-Content -Path $target -Value ($template.Replace('{Source}', $source) -replace "`n", "`r`n") -NoNewline
            (New-DotLink -Source $source -Target $target -Method Include -Template $template -Capability $noSymlink -ConflictAction Skip).Action |
                Should -Be 'AlreadyLinked'
        }

        It 'renders {SourcePosix} with forward slashes (for git config paths, where backslashes are escapes)' {
            $r = New-DotLink -Source $source -Target $target -Method Include -Template 'path = {SourcePosix}' -Capability $noSymlink
            $r.Action | Should -Be 'Linked'
            Get-Content -Path $target -Raw | Should -Match ([regex]::Escape("path = $($source.Replace('\', '/'))"))
        }

        It 'fails when no template is given' {
            $r = New-DotLink -Source $source -Target $target -Method Include -Capability $noSymlink
            $r.Action | Should -Be 'Failed'
            $r.Reason | Should -Match 'Template'
        }
    }

    Context 'conflicts' {
        BeforeEach {
            New-Item -ItemType Directory -Path (Split-Path $target) -Force | Out-Null
            Set-Content -Path $target -Value 'user content'
            $linkArgs = @{ Source = $source; Target = $target; Method = 'Copy'; Capability = $noSymlink }
            # The test runner's stdin is usually redirected; prompt tests simulate an interactive console.
            Mock -ModuleName DotfilesTools Test-CanPrompt { $true }
        }

        It 'Skip leaves the target untouched' {
            (New-DotLink @linkArgs -ConflictAction Skip).Action | Should -Be 'Skipped'
            Get-Content -Path $target | Should -Be 'user content'
        }

        It 'Backup moves the original aside before linking' {
            (New-DotLink @linkArgs -ConflictAction Backup).Action | Should -Be 'BackedUp'
            Get-Content -Path $target | Should -Be 'repo content'
            $backup = @(Get-ChildItem -Path (Split-Path $target) -Filter 'target.txt.backup-*')
            $backup | Should -HaveCount 1
            Get-Content -Path $backup[0].FullName | Should -Be 'user content'
        }

        It 'Overwrite replaces the target without a backup' {
            (New-DotLink @linkArgs -ConflictAction Overwrite).Action | Should -Be 'Overwritten'
            Get-Content -Path $target | Should -Be 'repo content'
            Get-ChildItem -Path (Split-Path $target) -Filter '*.backup-*' | Should -BeNullOrEmpty
        }

        It 'Prompt asks once and remembers an "all" answer' {
            Mock -ModuleName DotfilesTools Read-Host { 'S' }
            (New-DotLink @linkArgs).Action | Should -Be 'Skipped'
            $other = Join-Path (Split-Path $target) 'other.txt'
            Set-Content -Path $other -Value 'x'
            (New-DotLink -Source $source -Target $other -Method Copy -Capability $noSymlink).Action | Should -Be 'Skipped'
            Should -Invoke -ModuleName DotfilesTools Read-Host -Times 1 -Exactly
        }

        It 'Prompt asks again after an unrecognized answer' {
            $global:DotLinkTestAnswers = [System.Collections.Queue]::new([string[]] @('x', 'b'))
            Mock -ModuleName DotfilesTools Read-Host { $global:DotLinkTestAnswers.Dequeue() }
            (New-DotLink @linkArgs).Action | Should -Be 'BackedUp'
            Should -Invoke -ModuleName DotfilesTools Read-Host -Times 2 -Exactly
            Remove-Variable -Name DotLinkTestAnswers -Scope Global
        }

        It 'Prompt fails without asking when the session is not interactive' {
            Mock -ModuleName DotfilesTools Test-CanPrompt { $false }
            Mock -ModuleName DotfilesTools Read-Host { 'b' }
            $r = New-DotLink @linkArgs
            $r.Action | Should -Be 'Failed'
            $r.Reason | Should -Match 'non-interactive'
            Should -Invoke -ModuleName DotfilesTools Read-Host -Times 0 -Exactly
            Get-Content -Path $target | Should -Be 'user content'
        }

        It 'Prompt does not hang when stdin is at end-of-input (Task Scheduler, piped runs)' {
            $modulePath = (Resolve-Path (Join-Path $PSScriptRoot '..\..\lib\DotfilesTools.psm1')).Path
            $command = "Import-Module '$modulePath'; " +
                "(New-DotLink -Source '$source' -Target '$target' -Method Copy -Capability ([pscustomobject]@{ CanSymlink = `$false })).Action"
            $psi = [System.Diagnostics.ProcessStartInfo]::new('pwsh', @('-NoProfile', '-Command', $command))
            $psi.RedirectStandardInput = $true
            $psi.RedirectStandardOutput = $true
            $psi.UseShellExecute = $false
            $process = [System.Diagnostics.Process]::Start($psi)
            $process.StandardInput.Close()
            $finished = $process.WaitForExit(30000)
            if (-not $finished) { $process.Kill() }
            $finished | Should -BeTrue -Because 'the conflict prompt must not loop on an empty stdin'
            $process.StandardOutput.ReadToEnd().Trim() | Should -Be 'Failed'
            Get-Content -Path $target | Should -Be 'user content'
        }

        It "Prompt fails cleanly when the host can't prompt" {
            Mock -ModuleName DotfilesTools Read-Host { throw 'PowerShell is in NonInteractive mode.' }
            $r = New-DotLink @linkArgs
            $r.Action | Should -Be 'Failed'
            $r.Reason | Should -Match 'NonInteractive'
            Get-Content -Path $target | Should -Be 'user content'
        }
    }

    Context 'method selection' {
        It 'falls back to Copy when symlinks are unavailable' {
            $r = New-DotLink -Source $source -Target $target -Method Symlink, Copy -Capability $noSymlink
            $r.Method | Should -Be 'Copy'
            (Get-Item -Path $target).LinkType | Should -BeNullOrEmpty
        }

        It 'uses a symlink when the machine supports it' -Skip:(-not $canSymlink) {
            $r = New-DotLink -Source $source -Target $target -Method Symlink, Copy -Capability $withSymlink
            $r.Method | Should -Be 'Symlink'
            (Get-Item -Path $target).LinkTarget | Should -Be $source
        }

        It 'links a directory with a junction (no admin needed)' {
            $srcDir = Join-Path $dir 'skills'
            New-Item -ItemType Directory -Path $srcDir | Out-Null
            $dirTarget = Join-Path $dir 'home\skills'
            (New-DotLink -Source $srcDir -Target $dirTarget -Method Junction -Capability $noSymlink).Action | Should -Be 'Linked'
            (Get-Item -Path $dirTarget).LinkType | Should -Be 'Junction'
            (New-DotLink -Source $srcDir -Target $dirTarget -Method Junction -Capability $noSymlink -ConflictAction Skip).Action |
                Should -Be 'AlreadyLinked'
        }

        It 'overwriting a junction removes only the link' {
            $srcDir = Join-Path $dir 'skills'
            New-Item -ItemType Directory -Path $srcDir | Out-Null
            $otherDir = Join-Path $dir 'other'
            New-Item -ItemType Directory -Path $otherDir | Out-Null
            Set-Content -Path (Join-Path $otherDir 'keep.txt') -Value 'keep'
            $dirTarget = Join-Path $dir 'home\skills'
            New-Item -ItemType Directory -Path (Split-Path $dirTarget) -Force | Out-Null
            New-Item -ItemType Junction -Path $dirTarget -Target $otherDir | Out-Null

            (New-DotLink -Source $srcDir -Target $dirTarget -Method Junction -Capability $noSymlink -ConflictAction Overwrite).Action |
                Should -Be 'Overwritten'
            Join-Path $otherDir 'keep.txt' | Should -Exist
            (Get-Item -Path $dirTarget).LinkTarget | Should -Be $srcDir
        }

        It 'fails cleanly when no allowed method works' {
            $r = New-DotLink -Source $source -Target $target -Method Symlink -Capability $noSymlink
            $r.Action | Should -Be 'Failed'
            $r.Reason | Should -Match 'None of the allowed methods'
        }

        It 'fails cleanly when the source is missing' {
            $r = New-DotLink -Source (Join-Path $dir 'missing.txt') -Target $target -Method Copy -Capability $noSymlink
            $r.Action | Should -Be 'Failed'
            $r.Reason | Should -Match 'Source not found'
        }
    }

    Context 'copy drift' {
        BeforeEach {
            $state = Join-Path $dir 'state\copy-hashes.json'
            $copyArgs = @{ Source = $source; Target = $target; Method = 'Copy'; Capability = $noSymlink; StatePath = $state }
            Mock -ModuleName DotfilesTools Test-CanPrompt { $true }
        }

        It 'records the hash of what it copied' {
            (New-DotLink @copyArgs).Action | Should -Be 'Linked'
            $recorded = (Get-Content -Path $state -Raw | ConvertFrom-Json -AsHashtable)[$target.ToLowerInvariant()]
            $recorded | Should -Be (Get-FileHash -Path $source).Hash
        }

        It 'records the hash when the target already matches (first run on a machine that is already set up)' {
            New-Item -ItemType Directory -Path (Split-Path $target) -Force | Out-Null
            Copy-Item -Path $source -Destination $target
            (New-DotLink @copyArgs).Action | Should -Be 'AlreadyLinked'
            $state | Should -Exist
        }

        It 'refreshes the copy without asking when only the repo changed' {
            New-DotLink @copyArgs | Out-Null
            Set-Content -Path $source -Value 'repo v2'
            Mock -ModuleName DotfilesTools Read-Host { throw 'should not prompt' }
            (New-DotLink @copyArgs).Action | Should -Be 'Updated'
            Get-Content -Path $target | Should -Be 'repo v2'
            Get-ChildItem -Path (Split-Path $target) -Filter '*.backup-*' | Should -BeNullOrEmpty
        }

        It 'asks before overwriting edits made outside the repo, and can pull them into the repo' {
            New-DotLink @copyArgs | Out-Null
            Set-Content -Path $target -Value 'edited in the Settings UI'
            Mock -ModuleName DotfilesTools Read-Host { 'p' }
            (New-DotLink @copyArgs).Action | Should -Be 'Pulled'
            Get-Content -Path $source | Should -Be 'edited in the Settings UI'
            (New-DotLink @copyArgs).Action | Should -Be 'AlreadyLinked'
        }

        It 'reports edits made outside the repo as Failed in a non-interactive session' {
            New-DotLink @copyArgs | Out-Null
            Set-Content -Path $target -Value 'edited in the Settings UI'
            Mock -ModuleName DotfilesTools Test-CanPrompt { $false }
            $r = New-DotLink @copyArgs
            $r.Action | Should -Be 'Failed'
            $r.Reason | Should -Match 'edited outside the repo'
            Get-Content -Path $target | Should -Be 'edited in the Settings UI'
        }

        It 'does not apply an earlier "all" answer to a copy edited outside the repo' {
            New-DotLink @copyArgs | Out-Null
            Set-Content -Path $target -Value 'edited in the Settings UI'
            # An earlier, unrelated conflict was answered "[O]verwrite all".
            $other = Join-Path (Split-Path $target) 'other.txt'
            Set-Content -Path $other -Value 'x'
            Mock -ModuleName DotfilesTools Read-Host { 'O' }
            (New-DotLink -Source $source -Target $other -Method Copy -Capability $noSymlink).Action | Should -Be 'Overwritten'

            Mock -ModuleName DotfilesTools Read-Host { 's' }
            (New-DotLink @copyArgs).Action | Should -Be 'Skipped'
            Get-Content -Path $target | Should -Be 'edited in the Settings UI'
            Should -Invoke -ModuleName DotfilesTools Read-Host -Times 2 -Exactly
        }

        It 'treats a target with no record as a normal conflict (first run)' {
            New-Item -ItemType Directory -Path (Split-Path $target) -Force | Out-Null
            Set-Content -Path $target -Value 'pre-existing'
            (New-DotLink @copyArgs -ConflictAction Backup).Action | Should -Be 'BackedUp'
        }

        It 'treats a corrupt state file as no record' {
            New-Item -ItemType Directory -Path (Split-Path $state) -Force | Out-Null
            Set-Content -Path $state -Value '{ not json'
            New-Item -ItemType Directory -Path (Split-Path $target) -Force | Out-Null
            Set-Content -Path $target -Value 'pre-existing'
            (New-DotLink @copyArgs -ConflictAction Backup).Action | Should -Be 'BackedUp'
            (Get-Content -Path $state -Raw | ConvertFrom-Json -AsHashtable).Count | Should -Be 1
        }
    }
}

Describe 'Invoke-DotLinks' {
    It 'links each links.psd1 entry, resolving tokens and honoring OnConflict' {
        $root = New-TestDir
        $topic = New-Item -ItemType Directory -Path (Join-Path $root 'demo')
        Set-Content -Path (Join-Path $topic.FullName 'config.txt') -Value 'cfg'
        Set-Content -Path (Join-Path $topic.FullName 'links.psd1') -Value @'
@{
    Links = @(
        @{ Source = 'config.txt'; Target = '~\demo\config.txt'; Method = 'Copy' }
        @{ Source = 'config.txt'; Target = '{PROFILE}'; Method = 'Include'; Template = '. {Source}'; OnConflict = 'Backup' }
    )
}
'@
        $fakeHome = Join-Path $root 'home'
        $profilePath = Join-Path $root 'profile\profile.ps1'
        New-Item -ItemType Directory -Path (Split-Path $profilePath) | Out-Null
        Set-Content -Path $profilePath -Value 'old profile'

        $results = Invoke-DotLinks -Topic $topic -ConflictAction Skip -Capability $noSymlink `
            -TokenMap @{ '~' = $fakeHome; '{PROFILE}' = $profilePath }

        $results.Action | Should -Be @('Linked', 'BackedUp')
        Get-Content -Path (Join-Path $fakeHome 'demo\config.txt') | Should -Be 'cfg'
        Get-Content -Path $profilePath | Should -Be ". $(Join-Path $topic.FullName 'config.txt')"
    }

    It 'passes StatePath through to copy links' {
        $root = New-TestDir
        $topic = New-Item -ItemType Directory -Path (Join-Path $root 'demo')
        Set-Content -Path (Join-Path $topic.FullName 'c.txt') -Value 'c'
        Set-Content -Path (Join-Path $topic.FullName 'links.psd1') -Value "@{ Links = @( @{ Source = 'c.txt'; Target = '~\demo\c.txt'; Method = 'Copy' } ) }"
        $state = Join-Path $root '.state\copy-hashes.json'
        Invoke-DotLinks -Topic $topic -Capability $noSymlink -StatePath $state -TokenMap @{ '~' = (Join-Path $root 'home') } | Out-Null
        $state | Should -Exist
    }

    It 'skips entries whose RequireParent folder is missing, without creating it' {
        $root = New-TestDir
        $topic = New-Item -ItemType Directory -Path (Join-Path $root 'app')
        Set-Content -Path (Join-Path $topic.FullName 'settings.json') -Value '{}'
        Set-Content -Path (Join-Path $topic.FullName 'links.psd1') -Value "@{ Links = @( @{ Source = 'settings.json'; Target = '~\NotInstalled\LocalState\settings.json'; Method = 'Copy'; RequireParent = `$true } ) }"
        $r = Invoke-DotLinks -Topic $topic -Capability $noSymlink -TokenMap @{ '~' = (Join-Path $root 'home') }
        $r.Action | Should -Be 'Skipped'
        $r.Reason | Should -Match '^Not installed'
        Join-Path $root 'home\NotInstalled' | Should -Not -Exist
    }

    It 'reports a malformed links.psd1 or a bad entry as Failed and keeps going' {
        $root = New-TestDir
        $bad = New-Item -ItemType Directory -Path (Join-Path $root 'bad')
        Set-Content -Path (Join-Path $bad.FullName 'links.psd1') -Value '@{ Links = @( '
        $odd = New-Item -ItemType Directory -Path (Join-Path $root 'odd')
        Set-Content -Path (Join-Path $odd.FullName 'a.txt') -Value 'a'
        Set-Content -Path (Join-Path $odd.FullName 'links.psd1') -Value "@{ Links = @( @{ Source = 'a.txt'; Target = '~\odd\a.txt'; Method = 'Copy'; OnConflict = 'Sometimes' } ) }"
        $good = New-Item -ItemType Directory -Path (Join-Path $root 'good')
        Set-Content -Path (Join-Path $good.FullName 'g.txt') -Value 'g'
        Set-Content -Path (Join-Path $good.FullName 'links.psd1') -Value "@{ Links = @( @{ Source = 'g.txt'; Target = '~\good\g.txt'; Method = 'Copy' } ) }"

        $results = @(Invoke-DotLinks -Topic $bad, $odd, $good -ConflictAction Skip -Capability $noSymlink `
                -TokenMap @{ '~' = (Join-Path $root 'home') })

        $results.Action | Should -Be @('Failed', 'Failed', 'Linked')
        $results[0].Reason | Should -Match 'links\.psd1'
        $results[1].Reason | Should -Match 'Sometimes'
    }

    It 'emits nothing for an optional entry whose source is not in the repo, and links it once it is' {
        $root = New-TestDir
        $topic = New-Item -ItemType Directory -Path (Join-Path $root 'ai')
        Set-Content -Path (Join-Path $topic.FullName 'links.psd1') -Value "@{ Links = @( @{ Source = 'CLAUDE.md'; Target = '~\.claude\CLAUDE.md'; Method = 'Copy'; Optional = `$true } ) }"
        $tokenMap = @{ '~' = (Join-Path $root 'home') }
        Invoke-DotLinks -Topic $topic -Capability $noSymlink -TokenMap $tokenMap | Should -BeNullOrEmpty

        Set-Content -Path (Join-Path $topic.FullName 'CLAUDE.md') -Value '# global'
        (Invoke-DotLinks -Topic $topic -Capability $noSymlink -TokenMap $tokenMap).Action | Should -Be 'Linked'
    }

    It 'ignores topics without links.psd1' {
        Invoke-DotLinks -Topic (Get-Item -Path (New-TestDir)) -Capability $noSymlink | Should -BeNullOrEmpty
    }
}

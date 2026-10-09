class MenuOptionItem {
    [String] $Text
    [String] $Value

    MenuOptionItem() {}

    MenuOptionItem([String] $Text, [String] $Value) {
    	$this.Text = $Text
    	$this.Value = $Value
    }
}

function Get-MenuSelection
{
    [CmdletBinding()]
    [OutputType([string])]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'MenuPrompt', Justification = 'Read by the nested Write-Menu function')]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String[]]$MenuItems,
        [Parameter(Mandatory = $true)]
        [String]$MenuPrompt
    )
    # store initial cursor position
    $cursorPosition = $host.UI.RawUI.CursorPosition
    [Int32]$pos = 0 # current item selection

    $keyCodes = @{
    	ArrowUp = 38
    	ArrowDown = 40
    	Enter = 13

    	Zero = 48
    	Nine = 57

    	LetterI = 73
    	LetterX = 88

    	Backspace = 8
    }

    #==============
    # 1. Draw menu
    #==============
    function Write-Menu
    {
        param (
            [int]$selectedItemIndex
        )
        # reset the cursor position
        $Host.UI.RawUI.CursorPosition = $cursorPosition

        # Padding the menu prompt to center it
        $prompt = $MenuPrompt
        $maxLineLength = ($MenuItems | Measure-Object -Property Length -Maximum).Maximum + 4
        while ($prompt.Length -lt $maxLineLength+4)
        {
            $prompt = " $prompt "
        }
        Write-Host $prompt -ForegroundColor Green
        Write-Host "Use 'i' to search by index" -ForegroundColor DarkGray
        $padLength = $MenuItems.Length.ToString().Length
        # Write the menu lines
        for ($i = 0; $i -lt $MenuItems.Count; $i++)
        {
        	$index = ($i + 1).ToString().PadLeft($padLength, " ")
            $line = "[$index]:    $($MenuItems[$i])" + (" " * ($maxLineLength - $MenuItems[$i].Length))
            if ($selectedItemIndex -eq $i)
            {
                Write-Host $line -ForegroundColor Blue -BackgroundColor Gray
            }
            else
            {
                Write-Host $line
            }
        }
        $cancelIndex = "x".PadLeft($padLength, " ")
        $cancelText = "Cancel"
        $cancelLine = "[$cancelIndex]:    $cancelText" + (" " * ($maxLineLength - $cancelText.Length))
        Write-Host $cancelLine -ForegroundColor Red
    }

    Write-Menu -selectedItemIndex $pos

    $key = $null
    $isSearching = $true
    $isCancelled = $false
    while ($isSearching -ne $false)
    {
    	$openedSearchPrompt = $false

        while ($key -ne $keyCodes.Enter) {

        	#============================
        	# 2. Read the keyboard input
        	#============================
        	$press = $host.ui.rawui.readkey("NoEcho,IncludeKeyDown")
        	$key = $press.virtualkeycode

        	if ($key -eq $keyCodes.ArrowUp)
        	{
        	    $pos--
        	}
        	if ($key -eq $keyCodes.ArrowDown)
        	{
        	    $pos++
        	}

        	if($key -eq $keyCodes.LetterI) {
        		$openedSearchPrompt = $true
        		break
        	}

        	if($key -eq $keyCodes.LetterX) {
        		$isSearching = $false
        		$isCancelled = $true
        		break
			}

        	#handle out of bound selection cases
        	if ($pos -lt 0) { $pos = 0 }
        	if ($pos -eq $MenuItems.count) { $pos = $MenuItems.count - 1 }

        	#==============
        	# 1. Draw menu
        	#==============
        	Write-Menu -selectedItemIndex $pos -searchKeyString $searchKey
        }

        if($openedSearchPrompt) {
        	$userQuery = Read-Host "Index"
        	$index = -1
        	if($userQuery -eq "c" -or $userQuery -eq "C") {
        		continue
        	}
        	if([Int32]::TryParse($userQuery.Trim(), [ref]$index) -and $index -gt 0 -and $index -le $MenuItems.Length) {
        		$pos = $index - 1
        		$isSearching = $false
        	}
        } else {
        	$isSearching = $false
        }
    }

    if($isCancelled) {
    	return ""
    }

    return $MenuItems[$pos].Trim()
}

function Get-KeyValueMenuSelection {
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'MenuPrompt', Justification = 'Read by the nested Write-Menu function')]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [MenuOptionItem[]]$MenuItems,
        [Parameter(Mandatory = $False)]
        [String]$MenuPrompt = "Select an option"
    )
    # store initial cursor position
    $cursorPosition = $host.UI.RawUI.CursorPosition
    $pos = 0 # current item selection

    $keyCodes = @{
        ArrowUp = 38
        ArrowDown = 40
        Enter = 13
    }

    #==============
    # 1. Draw menu
    #==============
    function Write-Menu
    {
        param (
            [int]$selectedItemIndex
        )
        # reset the cursor position
        $Host.UI.RawUI.CursorPosition = $cursorPosition

        # Padding the menu prompt to center it
        $prompt = $MenuPrompt
        $maxLineLength = ($MenuItems.Text | Measure-Object -Property Length -Maximum).Maximum + 4
        while ($prompt.Length -lt $maxLineLength+4)
        {
            $prompt = " $prompt "
        }
        Write-Host $prompt -ForegroundColor Green
        # Write the menu lines
        for ($i = 0; $i -lt $MenuItems.Count; $i++)
        {
            $line = "    $($MenuItems[$i].Text)" + (" " * ($maxLineLength - $MenuItems[$i].Text.Length))
            if ($selectedItemIndex -eq $i)
            {
                Write-Host $line -ForegroundColor Blue -BackgroundColor Gray
            }
            else
            {
                Write-Host $line
            }
        }
    }

    Write-Menu -selectedItemIndex $pos

    $key = $null
    while ($key -ne $keyCodes.Enter)
    {
        #============================
        # 2. Read the keyboard input
        #============================
        $press = $host.ui.rawui.readkey("NoEcho,IncludeKeyDown")
        $key = $press.virtualkeycode
        if ($key -eq $keyCodes.ArrowUp)
        {
            $pos--
        }
        if ($key -eq $keyCodes.ArrowDown)
        {
            $pos++
        }
        #handle out of bound selection cases
        if ($pos -lt 0) { $pos = 0 }
        if ($pos -eq $MenuItems.count) { $pos = $MenuItems.count - 1 }

        #==============
        # 1. Draw menu
        #==============
        Write-Menu -selectedItemIndex $pos
    }

    Write-Host $MenuItems[$pos].Text
    return $MenuItems[$pos].Value
}

function Get-KeyCodeFromKeyPress {
	$press = $host.ui.rawui.readkey("NoEcho,IncludeKeyDown")

    return $press
}
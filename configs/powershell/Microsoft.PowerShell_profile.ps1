# =============================================================================
# WinForge PowerShell profile
# Drops sensible defaults, prompt, aliases, completion, and tool integrations.
# Safe to source from PowerShell 5.1 and PowerShell 7.
# =============================================================================

# --- Encoding & history ------------------------------------------------------
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding           = [System.Text.Encoding]::UTF8
$PSDefaultParameterValues['Out-File:Encoding'] = 'utf8'

# Persistent shared history
Set-PSReadLineOption -HistorySaveStyle SaveIncrementally `
                     -HistorySearchCursorMovesToEnd `
                     -PredictionSource HistoryAndPlugin `
                     -PredictionViewStyle ListView `
                     -EditMode Windows

Set-PSReadLineKeyHandler -Key Tab           -Function MenuComplete
Set-PSReadLineKeyHandler -Key Ctrl+r        -Function ReverseSearchHistory
Set-PSReadLineKeyHandler -Key UpArrow       -Function HistorySearchBackward
Set-PSReadLineKeyHandler -Key DownArrow     -Function HistorySearchForward

# --- Prompt: starship if available, else minimal fallback --------------------
if (Get-Command starship -ErrorAction SilentlyContinue) {
    Invoke-Expression (& starship init powershell)
} else {
    function prompt {
        $loc = (Get-Location).Path.Replace($HOME, '~')
        Write-Host "$env:USERNAME" -ForegroundColor Cyan -NoNewline
        Write-Host " $loc" -ForegroundColor Yellow -NoNewline
        return "`n> "
    }
}

# --- zoxide ------------------------------------------------------------------
if (Get-Command zoxide -ErrorAction SilentlyContinue) {
    Invoke-Expression (& { (zoxide init powershell | Out-String) })
}

# --- fnm (Node) --------------------------------------------------------------
if (Get-Command fnm -ErrorAction SilentlyContinue) {
    fnm env --use-on-cd | Out-String | Invoke-Expression
}

# --- Aliases / shortcuts -----------------------------------------------------
Set-Alias -Name g    -Value git           -Option AllScope -ErrorAction SilentlyContinue
Set-Alias -Name k    -Value kubectl       -Option AllScope -ErrorAction SilentlyContinue
Set-Alias -Name tf   -Value terraform     -Option AllScope -ErrorAction SilentlyContinue
Set-Alias -Name ll   -Value Get-ChildItem -Option AllScope -ErrorAction SilentlyContinue
Set-Alias -Name which -Value Get-Command  -Option AllScope -ErrorAction SilentlyContinue

function .. { Set-Location .. }
function ... { Set-Location ../.. }
function reload-profile { . $PROFILE }
function open ($path = '.') { Start-Process explorer.exe $path }

function gco { git checkout $args }
function gst { git status $args }
function gp  { git pull $args }
function gpu { git push $args }
function gca { git commit -a -m $args }

# --- WSL helpers -------------------------------------------------------------
function wsl-here { wsl --cd "$pwd" }

# --- WinForge utilities ------------------------------------------------------
function winforge-status {
    $state = "$env:ProgramData\WinForge\state.json"
    if (Test-Path $state) {
        Get-Content $state | ConvertFrom-Json | Format-List
    } else {
        Write-Host "No WinForge state found." -ForegroundColor Yellow
    }
}

function winforge-logs {
    $log = "$env:ProgramData\WinForge\logs"
    if (Test-Path $log) { Get-ChildItem $log | Sort-Object LastWriteTime -Descending | Select-Object -First 5 }
}

# --- Completion: gh, docker, winget where available --------------------------
foreach ($tool in 'gh','docker','rustup','kubectl') {
    if (Get-Command $tool -ErrorAction SilentlyContinue) {
        try { & $tool completion powershell 2>$null | Out-String | Invoke-Expression } catch {}
    }
}

# winget tab completion (Microsoft official snippet)
Register-ArgumentCompleter -Native -CommandName winget -ScriptBlock {
    param($wordToComplete, $commandAst, $cursorPosition)
    [Console]::InputEncoding = [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()
    $Local:word = $wordToComplete.Replace('"', '""')
    $Local:ast  = $commandAst.ToString().Replace('"', '""')
    winget complete --word="$Local:word" --commandline "$Local:ast" --position $cursorPosition |
        ForEach-Object { [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_) }
}

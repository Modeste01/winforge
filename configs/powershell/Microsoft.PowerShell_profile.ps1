# WinForge PowerShell Profile
# Deploy to: $env:USERPROFILE\Documents\PowerShell\Microsoft.PowerShell_profile.ps1

# Starship prompt
if (Get-Command starship -ErrorAction SilentlyContinue) {
    $env:STARSHIP_CONFIG = "$HOME\.config\starship.toml"
    Invoke-Expression (&starship init powershell)
} elseif (Get-Command oh-my-posh -ErrorAction SilentlyContinue) {
    oh-my-posh init pwsh --config "$HOME\AppData\Local\Programs\oh-my-posh\themes\catppuccin_mocha.omp.json" | Invoke-Expression
}

# PSReadLine
if (Get-Module PSReadLine -ListAvailable) {
    Import-Module PSReadLine
    Set-PSReadLineOption -PredictionSource HistoryAndPlugin
    Set-PSReadLineOption -PredictionViewStyle ListView
    Set-PSReadLineOption -EditMode Windows
    Set-PSReadLineKeyHandler -Key Tab       -Function MenuComplete
    Set-PSReadLineKeyHandler -Key UpArrow   -Function HistorySearchBackward
    Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
    Set-PSReadLineOption -Colors @{
        Command   = '#4f98a3'
        Parameter = '#6daa45'
        String    = '#e8af34'
        Comment   = '#5a5957'
        Keyword   = '#a86fdf'
        Error     = '#d163a7'
    }
}

# Modules
if (Get-Module Terminal-Icons -ListAvailable) { Import-Module Terminal-Icons }
if (Get-Module z -ListAvailable)             { Import-Module z }

# Aliases
Set-Alias -Name g     -Value git
Set-Alias -Name which -Value Get-Command
Set-Alias -Name open  -Value Invoke-Item
Set-Alias -Name grep  -Value Select-String

function ll  { Get-ChildItem -Force @args }
function la  { Get-ChildItem -Force -Hidden @args }
function ..  { Set-Location .. }
function ... { Set-Location ..\..\ }
function ~   { Set-Location $HOME }

# Git shortcuts
function gs   { git status @args }
function ga   { git add @args }
function gc   { git commit -m @args }
function gp   { git push @args }
function gpl  { git pull @args }
function gco  { git checkout @args }
function gb   { git branch @args }
function glog { git log --oneline --graph --decorate --all }
function gd   { git diff @args }
function gcl  { git clone @args }

# Dev shortcuts
function py       { python @args }
function activate { .\.venv\Scripts\Activate.ps1 }
function venv     { uv venv; activate }
function serve    { python -m http.server @args }
function ports    { netstat -ano | findstr LISTENING }
function path     { $env:PATH -split ';' | Sort-Object }

# WinForge utils
function wf-update {
    Write-Host "Updating all packages via winget..." -ForegroundColor Cyan
    winget upgrade --all --silent --accept-package-agreements --accept-source-agreements
}

# fnm (Node)
if (Get-Command fnm -ErrorAction SilentlyContinue) {
    fnm env --use-on-cd | Out-String | Invoke-Expression
}

# Welcome
$os = (Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue)
if ($os) {
    $ram = [math]::Round($os.TotalVisibleMemorySize/1MB, 1)
    Write-Host "  WinForge Shell  PS $($PSVersionTable.PSVersion.Major).$($PSVersionTable.PSVersion.Minor)  Windows Build $($os.BuildNumber)  RAM: ${ram} GB" -ForegroundColor DarkCyan
}

#Requires -Version 5.1
<#
.SYNOPSIS
    WinForge — Windows 11 power-user setup script
.DESCRIPTION
    Detects Windows version, prompts for tier, installs apps via winget/Scoop,
    deploys configs, runs debloat and tweaks sub-scripts.
.PARAMETER Tier
    Install tier: Core | PowerUser | Dev | AI
.PARAMETER DryRun
    Preview all changes without applying them
.PARAMETER SkipApps
    Skip package installation
.PARAMETER SkipConfigs
    Skip config file deployment
.PARAMETER SkipDebloat
    Skip debloat sub-script
.PARAMETER SkipTweaks
    Skip tweaks sub-script
.PARAMETER NoRestore
    Skip System Restore Point creation
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [ValidateSet('Core','PowerUser','Dev','AI')]
    [string]$Tier,
    [switch]$DryRun,
    [switch]$SkipApps,
    [switch]$SkipConfigs,
    [switch]$SkipDebloat,
    [switch]$SkipTweaks,
    [switch]$NoRestore
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$script:LogFile = "$PSScriptRoot\WinForge_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
$script:ScriptRoot = $PSScriptRoot

function Write-Log {
    param([string]$Msg, [string]$Level = 'INFO')
    $line = "[$(Get-Date -Format 'HH:mm:ss')] [$Level] $Msg"
    Add-Content -Path $script:LogFile -Value $line -ErrorAction SilentlyContinue
    switch ($Level) {
        'INFO'    { Write-Host $line -ForegroundColor Cyan }
        'WARN'    { Write-Host $line -ForegroundColor Yellow }
        'ERROR'   { Write-Host $line -ForegroundColor Red }
        'SUCCESS' { Write-Host $line -ForegroundColor Green }
        default   { Write-Host $line }
    }
}

function Test-Admin {
    $current = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
    return $current.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Test-Windows11 {
    $build = [System.Environment]::OSVersion.Version.Build
    return $build -ge 22000
}

function New-RestorePoint {
    if ($DryRun) { Write-Log 'DryRun: would create System Restore Point' 'INFO'; return }
    try {
        Enable-ComputerRestore -Drive "$env:SystemDrive\"
        Checkpoint-Computer -Description 'WinForge Pre-Install' -RestorePointType 'APPLICATION_INSTALL'
        Write-Log 'System Restore Point created' 'SUCCESS'
    } catch {
        Write-Log "Restore Point failed (non-fatal): $_" 'WARN'
    }
}

function Install-Scoop {
    if (Get-Command scoop -ErrorAction SilentlyContinue) {
        Write-Log 'Scoop already installed'
        return
    }
    Write-Log 'Installing Scoop...'
    if ($DryRun) { Write-Log 'DryRun: would install Scoop'; return }
    Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
    Invoke-RestMethod get.scoop.sh | Invoke-Expression
    scoop bucket add extras
    scoop bucket add versions
    Write-Log 'Scoop installed' 'SUCCESS'
}

function Install-WingetPackages {
    param([array]$Packages)
    foreach ($pkg in $Packages) {
        if ($pkg.manager -eq 'scoop') {
            Write-Log "Installing via Scoop: $($pkg.id)"
            if (-not $DryRun) {
                scoop install $pkg.id 2>&1 | Out-Null
                Write-Log "Scoop installed: $($pkg.id)" 'SUCCESS'
            }
            continue
        }
        Write-Log "Installing via winget: $($pkg.id)"
        if ($DryRun) { continue }
        try {
            $args = @(
                'install',
                '--id', $pkg.id,
                '--exact',
                '--silent',
                '--accept-package-agreements',
                '--accept-source-agreements'
            )
            if ($pkg.scope) { $args += '--scope'; $args += $pkg.scope }
            winget @args 2>&1 | Out-Null
            Write-Log "Installed: $($pkg.id)" 'SUCCESS'
        } catch {
            Write-Log "Failed: $($pkg.id) — $_" 'ERROR'
        }
    }
}

function Deploy-Configs {
    $configRoot = Join-Path $script:ScriptRoot 'configs'

    # Windows Terminal
    $wtTarget = Get-ChildItem "$env:LOCALAPPDATA\Packages" -Filter 'Microsoft.WindowsTerminal*' -ErrorAction SilentlyContinue |
        Select-Object -First 1 | ForEach-Object { "$($_.FullName)\LocalState" }
    if ($wtTarget) {
        Copy-Config "$configRoot\terminal\settings.json" "$wtTarget\settings.json"
    }

    # PowerShell Profile
    $psDir = Split-Path $PROFILE -Parent
    if (-not (Test-Path $psDir)) { New-Item $psDir -ItemType Directory -Force | Out-Null }
    Copy-Config "$configRoot\powershell\Microsoft.PowerShell_profile.ps1" $PROFILE

    # VS Code
    $codeUser = "$env:APPDATA\Code\User"
    if (-not (Test-Path $codeUser)) { New-Item $codeUser -ItemType Directory -Force | Out-Null }
    Copy-Config "$configRoot\vscode\settings.json"    "$codeUser\settings.json"
    Copy-Config "$configRoot\vscode\keybindings.json" "$codeUser\keybindings.json"

    # VS Code Extensions
    if (Get-Command code -ErrorAction SilentlyContinue) {
        $exts = (Get-Content "$configRoot\vscode\extensions.json" | ConvertFrom-Json).recommendations
        foreach ($ext in $exts) {
            Write-Log "Installing VS Code extension: $ext"
            if (-not $DryRun) { code --install-extension $ext --force 2>&1 | Out-Null }
        }
    }

    # AutoHotKey
    $ahkDir = "$env:USERPROFILE\Documents\AutoHotkey"
    if (-not (Test-Path $ahkDir)) { New-Item $ahkDir -ItemType Directory -Force | Out-Null }
    Copy-Config "$configRoot\ahk\winforge.ahk" "$ahkDir\winforge.ahk"

    # Espanso
    $espansoDir = "$env:APPDATA\espanso\match"
    if (-not (Test-Path $espansoDir)) { New-Item $espansoDir -ItemType Directory -Force | Out-Null }
    Copy-Config "$configRoot\espanso\default.yml" "$espansoDir\winforge.yml"

    # Starship
    $starshipDir = "$env:USERPROFILE\.config"
    if (-not (Test-Path $starshipDir)) { New-Item $starshipDir -ItemType Directory -Force | Out-Null }
    Copy-Config "$configRoot\wsl\starship.toml" "$starshipDir\starship.toml"
}

function Copy-Config {
    param([string]$Src, [string]$Dst)
    if (-not (Test-Path $Src)) { Write-Log "Config not found: $Src" 'WARN'; return }
    if ($DryRun) { Write-Log "DryRun: would copy $Src → $Dst"; return }
    Copy-Item $Src $Dst -Force
    Write-Log "Config deployed: $Dst" 'SUCCESS'
}

# ── MAIN ──────────────────────────────────────────────────────────────────────

Write-Log '══════════════════════════════════════'
Write-Log '  WinForge v1.0 — Windows 11 Setup'
Write-Log '══════════════════════════════════════'

if (-not (Test-Admin)) {
    Write-Log 'ERROR: Must run as Administrator. Re-launch PowerShell as Admin.' 'ERROR'
    exit 1
}

if (-not (Test-Windows11)) {
    Write-Log 'WARNING: Windows 11 (Build 22000+) is recommended. Continuing anyway...' 'WARN'
}

if ($DryRun) { Write-Log '*** DRY-RUN MODE — no changes will be made ***' 'WARN' }

# Tier selection
if (-not $Tier) {
    Write-Host ""
    Write-Host "  Select install tier:" -ForegroundColor Cyan
    Write-Host "  [1] Core        — 15 essential apps" -ForegroundColor White
    Write-Host "  [2] PowerUser   — Core + 20 power-user apps" -ForegroundColor White
    Write-Host "  [3] Dev         — PowerUser + 25 dev tools" -ForegroundColor White
    Write-Host "  [4] AI          — Dev + 15 AI tools" -ForegroundColor White
    Write-Host ""
    $choice = Read-Host "Enter 1-4"
    $Tier = switch ($choice) {
        '1' { 'Core' }
        '2' { 'PowerUser' }
        '3' { 'Dev' }
        '4' { 'AI' }
        default { Write-Log 'Invalid choice, defaulting to Core' 'WARN'; 'Core' }
    }
}

Write-Log "Selected tier: $Tier"

# Restore point
if (-not $NoRestore) { New-RestorePoint }

# Install apps
if (-not $SkipApps) {
    Install-Scoop
    $tierMap = @{
        'Core'      = @('core')
        'PowerUser' = @('core','poweruser')
        'Dev'       = @('core','poweruser','dev')
        'AI'        = @('core','poweruser','dev','ai')
    }
    $allPackages = @()
    foreach ($t in $tierMap[$Tier]) {
        $jsonPath = Join-Path $script:ScriptRoot "tiers\${t}.json"
        if (Test-Path $jsonPath) {
            $allPackages += Get-Content $jsonPath | ConvertFrom-Json
        }
    }
    Write-Log "Installing $($allPackages.Count) packages..."
    Install-WingetPackages -Packages $allPackages
}

# Configs
if (-not $SkipConfigs) {
    Write-Log 'Deploying configuration files...'
    Deploy-Configs
}

# Debloat
if (-not $SkipDebloat) {
    $debloatScript = Join-Path $script:ScriptRoot 'scripts\debloat.ps1'
    if (Test-Path $debloatScript) {
        Write-Log 'Running debloat script...'
        if (-not $DryRun) { & $debloatScript }
        else { Write-Log 'DryRun: would run debloat.ps1' }
    }
}

# Tweaks
if (-not $SkipTweaks) {
    $tweaksScript = Join-Path $script:ScriptRoot 'scripts\tweaks.ps1'
    if (Test-Path $tweaksScript) {
        Write-Log 'Running tweaks script...'
        if (-not $DryRun) { & $tweaksScript }
        else { Write-Log 'DryRun: would run tweaks.ps1' }
    }
}

Write-Log '══════════════════════════════════════' 'SUCCESS'
Write-Log "  WinForge setup complete!" 'SUCCESS'
Write-Log "  Log: $script:LogFile" 'SUCCESS'
Write-Log '══════════════════════════════════════' 'SUCCESS'
Write-Log 'Restart your machine to apply all changes.' 'WARN'

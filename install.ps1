#Requires -Version 5.1
<#
.SYNOPSIS
    WinForge - Windows 11 power-user setup script
.DESCRIPTION
    Detects Windows version, prompts for tier, installs everything via winget and Scoop.
    Deploys configs, runs debloat and tweaks sub-scripts.
.PARAMETER Tier
    Install tier: Core | PowerUser | Dev | AI (optional - prompts if not provided)
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
    [string]$Tier,
    [switch]$DryRun,
    [switch]$SkipApps,
    [switch]$SkipConfigs,
    [switch]$SkipDebloat,
    [switch]$SkipTweaks,
    [switch]$NoRestore
)

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
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $p  = [Security.Principal.WindowsPrincipal]$id
    return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Test-Windows11 {
    $build = [System.Environment]::OSVersion.Version.Build
    return $build -ge 22000
}

function Get-TierSelection {
    if ($Tier -and $Tier -in @('Core','PowerUser','Dev','AI')) {
        return $Tier
    }
    Write-Host ""
    Write-Host "  Select install tier:"
    Write-Host "  [1] Core        - 15 essential apps"
    Write-Host "  [2] PowerUser   - Core + 20 power-user apps"
    Write-Host "  [3] Dev         - PowerUser + 25 dev tools"
    Write-Host "  [4] AI          - Dev + 15 AI tools"
    Write-Host ""
    do {
        $choice = Read-Host "Enter 1-4"
    } until ($choice -in @('1','2','3','4'))
    switch ($choice) {
        '1' { return 'Core' }
        '2' { return 'PowerUser' }
        '3' { return 'Dev' }
        '4' { return 'AI' }
    }
}

function Install-Scoop {
    if (Get-Command scoop -ErrorAction SilentlyContinue) {
        Write-Log "Scoop already installed - skipping"
        return
    }
    Write-Log "Installing Scoop..."
    try {
        Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force -ErrorAction SilentlyContinue
    } catch {
        Write-Log "ExecutionPolicy note: $($_.Exception.Message) (non-fatal, continuing)" 'WARN'
    }
    try {
        Invoke-RestMethod -Uri https://get.scoop.sh -UseBasicParsing | Invoke-Expression
        Write-Log "Scoop installed" 'SUCCESS'
    } catch {
        Write-Log "Scoop install failed: $_" 'ERROR'
    }
}

function Install-WingetApp {
    param([string]$Id, [string]$Name)
    Write-Log "Installing $Name ($Id)..."
    if ($DryRun) { Write-Log "[DryRun] Would install $Id"; return }
    $result = winget install --id $Id --exact --silent --accept-package-agreements --accept-source-agreements 2>&1
    if ($LASTEXITCODE -eq 0 -or $LASTEXITCODE -eq -1978335212) {
        Write-Log "$Name installed" 'SUCCESS'
    } else {
        Write-Log "$Name failed (exit $LASTEXITCODE): $result" 'WARN'
    }
}

function Install-ScoopApp {
    param([string]$Name, [string]$Bucket = 'main')
    Write-Log "Installing $Name via Scoop..."
    if ($DryRun) { Write-Log "[DryRun] Would scoop install $Name"; return }
    scoop install $Name 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-Log "$Name installed" 'SUCCESS'
    } else {
        Write-Log "$Name scoop install failed" 'WARN'
    }
}

function Get-TierApps {
    param([string]$SelectedTier)
    $tiers = @('Core')
    if ($SelectedTier -in @('PowerUser','Dev','AI')) { $tiers += 'PowerUser' }
    if ($SelectedTier -in @('Dev','AI'))              { $tiers += 'Dev' }
    if ($SelectedTier -eq 'AI')                       { $tiers += 'AI' }

    $apps = @()
    foreach ($t in $tiers) {
        $manifestPath = Join-Path $script:ScriptRoot "tiers\$t.json"
        if (Test-Path $manifestPath) {
            $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
            $apps += $manifest.apps
        } else {
            Write-Log "Manifest not found: $manifestPath" 'WARN'
        }
    }
    return $apps
}

function Install-Apps {
    param([string]$SelectedTier)
    $apps = Get-TierApps -SelectedTier $SelectedTier
    Write-Log "Installing $($apps.Count) apps for tier: $SelectedTier"
    foreach ($app in $apps) {
        switch ($app.manager) {
            'winget' { Install-WingetApp -Id $app.id -Name $app.name }
            'scoop'  { Install-ScoopApp -Name $app.id }
            'manual' { Write-Log "Manual install required for $($app.name): $($app.id)" 'WARN' }
            'script' { Write-Log "Script/bootstrap step required for $($app.name): $($app.id)" 'WARN' }
            default  { Write-Log "Unknown manager '$($app.manager)' for $($app.name); skipping" 'WARN' }
        }
    }
}

function Deploy-Configs {
    param([string]$SelectedTier)
    Write-Log "Deploying configurations..."
    $configRoot = Join-Path $script:ScriptRoot 'configs'

    # Windows Terminal
    $wtSettings = Join-Path $configRoot 'terminal\settings.json'
    $wtTarget   = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
    if ((Test-Path $wtSettings) -and (Test-Path (Split-Path $wtTarget))) {
        if (-not $DryRun) { Copy-Item $wtSettings $wtTarget -Force }
        Write-Log "Windows Terminal settings deployed" 'SUCCESS'
    }

    # PowerShell profile
    $psProfile = Join-Path $configRoot 'powershell\Microsoft.PowerShell_profile.ps1'
    if (Test-Path $psProfile) {
        $targetDir = Split-Path $PROFILE.CurrentUserAllHosts
        if (-not (Test-Path $targetDir)) { New-Item -ItemType Directory -Path $targetDir -Force | Out-Null }
        if (-not $DryRun) { Copy-Item $psProfile $PROFILE.CurrentUserAllHosts -Force }
        Write-Log "PowerShell profile deployed" 'SUCCESS'
    }

    # VS Code
    if ($SelectedTier -in @('Dev','AI')) {
        $vsCodeDir = "$env:APPDATA\Code\User"
        if (-not (Test-Path $vsCodeDir)) { New-Item -ItemType Directory -Path $vsCodeDir -Force | Out-Null }
        foreach ($f in @('settings.json','keybindings.json')) {
            $src = Join-Path $configRoot "vscode\$f"
            if (Test-Path $src) {
                if (-not $DryRun) { Copy-Item $src "$vsCodeDir\$f" -Force }
                Write-Log "VS Code $f deployed" 'SUCCESS'
            }
        }
        # Install VS Code extensions
        $extFile = Join-Path $configRoot 'vscode\extensions.json'
        if ((Test-Path $extFile) -and (Get-Command code -ErrorAction SilentlyContinue)) {
            $exts = (Get-Content $extFile | ConvertFrom-Json).recommendations
            foreach ($ext in $exts) {
                if (-not $DryRun) { code --install-extension $ext --force 2>&1 | Out-Null }
                Write-Log "VS Code extension: $ext" 'SUCCESS'
            }
        }
    }

    # AutoHotKey script
    $ahkSrc = Join-Path $configRoot 'ahk\winforge.ahk'
    $ahkDst = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\winforge.ahk"
    if (Test-Path $ahkSrc) {
        if (-not $DryRun) { Copy-Item $ahkSrc $ahkDst -Force }
        Write-Log "AutoHotKey startup script deployed" 'SUCCESS'
    }

    # Espanso
    $espansoCfg = Join-Path $configRoot 'espanso\default.yml'
    $espansoDst = "$env:APPDATA\espanso\match\default.yml"
    if ((Test-Path $espansoCfg) -and (Test-Path (Split-Path $espansoDst -ErrorAction SilentlyContinue))) {
        if (-not $DryRun) { Copy-Item $espansoCfg $espansoDst -Force }
        Write-Log "Espanso config deployed" 'SUCCESS'
    }
}

function New-RestorePoint {
    Write-Log "Creating System Restore Point..."
    try {
        Enable-ComputerRestore -Drive "$env:SystemDrive" -ErrorAction SilentlyContinue
        Checkpoint-Computer -Description 'WinForge Pre-Install' -RestorePointType 'MODIFY_SETTINGS' -ErrorAction Stop
        Write-Log "System Restore Point created" 'SUCCESS'
    } catch {
        Write-Log "Restore point skipped: $($_.Exception.Message)" 'WARN'
    }
}

# ── MAIN ────────────────────────────────────────────────────────────────────

$ErrorActionPreference = 'Continue'

Write-Log "══════════════════════════════════════"
Write-Log "  WinForge v1.0 - Windows 11 Setup"
Write-Log "══════════════════════════════════════"

if (-not (Test-Admin)) {
    Write-Log "Not running as Administrator - some installs may fail. Re-run as Admin for best results." 'WARN'
}

if (-not (Test-Windows11)) {
    Write-Log "Windows 11 not detected (build $([System.Environment]::OSVersion.Version.Build)). Script is designed for Windows 11." 'WARN'
}

$selectedTier = Get-TierSelection
Write-Log "Selected tier: $selectedTier"

if (-not $NoRestore -and -not $DryRun) {
    New-RestorePoint
}

Install-Scoop

if (-not $SkipApps) {
    Install-Apps -SelectedTier $selectedTier
}

if (-not $SkipConfigs) {
    Deploy-Configs -SelectedTier $selectedTier
}

if (-not $SkipDebloat) {
    $debloatScript = Join-Path $script:ScriptRoot 'scripts\debloat.ps1'
    if (Test-Path $debloatScript) {
        Write-Log "Running debloat sub-script..."
        if (-not $DryRun) { & $debloatScript }
        Write-Log "Debloat complete" 'SUCCESS'
    }
}

if (-not $SkipTweaks) {
    $tweaksScript = Join-Path $script:ScriptRoot 'scripts\tweaks.ps1'
    if (Test-Path $tweaksScript) {
        Write-Log "Running tweaks sub-script..."
        if (-not $DryRun) { & $tweaksScript }
        Write-Log "Tweaks complete" 'SUCCESS'
    }
}

Write-Log "══════════════════════════════════════"
Write-Log "  WinForge complete! Log: $script:LogFile" 'SUCCESS'
Write-Log "══════════════════════════════════════"

Write-Host ""
Write-Host "  All done! Please RESTART your machine for all changes to take effect." -ForegroundColor Green
Write-Host "  Log saved to: $script:LogFile" -ForegroundColor Cyan
Write-Host ""

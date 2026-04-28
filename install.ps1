<#
.SYNOPSIS
    WinForge — Windows 11 setup orchestrator.

.DESCRIPTION
    Installs a tiered set of applications, applies sensible tweaks, optionally
    debloats consumer apps, and lays down dotfiles/configs for Windows Terminal,
    PowerShell, VS Code, PowerToys, AutoHotkey, espanso, and WSL.

    Run from an elevated PowerShell session.

.PARAMETER Tier
    Which tier to install. One of: minimal, standard, power-user, dev, ai, all.
    "minimal" = core only.
    "standard" = core (alias for minimal in current build; reserved for future).
    "power-user" = core + power-user.
    "dev" = above + dev.
    "ai" = above + ai.
    "all" = ai (full chain).

.PARAMETER DryRun
    Print every action that would be taken; change nothing.

.PARAMETER SkipDebloat
    Do not run scripts/debloat.ps1.

.PARAMETER SkipTweaks
    Do not run scripts/tweaks.ps1.

.PARAMETER SkipConfigs
    Do not deploy configs/* dotfiles.

.PARAMETER Force
    Override OS-version guard (e.g. run on Windows 10 or Server).

.EXAMPLE
    .\install.ps1 -Tier dev

.EXAMPLE
    .\install.ps1 -Tier ai -DryRun

.NOTES
    Logs:    %ProgramData%\WinForge\logs\winforge-<timestamp>.log
    State:   %ProgramData%\WinForge\state.json
    Backups: %ProgramData%\WinForge\backups\
#>
[CmdletBinding()]
param(
    [ValidateSet('minimal','standard','power-user','dev','ai','all')]
    [string]$Tier,

    [switch]$DryRun,
    [switch]$SkipDebloat,
    [switch]$SkipTweaks,
    [switch]$SkipConfigs,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# --- Resolve script root and import module -----------------------------------
$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
Import-Module (Join-Path $ScriptRoot 'scripts\lib\WinForge.psm1') -Force

Initialize-WinForge -DryRun:$DryRun
$paths = Get-WinForgePaths

Write-WinForgeBanner "WinForge — Windows 11 setup"
Write-WinForgeLog "Repo root : $($paths.Root)"
Write-WinForgeLog "Log file  : $($paths.LogFile)"
Write-WinForgeLog "Dry run   : $DryRun"

try {
    Assert-WinForgePrereqs -Force:$Force
} catch {
    Write-WinForgeLog $_ Error
    exit 1
}

# --- Interactive tier selection ----------------------------------------------
if (-not $Tier) {
    Write-Host ""
    Write-Host "Select a tier:" -ForegroundColor Cyan
    Write-Host "  1) minimal     — Core 15 essentials"
    Write-Host "  2) power-user  — Core 15 + Power-user +20 (productivity, window mgmt, sync)"
    Write-Host "  3) dev         — + Dev +23 (WSL2, Docker, VS Code, fnm, uv, Rust, Go, DB GUIs)"
    Write-Host "  4) ai          — + AI +10 (Ollama, LM Studio, Cursor, Claude Desktop, etc.)"
    Write-Host "  5) all         — same as ai"
    $choice = Read-Host "Enter choice [1-5] (default 2)"
    switch ($choice) {
        '1' { $Tier = 'minimal' }
        '3' { $Tier = 'dev' }
        '4' { $Tier = 'ai' }
        '5' { $Tier = 'all' }
        default { $Tier = 'power-user' }
    }
}

$tierMap = @{
    'minimal'    = 'core'
    'standard'   = 'core'
    'power-user' = 'power-user'
    'dev'        = 'dev'
    'ai'         = 'ai'
    'all'        = 'ai'
}
$resolvedTier = $tierMap[$Tier]
Write-WinForgeLog "Resolved tier: $Tier -> $resolvedTier" Step

# --- Load manifest -----------------------------------------------------------
$manifest = Get-WinForgeManifest
$packages = Resolve-WinForgeTier -Manifest $manifest -Tier $resolvedTier
Write-WinForgeLog "Packages to consider: $($packages.Count)"

# --- Restore point -----------------------------------------------------------
New-WinForgeRestorePoint -Description "WinForge install ($Tier)"

# --- Bootstrap package managers ---------------------------------------------
Write-WinForgeBanner "Bootstrapping package managers"
Install-WinForgeWinget
Install-WinForgeScoop -Buckets ($manifest.scoopBuckets)

# --- Install packages --------------------------------------------------------
Write-WinForgeBanner "Installing packages ($Tier)"
$results = New-Object System.Collections.Generic.List[object]
foreach ($pkg in $packages) {
    try {
        $r = Install-WinForgePackage -Package $pkg
        if ($r) { $results.Add($r) | Out-Null }
    } catch {
        Write-WinForgeLog "Exception while installing $($pkg.id): $_" Error
    }
}

# --- Summary table -----------------------------------------------------------
Write-WinForgeBanner "Package install summary"
$grouped = $results | Group-Object Status
foreach ($g in $grouped) {
    Write-WinForgeLog ("{0,-20} {1}" -f $g.Name, $g.Count)
}
$results | Export-Csv -Path (Join-Path $paths.Logs ('package-results-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.csv')) -NoTypeInformation

# --- Tweaks ------------------------------------------------------------------
if (-not $SkipTweaks) {
    Write-WinForgeBanner "Applying tweaks"
    & (Join-Path $ScriptRoot 'scripts\tweaks.ps1') -Mode Apply -DryRun:$DryRun
} else {
    Write-WinForgeLog "Skipping tweaks (--SkipTweaks)" Warn
}

# --- Debloat -----------------------------------------------------------------
if (-not $SkipDebloat) {
    Write-WinForgeBanner "Debloating consumer apps"
    & (Join-Path $ScriptRoot 'scripts\debloat.ps1') -Mode Apply -DryRun:$DryRun
} else {
    Write-WinForgeLog "Skipping debloat (--SkipDebloat)" Warn
}

# --- Configs -----------------------------------------------------------------
if (-not $SkipConfigs) {
    Write-WinForgeBanner "Deploying configs"
    & (Join-Path $ScriptRoot 'scripts\deploy-configs.ps1') -DryRun:$DryRun
} else {
    Write-WinForgeLog "Skipping configs (--SkipConfigs)" Warn
}

# --- VS Code extensions ------------------------------------------------------
if (-not $SkipConfigs -and (Test-Command code)) {
    Write-WinForgeBanner "Installing VS Code extensions"
    foreach ($ext in $manifest.vscodeExtensions) {
        if ($DryRun) {
            Write-WinForgeLog "Would install code extension $ext" DryRun
        } else {
            Write-WinForgeLog "code --install-extension $ext"
            try { & code --install-extension $ext --force 2>&1 | Out-Null } catch { Write-WinForgeLog "ext failed: $ext" Warn }
        }
    }
}

# --- WSL bootstrap -----------------------------------------------------------
if ($resolvedTier -in @('dev','ai')) {
    Write-WinForgeBanner "Provisioning WSL2 + Ubuntu"
    if ($DryRun) {
        Write-WinForgeLog "Would run wsl --install -d Ubuntu-24.04 and copy bootstrap-ubuntu.sh" DryRun
    } else {
        try {
            wsl --set-default-version 2 2>&1 | Out-Null
            $existing = (wsl -l -q) 2>&1
            if ($existing -notmatch 'Ubuntu') {
                Write-WinForgeLog "Installing Ubuntu via WSL — a reboot may be required."
                wsl --install -d Ubuntu-24.04 --no-launch
            } else {
                Write-WinForgeLog "WSL distro already installed: $existing" Ok
            }
            $bootstrap = Join-Path $ScriptRoot 'configs\wsl\bootstrap-ubuntu.sh'
            if (Test-Path $bootstrap) {
                Write-WinForgeLog "Bootstrap script ready at: $bootstrap"
                Write-WinForgeLog "After first WSL launch, run: wsl -- bash /mnt/$(((Get-Location).Drive.Name).ToLower())/.../winforge/configs/wsl/bootstrap-ubuntu.sh" Step
            }
        } catch {
            Write-WinForgeLog "WSL provisioning failed: $_" Warn
        }
    }
}

Write-WinForgeBanner "WinForge complete"
Write-WinForgeLog "Log file : $($paths.LogFile)" Ok
Write-WinForgeLog "State    : $($paths.StateFile)" Ok
Write-WinForgeLog "Reboot recommended to finalize." Warn

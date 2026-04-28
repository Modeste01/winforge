<#
.SYNOPSIS
    Reverse a WinForge run.

.DESCRIPTION
    By default, performs a SAFE rollback:
      - Reverts tweaks (using saved registry backups via scripts/tweaks.ps1 -Mode Revert).
      - Restores debloat allow/deny state where possible (scripts/debloat.ps1 -Mode Restore).
      - Removes deployed dotfiles symlinks/copies if known.
      - Leaves installed apps in place.

    With -RemovePackages, also uninstalls every package recorded in state.json.

.PARAMETER RemovePackages
    Also uninstall every package WinForge installed.

.PARAMETER DryRun
    Print what would happen; change nothing.

.PARAMETER Force
    Bypass confirmation prompts.

.EXAMPLE
    .\uninstall.ps1
.EXAMPLE
    .\uninstall.ps1 -RemovePackages -Force
#>
[CmdletBinding()]
param(
    [switch]$RemovePackages,
    [switch]$DryRun,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
Import-Module (Join-Path $ScriptRoot 'scripts\lib\WinForge.psm1') -Force
Initialize-WinForge -DryRun:$DryRun

$paths = Get-WinForgePaths
Write-WinForgeBanner "WinForge uninstall"
Write-WinForgeLog "Mode: $(if ($RemovePackages) {'FULL (config + packages)'} else {'SAFE (config only)'})" Step

if (-not $Force -and -not $DryRun) {
    $resp = Read-Host "Proceed? (y/N)"
    if ($resp -notmatch '^[Yy]') { Write-WinForgeLog "Aborted by user." Warn; exit 0 }
}

# --- Revert tweaks -----------------------------------------------------------
Write-WinForgeBanner "Reverting tweaks"
& (Join-Path $ScriptRoot 'scripts\tweaks.ps1') -Mode Revert -DryRun:$DryRun

# --- Restore debloated apps where possible -----------------------------------
Write-WinForgeBanner "Restoring debloated apps"
& (Join-Path $ScriptRoot 'scripts\debloat.ps1') -Mode Restore -DryRun:$DryRun

# --- Remove dotfile copies ---------------------------------------------------
Write-WinForgeBanner "Removing deployed configs"
$state = Get-WinForgeState
if ($state -and $state.PSObject.Properties['configsDeployed']) {
    foreach ($c in $state.configsDeployed) {
        if (Test-Path $c) {
            if ($DryRun) {
                Write-WinForgeLog "Would remove deployed config: $c" DryRun
            } else {
                try { Remove-Item -Path $c -Force -Recurse -ErrorAction Stop; Write-WinForgeLog "Removed $c" Ok }
                catch { Write-WinForgeLog "Could not remove ${c}: $_" Warn }
            }
        }
    }
} else {
    Write-WinForgeLog "No config deployment records found in state.json" Warn
}

# --- Optionally remove packages ---------------------------------------------
if ($RemovePackages) {
    Write-WinForgeBanner "Uninstalling packages installed by WinForge"
    if (-not $state -or -not $state.PSObject.Properties['packagesInstalled']) {
        Write-WinForgeLog "No package records found." Warn
    } else {
        foreach ($p in $state.packagesInstalled) {
            $id = $p.id; $src = $p.source
            if ($DryRun) {
                Write-WinForgeLog "Would uninstall [$src] $id" DryRun
                continue
            }
            try {
                switch ($src) {
                    'winget' {
                        Write-WinForgeLog "winget uninstall $id"
                        Start-Process winget -ArgumentList @('uninstall','--id',$id,'--exact','--silent','--accept-source-agreements') -Wait -NoNewWindow | Out-Null
                    }
                    'scoop' {
                        Write-WinForgeLog "scoop uninstall $id"
                        & scoop uninstall $id 2>&1 | Out-Null
                    }
                    default { Write-WinForgeLog "Unknown source $src for $id; skipping." Warn }
                }
            } catch {
                Write-WinForgeLog "Uninstall failed for ${id}: $_" Warn
            }
        }
    }
} else {
    Write-WinForgeLog "Packages preserved. Re-run with -RemovePackages to uninstall." Ok
}

Write-WinForgeBanner "WinForge uninstall complete"
Write-WinForgeLog "Backups remain at: $($paths.Backups)"
Write-WinForgeLog "Logs    remain at: $($paths.Logs)"

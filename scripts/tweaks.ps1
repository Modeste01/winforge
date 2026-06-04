#Requires -Version 5.1
<#
.SYNOPSIS
    WinForge Tweaks — registry tweaks for performance, Explorer, taskbar, privacy
.DESCRIPTION
    Reversible: all registry keys backed up to WinForge_Backups\ before changes.
#>
[CmdletBinding(SupportsShouldProcess)]
param([switch]$DryRun)

$backupDir = "$PSScriptRoot\..\WinForge_Backups\tweaks_$(Get-Date -Format 'yyyyMMdd_HHmmss')"

function Backup-Registry {
    param([string]$Path, [string]$Name)
    if ($DryRun) { return }
    if (-not (Test-Path $backupDir)) { New-Item $backupDir -ItemType Directory -Force | Out-Null }
    try { reg export $Path "$backupDir\${Name}.reg" /y 2>&1 | Out-Null } catch {}
}

function Set-Reg {
    param([string]$Path, [string]$Name, $Value, [string]$Type = 'DWord')
    if ($DryRun) { Write-Host "DryRun: $Path\$Name = $Value"; return }
    if (-not (Test-Path $Path)) { New-Item $Path -Force | Out-Null }
    Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type -ErrorAction SilentlyContinue
}

Write-Host "WinForge Tweaks" -ForegroundColor Cyan

# ── Explorer ──────────────────────────────────────────────────────────────────
Backup-Registry 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'explorer'
Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'HideFileExt'          0  # Show file extensions
Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'Hidden'               1  # Show hidden files
Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'ShowSuperHidden'      0  # Hide system files (safe)
Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'LaunchTo'             1  # Open Explorer to This PC
Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'NavPaneExpandToCurrentFolder' 1
Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'NavPaneShowAllFolders' 1
Write-Host "  Explorer tweaks applied" -ForegroundColor Green

# ── Taskbar ───────────────────────────────────────────────────────────────────
Backup-Registry 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'taskbar'
Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'TaskbarSmallIcons'  0
Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'ShowTaskViewButton' 0  # Hide Task View button
Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'ShowCopilotButton'  0  # Hide Copilot button
Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search' 'SearchboxTaskbarMode' 1             # Search icon only
Write-Host "  Taskbar tweaks applied" -ForegroundColor Green

# ── Performance ───────────────────────────────────────────────────────────────
Backup-Registry 'HKCU:\Control Panel\Desktop' 'desktop'
Set-Reg 'HKCU:\Control Panel\Desktop' 'MenuShowDelay' '0' 'String'
Set-Reg 'HKCU:\Control Panel\Desktop' 'WaitToKillAppTimeout' '2000' 'String'
Set-Reg 'HKCU:\Control Panel\Desktop' 'HungAppTimeout' '1000' 'String'
Set-Reg 'HKCU:\Control Panel\Desktop\WindowMetrics' 'MinAnimate' '0' 'String'

# Set High Performance power plan
if (-not $DryRun) {
    powercfg -setactive SCHEME_MIN 2>&1 | Out-Null
    Write-Host "  Power plan set to High Performance" -ForegroundColor Green
}

# NumLock on at startup
Set-Reg 'HKCU:\Control Panel\Keyboard' 'InitialKeyboardIndicators' 2
Write-Host "  NumLock on at startup" -ForegroundColor Green

# ── Privacy ───────────────────────────────────────────────────────────────────
Backup-Registry 'HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo' 'advertising'
Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo' 'Enabled' 0
Set-Reg 'HKCU:\Software\Microsoft\InputPersonalization' 'RestrictImplicitInkCollection' 1
Set-Reg 'HKCU:\Software\Microsoft\InputPersonalization' 'RestrictImplicitTextCollection' 1
Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy' 'TailoredExperiencesWithDiagnosticDataEnabled' 0
Write-Host "  Privacy tweaks applied" -ForegroundColor Green

# ── Disable Sticky Keys popup ─────────────────────────────────────────────────
Set-Reg 'HKCU:\Control Panel\Accessibility\StickyKeys' 'Flags' '506' 'String'
Set-Reg 'HKCU:\Control Panel\Accessibility\ToggleKeys' 'Flags' '58'  'String'
Set-Reg 'HKCU:\Control Panel\Accessibility\Keyboard Response' 'Flags' '122' 'String'
Write-Host "  Sticky Keys popup disabled" -ForegroundColor Green

# Restart Explorer to apply
if (-not $DryRun) {
    Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
    Start-Sleep 1
    Start-Process explorer
    Write-Host "  Explorer restarted" -ForegroundColor Green
}

Write-Host "Tweaks complete. Backups saved to: $backupDir" -ForegroundColor Cyan

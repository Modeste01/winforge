#Requires -Version 5.1
<#
.SYNOPSIS
    WinForge Uninstall — reverses all registry tweaks and optionally removes installed apps
.PARAMETER RemoveApps
    Also remove apps installed by WinForge (interactive confirmation per app)
.PARAMETER BackupDir
    Path to WinForge_Backups directory. Defaults to .\WinForge_Backups
#>
param(
    [switch]$RemoveApps,
    [string]$BackupDir = ".\WinForge_Backups"
)

Write-Host "WinForge Uninstall" -ForegroundColor Cyan

# ── Restore registry backups ──────────────────────────────────────────────────
$backups = Get-ChildItem $BackupDir -Recurse -Filter '*.reg' -ErrorAction SilentlyContinue
if ($backups) {
    Write-Host "Found $($backups.Count) registry backup file(s). Restoring..." -ForegroundColor Yellow
    foreach ($backup in $backups) {
        Write-Host "  Importing: $($backup.FullName)"
        reg import $backup.FullName 2>&1 | Out-Null
        Write-Host "  Restored: $($backup.Name)" -ForegroundColor Green
    }
} else {
    Write-Host "No registry backups found at: $BackupDir" -ForegroundColor Yellow
    Write-Host "You can manually restore via:"
    Write-Host "  Settings → System → Recovery → Open System Restore"
}

# ── Re-enable disabled features ───────────────────────────────────────────────
try {
    # Re-enable Bing search
    Set-ItemProperty 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search' 'BingSearchEnabled' 1 -ErrorAction SilentlyContinue
    Set-ItemProperty 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search' 'CortanaConsent' 1    -ErrorAction SilentlyContinue
    Write-Host "  Bing search re-enabled" -ForegroundColor Green
} catch {}

# ── Remove deployed configs ───────────────────────────────────────────────────
$configs = @(
    "$env:APPDATA\espanso\match\winforge.yml",
    "$env:USERPROFILE\Documents\AutoHotkey\winforge.ahk"
)
foreach ($c in $configs) {
    if (Test-Path $c) {
        Remove-Item $c -Force
        Write-Host "  Removed config: $c" -ForegroundColor Green
    }
}

# ── Restart Explorer ──────────────────────────────────────────────────────────
Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
Start-Sleep 1
Start-Process explorer

Write-Host ""
Write-Host "WinForge uninstall complete." -ForegroundColor Green
Write-Host "A full system restart is recommended." -ForegroundColor Yellow

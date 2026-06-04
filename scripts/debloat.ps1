#Requires -Version 5.1
<#
.SYNOPSIS
    WinForge Debloat — removes Windows 11 bloat and disables telemetry
.DESCRIPTION
    Reversible: all registry keys backed up to WinForge_Backups\ before changes.
#>
[CmdletBinding(SupportsShouldProcess)]
param([switch]$DryRun)

$backupDir = "$PSScriptRoot\..\WinForge_Backups\registry_backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"

function Backup-Registry {
    param([string]$Path, [string]$Name)
    if ($DryRun) { return }
    if (-not (Test-Path $backupDir)) { New-Item $backupDir -ItemType Directory -Force | Out-Null }
    try {
        reg export $Path "$backupDir\${Name}.reg" /y 2>&1 | Out-Null
    } catch {}
}

function Remove-AppxSafe {
    param([string]$Name)
    Get-AppxPackage -AllUsers -Name "*$Name*" -ErrorAction SilentlyContinue |
        Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
    Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue |
        Where-Object { $_.PackageName -like "*$Name*" } |
        Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Out-Null
    Write-Host "  Removed: $Name" -ForegroundColor Green
}

function Set-RegistryValue {
    param([string]$Path, [string]$Name, $Value, [string]$Type = 'DWord')
    if ($DryRun) { Write-Host "DryRun: $Path\$Name = $Value"; return }
    if (-not (Test-Path $Path)) { New-Item $Path -Force | Out-Null }
    Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type -ErrorAction SilentlyContinue
}

Write-Host "WinForge Debloat" -ForegroundColor Cyan

# ── Remove bloat apps ─────────────────────────────────────────────────────────
$bloat = @(
    'Microsoft.BingWeather',
    'Microsoft.BingNews',
    'Microsoft.BingFinance',
    'Microsoft.BingSports',
    'Microsoft.BingSearch',
    'Microsoft.GetHelp',
    'Microsoft.Getstarted',
    'Microsoft.MicrosoftSolitaireCollection',
    'Microsoft.MicrosoftOfficeHub',
    'Microsoft.Office.OneNote',
    'Microsoft.OneConnect',
    'Microsoft.People',
    'Microsoft.SkypeApp',
    'Microsoft.Todos',
    'Microsoft.WindowsFeedbackHub',
    'Microsoft.WindowsMaps',
    'Microsoft.XboxApp',
    'Microsoft.XboxGameOverlay',
    'Microsoft.XboxGamingOverlay',
    'Microsoft.XboxIdentityProvider',
    'Microsoft.XboxSpeechToTextOverlay',
    'Microsoft.YourPhone',
    'Microsoft.ZuneMusic',
    'Microsoft.ZuneVideo',
    'Clipchamp.Clipchamp',
    'MicrosoftTeams',
    'Microsoft.WindowsCommunicationsApps'
)

Write-Host "Removing $($bloat.Count) bloat apps..." -ForegroundColor Cyan
if (-not $DryRun) {
    foreach ($app in $bloat) { Remove-AppxSafe $app }
} else {
    $bloat | ForEach-Object { Write-Host "DryRun: would remove $_" }
}

# ── Disable Cortana ───────────────────────────────────────────────────────────
Backup-Registry 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search' 'cortana'
Set-RegistryValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search' 'AllowCortana' 0
Write-Host "  Cortana disabled" -ForegroundColor Green

# ── Disable Edge Desktop Search Bar ──────────────────────────────────────────
Backup-Registry 'HKLM:\SOFTWARE\Policies\Microsoft\Edge' 'edge'
Set-RegistryValue 'HKLM:\SOFTWARE\Policies\Microsoft\Edge' 'WebWidgetAllowed' 0
Set-RegistryValue 'HKLM:\SOFTWARE\Policies\Microsoft\Edge' 'HideFirstRunExperience' 1
Set-RegistryValue 'HKLM:\SOFTWARE\Policies\Microsoft\Edge' 'DefaultBrowserSettingEnabled' 0

# ── Disable Telemetry ─────────────────────────────────────────────────────────
Backup-Registry 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' 'telemetry'
Set-RegistryValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' 'AllowTelemetry' 0
Set-RegistryValue 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection' 'AllowTelemetry' 0
Write-Host "  Telemetry minimized" -ForegroundColor Green

# ── Disable Bing in Start Menu ────────────────────────────────────────────────
Backup-Registry 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search' 'bing_search'
Set-RegistryValue 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search' 'BingSearchEnabled' 0
Set-RegistryValue 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search' 'CortanaConsent' 0
Write-Host "  Bing Start search disabled" -ForegroundColor Green

# ── Disable ads and suggestions ───────────────────────────────────────────────
Backup-Registry 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'ads'
$adKeys = @(
    'ContentDeliveryAllowed', 'OemPreInstalledAppsEnabled',
    'PreInstalledAppsEnabled', 'PreInstalledAppsEverEnabled',
    'SilentInstalledAppsEnabled', 'SubscribedContent-338387Enabled',
    'SubscribedContent-338388Enabled', 'SubscribedContent-338389Enabled',
    'SubscribedContent-353698Enabled', 'SystemPaneSuggestionsEnabled'
)
foreach ($key in $adKeys) {
    Set-RegistryValue 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' $key 0
}
Write-Host "  Ads and suggestions disabled" -ForegroundColor Green

Write-Host "Debloat complete. Backups saved to: $backupDir" -ForegroundColor Cyan

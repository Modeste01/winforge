<#
.SYNOPSIS
    Reversible Windows 11 debloat — Apply and Restore modes.

.DESCRIPTION
    - Apply: removes Appx packages whose names match patterns in
      manifests/appx-allowlist.json -> debloatCandidates AND are NOT in neverRemove.
      Records every removed package + its provisioning state in state.json so
      Restore mode can reinstall them from the original source where possible.
    - Restore: re-registers / re-provisions previously removed Appx packages.
      Note: full reinstallation may require Microsoft Store; we use a best-effort
      Add-AppxPackage from %ProgramFiles%\WindowsApps when bits remain on disk.

    Microsoft Edge is **never** removed (per Microsoft policy and to avoid breaking
    OS components).

.PARAMETER Mode
    Apply | Restore | List

.PARAMETER DryRun
    Print actions without changing system state.
#>
[CmdletBinding()]
param(
    [ValidateSet('Apply','Restore','List')] [string]$Mode = 'Apply',
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot   = Split-Path -Parent $ScriptRoot
Import-Module (Join-Path $RepoRoot 'scripts\lib\WinForge.psm1') -Force
Initialize-WinForge -DryRun:$DryRun

$allowlistPath = Join-Path $RepoRoot 'manifests\appx-allowlist.json'
$allow = Get-Content -Raw $allowlistPath | ConvertFrom-Json

function Test-MatchAny {
    param([string]$Name, [string[]]$Patterns)
    foreach ($p in $Patterns) {
        if ($Name -like $p) { return $true }
    }
    return $false
}

switch ($Mode) {
    'List' {
        Write-WinForgeBanner "Installed Appx packages"
        Get-AppxPackage -AllUsers | Sort-Object Name | Select-Object Name, Publisher | Format-Table -AutoSize
        return
    }
    'Apply' {
        Write-WinForgeBanner "Debloat: removing matching Appx packages"
        New-WinForgeRestorePoint -Description "WinForge debloat"

        $candidates = $allow.debloatCandidates
        $never      = $allow.neverRemove
        $installed  = Get-AppxPackage -AllUsers
        $provisioned = Get-AppxProvisionedPackage -Online

        $removed = New-Object System.Collections.Generic.List[string]

        foreach ($pkg in $installed) {
            if (Test-MatchAny -Name $pkg.Name -Patterns $never) { continue }
            if (-not (Test-MatchAny -Name $pkg.Name -Patterns $candidates)) { continue }

            if ($DryRun) {
                Write-WinForgeLog "Would remove Appx: $($pkg.Name)" DryRun
                continue
            }

            try {
                Write-WinForgeLog "Removing Appx: $($pkg.Name)" Step
                Remove-AppxPackage -Package $pkg.PackageFullName -AllUsers -ErrorAction Stop
                Add-WinForgeStateAppx -Name $pkg.Name
                $removed.Add($pkg.Name) | Out-Null
            } catch {
                Write-WinForgeLog "Failed to remove $($pkg.Name): $_" Warn
            }
        }

        # De-provision so new accounts don't get them back.
        foreach ($pp in $provisioned) {
            if (Test-MatchAny -Name $pp.DisplayName -Patterns $never) { continue }
            if (-not (Test-MatchAny -Name $pp.DisplayName -Patterns $candidates)) { continue }
            if ($DryRun) {
                Write-WinForgeLog "Would deprovision: $($pp.DisplayName)" DryRun
                continue
            }
            try {
                Remove-AppxProvisionedPackage -Online -PackageName $pp.PackageName -ErrorAction Stop | Out-Null
                Write-WinForgeLog "Deprovisioned $($pp.DisplayName)" Ok
            } catch {
                Write-WinForgeLog "Could not deprovision $($pp.DisplayName): $_" Warn
            }
        }

        Write-WinForgeLog ("Debloat complete. Removed {0} package(s)." -f $removed.Count) Ok
    }
    'Restore' {
        Write-WinForgeBanner "Debloat: restore mode"
        $state = Get-WinForgeState
        if (-not $state -or -not $state.PSObject.Properties['appxRemoved'] -or -not $state.appxRemoved) {
            Write-WinForgeLog "No debloat records found in state.json — nothing to restore." Warn
            return
        }
        foreach ($name in $state.appxRemoved) {
            if ($DryRun) {
                Write-WinForgeLog "Would attempt to reinstall $name (Store)" DryRun
                continue
            }
            Write-WinForgeLog "Attempting to reinstall $name via Store registration..." Step
            $manifest = Get-ChildItem "$env:ProgramFiles\WindowsApps" -Recurse -Filter AppxManifest.xml -ErrorAction SilentlyContinue |
                Where-Object { $_.FullName -match [regex]::Escape($name) } |
                Select-Object -First 1
            if ($manifest) {
                try {
                    Add-AppxPackage -DisableDevelopmentMode -Register $manifest.FullName -ErrorAction Stop
                    Write-WinForgeLog "Re-registered $name" Ok
                } catch {
                    Write-WinForgeLog "Re-register failed for ${name}: $_  (install manually from Microsoft Store)" Warn
                }
            } else {
                Write-WinForgeLog "Manifest for $name not found on disk. Install from Microsoft Store." Warn
            }
        }
    }
}

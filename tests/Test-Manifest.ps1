#Requires -Version 5.1
<#
.SYNOPSIS
    WinForge manifest validator — checks all tier JSON files for required fields
    and optionally verifies winget package IDs exist.
.PARAMETER OnlineCheck
    Also verify each winget package ID against the live winget source.
#>
param([switch]$OnlineCheck)

$ErrorCount  = 0
$missing     = @()
$tierFiles   = Get-ChildItem -Path "$PSScriptRoot\..\tiers" -Filter '*.json'

foreach ($file in $tierFiles) {
    $t    = $file.BaseName
    $pkgs = Get-Content $file.FullName | ConvertFrom-Json
    Write-Host "[${t}] $($pkgs.Count) packages" -ForegroundColor Cyan

    foreach ($pkg in $pkgs) {
        if (-not $pkg.id) {
            Write-Host "  MISSING id field: $(ConvertTo-Json $pkg -Compress)" -ForegroundColor Red
            $ErrorCount++
            continue
        }
        if (-not $pkg.name) {
            Write-Host "  MISSING name: $($pkg.id)" -ForegroundColor Yellow
        }
        if (-not $pkg.manager) {
            Write-Host "  MISSING manager: $($pkg.id)" -ForegroundColor Yellow
        }
    }
}

if ($OnlineCheck) {
    Write-Host "`nRunning online winget checks..." -ForegroundColor Cyan
    foreach ($file in $tierFiles) {
        $t    = $file.BaseName
        $pkgs = Get-Content $file.FullName | ConvertFrom-Json
        foreach ($pkg in $pkgs) {
            if ($pkg.manager -eq 'scoop') { continue }
            winget show --id $pkg.id --exact --accept-source-agreements 1>$null 2>&1
            if ($LASTEXITCODE -ne 0) {
                Write-Host "  missing: $($pkg.id) (tier ${t})" -ForegroundColor Yellow
                $missing += "${t}:$($pkg.id)"
            }
        }
    }
}

if ($ErrorCount -gt 0) {
    Write-Host "`nFailed with $ErrorCount errors." -ForegroundColor Red
    exit 1
} elseif ($missing.Count -gt 0) {
    Write-Host "`nWarning: $($missing.Count) packages not found in winget." -ForegroundColor Yellow
    exit 0
} else {
    Write-Host "`nAll manifests valid." -ForegroundColor Green
    exit 0
}

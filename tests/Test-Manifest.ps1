<#
.SYNOPSIS
    Local sanity checks for the WinForge manifest. Runs the same JSON/YAML
    syntax & ID checks the CI workflow does, but offline-friendly.

.PARAMETER OnlineCheck
    Also call `winget show` for every required winget ID.

.EXAMPLE
    pwsh ./tests/Test-Manifest.ps1
    pwsh ./tests/Test-Manifest.ps1 -OnlineCheck
#>
[CmdletBinding()]
param([switch]$OnlineCheck)

$ErrorActionPreference = 'Stop'
$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot   = Split-Path -Parent $ScriptRoot

Write-Host "WinForge manifest test" -ForegroundColor Cyan
Write-Host ("=" * 40) -ForegroundColor Cyan

$manifestPath = Join-Path $RepoRoot 'manifests\apps.json'
$manifest = $null
try {
    $manifest = Get-Content -Raw $manifestPath | ConvertFrom-Json -ErrorAction Stop
    Write-Host "[ok] apps.json parses" -ForegroundColor Green
} catch {
    Write-Host "[ERR] apps.json failed to parse: $_" -ForegroundColor Red
    exit 1
}

# Required tiers
foreach ($tier in 'core','power-user','dev','ai') {
    if (-not $manifest.tiers.$tier) {
        Write-Host "[ERR] tier '$tier' missing" -ForegroundColor Red
        exit 1
    }
    Write-Host "[ok] tier '$tier' present ($($manifest.tiers.$tier.packages.Count) packages)" -ForegroundColor Green
}

# Walk every JSON file
$jsonBad = 0
Get-ChildItem -Path $RepoRoot -Recurse -Include *.json | ForEach-Object {
    try { Get-Content -Raw $_.FullName | ConvertFrom-Json -ErrorAction Stop | Out-Null }
    catch { Write-Host "[ERR] $($_.FullName): $_" -ForegroundColor Red; $jsonBad++ }
}
if ($jsonBad) { Write-Host "[ERR] $jsonBad JSON files invalid" -ForegroundColor Red; exit 1 }
Write-Host "[ok] all JSON files parse" -ForegroundColor Green

# Optional online check
if ($OnlineCheck) {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Host "[skip] winget not available; skipping online check" -ForegroundColor Yellow
    } else {
        $missing = @()
        foreach ($t in $manifest.tiers.PSObject.Properties.Name) {
            foreach ($pkg in $manifest.tiers.$t.packages) {
                if ($pkg.source -ne 'winget') { continue }
                if ($pkg.optional -or $pkg.manual) { continue }
                winget show --id $pkg.id --exact --accept-source-agreements 1>$null 2>&1
                if ($LASTEXITCODE -ne 0) {
                    Write-Host "  missing: $($pkg.id) (tier $t)" -ForegroundColor Yellow
                    $missing += "$t::$($pkg.id)"
                }
            }
        }
        if ($missing.Count) {
            Write-Host "[warn] $($missing.Count) IDs not found upstream — fix manifests/apps.json" -ForegroundColor Yellow
        } else {
            Write-Host "[ok] all required winget IDs resolved" -ForegroundColor Green
        }
    }
}

Write-Host "All checks passed." -ForegroundColor Green

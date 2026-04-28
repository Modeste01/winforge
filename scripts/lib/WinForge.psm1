<#
.SYNOPSIS
    WinForge core module — shared helpers used by install.ps1, uninstall.ps1,
    debloat.ps1, and tweaks.ps1.

.DESCRIPTION
    Provides logging, OS detection, package-manager bootstrap, manifest loading,
    state tracking (so uninstall can reverse changes), and registry helpers.

    All public functions are prefixed with WinForge- so name collisions are unlikely.

.NOTES
    Requires PowerShell 5.1+ (Windows PowerShell) for bootstrapping.
    Most operations run better under PowerShell 7 (pwsh).
#>

#region ---- Module state ----------------------------------------------------

$script:WinForgeRoot      = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$script:WinForgeData      = Join-Path $env:ProgramData 'WinForge'
$script:WinForgeLogDir    = Join-Path $script:WinForgeData 'logs'
$script:WinForgeBackupDir = Join-Path $script:WinForgeData 'backups'
$script:WinForgeStateFile = Join-Path $script:WinForgeData 'state.json'
$script:WinForgeLogFile   = $null
$script:WinForgeDryRun    = $false

#endregion

#region ---- Initialization --------------------------------------------------

function Initialize-WinForge {
    [CmdletBinding()]
    param(
        [switch]$DryRun
    )
    $script:WinForgeDryRun = [bool]$DryRun

    foreach ($d in @($script:WinForgeData, $script:WinForgeLogDir, $script:WinForgeBackupDir)) {
        if (-not (Test-Path $d)) {
            New-Item -ItemType Directory -Path $d -Force | Out-Null
        }
    }

    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $script:WinForgeLogFile = Join-Path $script:WinForgeLogDir "winforge-$stamp.log"
    "WinForge run started $(Get-Date -Format o) (DryRun=$($script:WinForgeDryRun))" |
        Out-File -FilePath $script:WinForgeLogFile -Encoding utf8

    if (-not (Test-Path $script:WinForgeStateFile)) {
        @{ packagesInstalled = @(); tweaksApplied = @(); appxRemoved = @(); createdAt = (Get-Date).ToString('o') } |
            ConvertTo-Json -Depth 5 |
            Out-File -FilePath $script:WinForgeStateFile -Encoding utf8
    }
}

function Get-WinForgePaths {
    [pscustomobject]@{
        Root      = $script:WinForgeRoot
        Data      = $script:WinForgeData
        Logs      = $script:WinForgeLogDir
        Backups   = $script:WinForgeBackupDir
        StateFile = $script:WinForgeStateFile
        LogFile   = $script:WinForgeLogFile
    }
}

#endregion

#region ---- Logging ---------------------------------------------------------

function Write-WinForgeLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Message,
        [ValidateSet('Info','Ok','Warn','Error','Step','DryRun')] [string]$Level = 'Info'
    )
    $ts = Get-Date -Format 'HH:mm:ss'
    $color = switch ($Level) {
        'Ok'     { 'Green' }
        'Warn'   { 'Yellow' }
        'Error'  { 'Red' }
        'Step'   { 'Cyan' }
        'DryRun' { 'Magenta' }
        default  { 'Gray' }
    }
    $tag = "[$Level]".PadRight(8)
    $line = "$ts $tag $Message"
    Write-Host $line -ForegroundColor $color
    if ($script:WinForgeLogFile) {
        Add-Content -Path $script:WinForgeLogFile -Value $line
    }
}

function Write-WinForgeBanner {
    param([string]$Title)
    $bar = '═' * ([Math]::Max(8, $Title.Length + 4))
    Write-Host ''
    Write-Host $bar -ForegroundColor Cyan
    Write-Host "  $Title" -ForegroundColor Cyan
    Write-Host $bar -ForegroundColor Cyan
    if ($script:WinForgeLogFile) {
        Add-Content -Path $script:WinForgeLogFile -Value "`n=== $Title ==="
    }
}

#endregion

#region ---- Environment / OS detection -------------------------------------

function Test-WinForgeAdmin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $p  = New-Object Security.Principal.WindowsPrincipal($id)
    return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Test-Windows11 {
    [CmdletBinding()] param()
    try {
        $os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
        # Win11 reports as 10.0 but build >= 22000.
        $build = [int]($os.BuildNumber)
        return ($os.Caption -match 'Windows 11' -or $build -ge 22000)
    } catch {
        return $false
    }
}

function Assert-WinForgePrereqs {
    [CmdletBinding()]
    param([switch]$Force)
    if (-not (Test-WinForgeAdmin)) {
        throw "WinForge must be run from an elevated PowerShell session (Run as Administrator)."
    }
    if (-not (Test-Windows11)) {
        if ($Force) {
            Write-WinForgeLog "Not running Windows 11 — continuing because -Force was specified." Warn
        } else {
            throw "WinForge targets Windows 11 (build 22000+). Re-run with -Force to override."
        }
    }
}

#endregion

#region ---- Manifests -------------------------------------------------------

function Get-WinForgeManifest {
    [CmdletBinding()]
    param(
        [string]$Path = (Join-Path $script:WinForgeRoot 'manifests\apps.json')
    )
    if (-not (Test-Path $Path)) { throw "Manifest not found: $Path" }
    return Get-Content -Raw -Path $Path | ConvertFrom-Json
}

function Resolve-WinForgeTier {
    <# Returns the deduplicated list of packages for a tier, walking the 'extends' chain. #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] $Manifest,
        [Parameter(Mandatory)][string]$Tier
    )
    $resolved = New-Object System.Collections.Generic.List[object]
    $seen     = New-Object System.Collections.Generic.HashSet[string]
    $chain    = New-Object System.Collections.Generic.Stack[string]

    $current = $Tier
    while ($current) {
        $node = $Manifest.tiers.$current
        if (-not $node) { throw "Unknown tier: $current" }
        $chain.Push($current)
        $current = $node.extends
    }

    while ($chain.Count -gt 0) {
        $name = $chain.Pop()
        foreach ($pkg in $Manifest.tiers.$name.packages) {
            $key = "$($pkg.source):$($pkg.id)"
            if ($seen.Add($key)) { $resolved.Add($pkg) | Out-Null }
        }
    }
    return ,$resolved.ToArray()
}

#endregion

#region ---- Package managers ------------------------------------------------

function Test-Command {
    param([Parameter(Mandatory)][string]$Name)
    return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

function Install-WinForgeWinget {
    [CmdletBinding()]
    param()
    if (Test-Command winget) {
        Write-WinForgeLog "winget already installed: $(winget --version)" Ok
        return
    }
    Write-WinForgeLog "winget not detected — bootstrapping App Installer." Step
    if ($script:WinForgeDryRun) {
        Write-WinForgeLog "Would install Microsoft.DesktopAppInstaller from Microsoft Store" DryRun
        return
    }
    try {
        # Trigger Store update for App Installer.
        Start-Process "ms-windows-store://pdp/?ProductId=9NBLGGH4NNS1" | Out-Null
        Write-WinForgeLog "Opened Store page for App Installer. Re-run WinForge after install completes." Warn
    } catch {
        Write-WinForgeLog "Could not auto-install winget: $_" Error
    }
}

function Install-WinForgeScoop {
    [CmdletBinding()]
    param([string[]]$Buckets = @())
    if (-not (Test-Command scoop)) {
        Write-WinForgeLog "Installing Scoop." Step
        if ($script:WinForgeDryRun) {
            Write-WinForgeLog "Would install Scoop via web installer" DryRun
        } else {
            try {
                Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
                Invoke-RestMethod -Uri 'https://get.scoop.sh' | Invoke-Expression
            } catch {
                Write-WinForgeLog "Scoop install failed: $_" Error
                return
            }
        }
    } else {
        Write-WinForgeLog "Scoop already installed." Ok
    }

    foreach ($b in $Buckets) {
        if (-not (Test-Command scoop)) { break }
        if ($script:WinForgeDryRun) {
            Write-WinForgeLog "Would add scoop bucket $b" DryRun
            continue
        }
        $existing = & scoop bucket list 2>$null
        if ($existing -notmatch [regex]::Escape($b)) {
            Write-WinForgeLog "Adding scoop bucket: $b"
            & scoop bucket add $b 2>&1 | Out-Null
        }
    }
}

function Test-WingetPackageAvailable {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Id)
    if (-not (Test-Command winget)) { return $false }
    try {
        $result = winget show --id $Id --exact --accept-source-agreements 2>&1
        return ($LASTEXITCODE -eq 0)
    } catch {
        return $false
    }
}

function Install-WinForgePackage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] $Package
    )
    $id = $Package.id
    $src = $Package.source
    $isOptional = [bool]$Package.optional
    $isManual   = [bool]$Package.manual

    if ($isManual -or $src -eq 'manual') {
        Write-WinForgeLog "MANUAL: $id — $($Package.notes)" Warn
        return [pscustomobject]@{ Id=$id; Source=$src; Status='manual' }
    }

    if ($src -eq 'script') {
        # Script entries are bookkeeping placeholders (Scoop bootstrap, FancyZones import,
        # SDKMAN-in-WSL, Cursor dedupe between dev/ai, Raycast/Recall alternatives, etc.).
        # The actual work is performed elsewhere (install.ps1, deploy-configs.ps1, the WSL
        # bootstrap script). We log and move on rather than failing.
        Write-WinForgeLog "SCRIPT: $id — $($Package.notes)" Step
        return [pscustomobject]@{ Id=$id; Source=$src; Status='script' }
    }

    if ($script:WinForgeDryRun) {
        Write-WinForgeLog "Would install [$src] $id" DryRun
        return [pscustomobject]@{ Id=$id; Source=$src; Status='dryrun' }
    }

    switch ($src) {
        'winget' {
            if (-not (Test-Command winget)) {
                Write-WinForgeLog "winget unavailable; skipping $id" Warn
                return [pscustomobject]@{ Id=$id; Source=$src; Status='skipped-no-winget' }
            }
            if (-not (Test-WingetPackageAvailable -Id $id)) {
                # Runtime verification: every winget id is checked with `winget show --id <id> --exact`
                # before attempting an install. Optional packages (paid, region-locked, drifting ids)
                # downgrade to a warning so the run keeps going.
                $level = if ($isOptional) { 'Warn' } else { 'Error' }
                Write-WinForgeLog "winget id not resolvable: $id ($($Package.notes))" $level
                return [pscustomobject]@{ Id=$id; Source=$src; Status='not-found' }
            }
            Write-WinForgeLog "Installing [winget] $id" Step
            $args = @('install','--id', $id,
                      '--exact',
                      '--silent',
                      '--accept-package-agreements',
                      '--accept-source-agreements',
                      '--source','winget')
            $proc = Start-Process winget -ArgumentList $args -Wait -NoNewWindow -PassThru
            if ($proc.ExitCode -eq 0 -or $proc.ExitCode -eq -1978335189) {
                Add-WinForgeStatePackage -Id $id -Source 'winget'
                return [pscustomobject]@{ Id=$id; Source=$src; Status='installed' }
            } else {
                Write-WinForgeLog "winget install failed for $id (exit $($proc.ExitCode))" Warn
                return [pscustomobject]@{ Id=$id; Source=$src; Status="failed:$($proc.ExitCode)" }
            }
        }
        'scoop' {
            if (-not (Test-Command scoop)) {
                Write-WinForgeLog "Scoop unavailable; skipping $id" Warn
                return [pscustomobject]@{ Id=$id; Source=$src; Status='skipped-no-scoop' }
            }
            $target = if ($Package.bucket) { "$($Package.bucket)/$id" } else { $id }
            Write-WinForgeLog "Installing [scoop] $target" Step
            & scoop install $target 2>&1 | Tee-Object -Variable scoopOut | Out-Null
            if ($LASTEXITCODE -eq 0) {
                Add-WinForgeStatePackage -Id $target -Source 'scoop'
                return [pscustomobject]@{ Id=$id; Source=$src; Status='installed' }
            } else {
                Write-WinForgeLog "scoop install failed: $target" Warn
                return [pscustomobject]@{ Id=$id; Source=$src; Status='failed' }
            }
        }
        default {
            Write-WinForgeLog "Unknown source '$src' for $id" Warn
            return [pscustomobject]@{ Id=$id; Source=$src; Status='unknown-source' }
        }
    }
}

#endregion

#region ---- State tracking --------------------------------------------------

function Get-WinForgeState {
    if (-not (Test-Path $script:WinForgeStateFile)) { return $null }
    return Get-Content -Raw $script:WinForgeStateFile | ConvertFrom-Json
}

function Save-WinForgeState {
    param([Parameter(Mandatory)] $State)
    $State | ConvertTo-Json -Depth 6 | Out-File -FilePath $script:WinForgeStateFile -Encoding utf8
}

function Add-WinForgeStatePackage {
    param([string]$Id, [string]$Source)
    $st = Get-WinForgeState
    if (-not $st.packagesInstalled) { $st | Add-Member -NotePropertyName packagesInstalled -NotePropertyValue @() -Force }
    $st.packagesInstalled = @($st.packagesInstalled) + @([pscustomobject]@{
        id = $Id; source = $Source; installedAt = (Get-Date).ToString('o')
    })
    Save-WinForgeState $st
}

function Add-WinForgeStateTweak {
    param([string]$Name, [hashtable]$BackupRef)
    $st = Get-WinForgeState
    if (-not $st.tweaksApplied) { $st | Add-Member -NotePropertyName tweaksApplied -NotePropertyValue @() -Force }
    $st.tweaksApplied = @($st.tweaksApplied) + @([pscustomobject]@{
        name = $Name
        backup = $BackupRef
        appliedAt = (Get-Date).ToString('o')
    })
    Save-WinForgeState $st
}

function Add-WinForgeStateAppx {
    param([string]$Name)
    $st = Get-WinForgeState
    if (-not $st.appxRemoved) { $st | Add-Member -NotePropertyName appxRemoved -NotePropertyValue @() -Force }
    $st.appxRemoved = @($st.appxRemoved) + @($Name)
    Save-WinForgeState $st
}

#endregion

#region ---- Backups & registry ---------------------------------------------

function New-WinForgeRestorePoint {
    [CmdletBinding()]
    param([string]$Description = 'WinForge pre-change')
    try {
        if ($script:WinForgeDryRun) {
            Write-WinForgeLog "Would create system restore point: $Description" DryRun
            return
        }
        Enable-ComputerRestore -Drive (Get-CimInstance Win32_OperatingSystem).SystemDrive -ErrorAction SilentlyContinue
        Checkpoint-Computer -Description $Description -RestorePointType MODIFY_SETTINGS -ErrorAction Stop
        Write-WinForgeLog "Created restore point: $Description" Ok
    } catch {
        Write-WinForgeLog "Restore point creation failed (non-fatal): $_" Warn
    }
}

function Backup-WinForgeRegistryKey {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path, [string]$Tag = 'tweak')
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $safe  = ($Path -replace '[^a-zA-Z0-9]','_')
    $file  = Join-Path $script:WinForgeBackupDir "$Tag-$safe-$stamp.reg"
    if ($script:WinForgeDryRun) {
        Write-WinForgeLog "Would back up $Path to $file" DryRun
        return $file
    }
    try {
        $regPath = $Path -replace '^HKCU:','HKEY_CURRENT_USER' `
                          -replace '^HKLM:','HKEY_LOCAL_MACHINE' `
                          -replace '^HKCR:','HKEY_CLASSES_ROOT'
        & reg.exe export $regPath $file /y | Out-Null
        Write-WinForgeLog "Backed up $Path -> $file"
        return $file
    } catch {
        Write-WinForgeLog "Failed to back up $Path : $_" Warn
        return $null
    }
}

function Set-WinForgeRegistryValue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)] $Value,
        [ValidateSet('String','ExpandString','Binary','DWord','MultiString','QWord')]
        [string]$Type = 'DWord'
    )
    if ($script:WinForgeDryRun) {
        Write-WinForgeLog "Would set $Path\$Name = $Value ($Type)" DryRun
        return
    }
    if (-not (Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
    New-ItemProperty -Path $Path -Name $Name -Value $Value -PropertyType $Type -Force | Out-Null
}

#endregion

Export-ModuleMember -Function `
    Initialize-WinForge, Get-WinForgePaths, `
    Write-WinForgeLog, Write-WinForgeBanner, `
    Test-WinForgeAdmin, Test-Windows11, Assert-WinForgePrereqs, `
    Get-WinForgeManifest, Resolve-WinForgeTier, `
    Test-Command, Install-WinForgeWinget, Install-WinForgeScoop, `
    Test-WingetPackageAvailable, Install-WinForgePackage, `
    Get-WinForgeState, Save-WinForgeState, `
    Add-WinForgeStatePackage, Add-WinForgeStateTweak, Add-WinForgeStateAppx, `
    New-WinForgeRestorePoint, Backup-WinForgeRegistryKey, Set-WinForgeRegistryValue

<#
.SYNOPSIS
    Copy WinForge configs from configs/ into their destinations.

.DESCRIPTION
    Targets:
      - PowerToys settings  -> %LOCALAPPDATA%\Microsoft\PowerToys
      - Windows Terminal    -> %LOCALAPPDATA%\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState
      - PowerShell profile  -> $PROFILE
      - VS Code             -> %APPDATA%\Code\User
      - AutoHotkey          -> %USERPROFILE%\Documents\AutoHotkey
      - espanso             -> %APPDATA%\espanso\match  (or wherever espanso path config points)

    Each existing target file is backed up to %ProgramData%\WinForge\backups
    before being overwritten. Records destinations in state.json so uninstall
    can roll back.
#>
[CmdletBinding()]
param([switch]$DryRun)

$ErrorActionPreference = 'Stop'
$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot   = Split-Path -Parent $ScriptRoot
Import-Module (Join-Path $RepoRoot 'scripts\lib\WinForge.psm1') -Force
Initialize-WinForge -DryRun:$DryRun

$paths = Get-WinForgePaths

function Copy-Config {
    param([string]$Src, [string]$Dst)
    if (-not (Test-Path $Src)) { Write-WinForgeLog "Source missing: $Src" Warn; return }
    $dstDir = Split-Path -Parent $Dst
    if (-not (Test-Path $dstDir)) {
        if ($DryRun) { Write-WinForgeLog "Would mkdir $dstDir" DryRun }
        else        { New-Item -ItemType Directory -Path $dstDir -Force | Out-Null }
    }
    if (Test-Path $Dst) {
        $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
        $bak = Join-Path $paths.Backups ("config-" + (Split-Path -Leaf $Dst) + "-$stamp")
        if ($DryRun) { Write-WinForgeLog "Would back up $Dst -> $bak" DryRun }
        else { Copy-Item -Path $Dst -Destination $bak -Force }
    }
    if ($DryRun) {
        Write-WinForgeLog "Would copy $Src -> $Dst" DryRun
    } else {
        Copy-Item -Path $Src -Destination $Dst -Force
        Write-WinForgeLog "Deployed $Dst" Ok

        # record in state for uninstall
        $st = Get-WinForgeState
        if (-not $st.PSObject.Properties['configsDeployed']) {
            $st | Add-Member -NotePropertyName configsDeployed -NotePropertyValue @() -Force
        }
        $st.configsDeployed = @($st.configsDeployed) + @($Dst)
        Save-WinForgeState $st
    }
}

# --- PowerToys ---------------------------------------------------------------
$powerToysSrc = Join-Path $RepoRoot 'configs\powertoys\settings.json'
$powerToysDst = Join-Path $env:LOCALAPPDATA 'Microsoft\PowerToys\settings.json'
Copy-Config -Src $powerToysSrc -Dst $powerToysDst

$fzSrc = Join-Path $RepoRoot 'configs\powertoys\fancyzones-layouts.json'
$fzDst = Join-Path $env:LOCALAPPDATA 'Microsoft\PowerToys\FancyZones\custom-layouts.json'
Copy-Config -Src $fzSrc -Dst $fzDst

# --- Windows Terminal --------------------------------------------------------
$wtSrc = Join-Path $RepoRoot 'configs\windows-terminal\settings.json'
$wtDst = Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json'
Copy-Config -Src $wtSrc -Dst $wtDst

# --- PowerShell profile ------------------------------------------------------
$psSrc = Join-Path $RepoRoot 'configs\powershell\Microsoft.PowerShell_profile.ps1'
$psDst = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'PowerShell\Microsoft.PowerShell_profile.ps1'
Copy-Config -Src $psSrc -Dst $psDst

# Also drop a copy for Windows PowerShell 5.1
$psDstLegacy = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'WindowsPowerShell\Microsoft.PowerShell_profile.ps1'
Copy-Config -Src $psSrc -Dst $psDstLegacy

# --- VS Code -----------------------------------------------------------------
$codeUser = Join-Path $env:APPDATA 'Code\User'
Copy-Config -Src (Join-Path $RepoRoot 'configs\vscode\settings.json')      -Dst (Join-Path $codeUser 'settings.json')
Copy-Config -Src (Join-Path $RepoRoot 'configs\vscode\keybindings.json')   -Dst (Join-Path $codeUser 'keybindings.json')

# --- AutoHotkey --------------------------------------------------------------
$ahkSrc = Join-Path $RepoRoot 'configs\autohotkey\winforge.ahk'
$ahkDst = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'AutoHotkey\winforge.ahk'
Copy-Config -Src $ahkSrc -Dst $ahkDst

# --- espanso -----------------------------------------------------------------
$espansoSrc = Join-Path $RepoRoot 'configs\espanso\match\base.yml'
$espansoDst = Join-Path $env:APPDATA 'espanso\match\base.yml'
Copy-Config -Src $espansoSrc -Dst $espansoDst

Write-WinForgeLog "All configs processed." Ok

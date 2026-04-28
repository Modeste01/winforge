<#
.SYNOPSIS
    Apply or revert opinionated Windows 11 tweaks. Every tweak backs up the
    affected registry key to %ProgramData%\WinForge\backups before changing it.

.PARAMETER Mode
    Apply | Revert

.PARAMETER DryRun
    Print actions; change nothing.

.NOTES
    Tweaks chosen are conservative — visual quality-of-life and developer
    ergonomics. Nothing here disables Defender, telemetry baselines required
    by Windows Update, or other security-critical components.
#>
[CmdletBinding()]
param(
    [ValidateSet('Apply','Revert')] [string]$Mode = 'Apply',
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot   = Split-Path -Parent $ScriptRoot
Import-Module (Join-Path $RepoRoot 'scripts\lib\WinForge.psm1') -Force
Initialize-WinForge -DryRun:$DryRun

# A list of tweak descriptors. Each one knows how to Apply itself and how to Revert.
$tweaks = @(
    @{
        name = 'Show file extensions'
        path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
        name2 = 'HideFileExt'
        applyValue = 0
        type = 'DWord'
    },
    @{
        name = 'Show hidden files'
        path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
        name2 = 'Hidden'
        applyValue = 1
        type = 'DWord'
    },
    @{
        name = 'Taskbar align left'
        path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
        name2 = 'TaskbarAl'
        applyValue = 0
        type = 'DWord'
    },
    @{
        name = 'Disable taskbar widgets'
        path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
        name2 = 'TaskbarDa'
        applyValue = 0
        type = 'DWord'
    },
    @{
        name = 'Disable taskbar chat'
        path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
        name2 = 'TaskbarMn'
        applyValue = 0
        type = 'DWord'
    },
    @{
        name = 'Compact mode in Explorer'
        path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
        name2 = 'UseCompactMode'
        applyValue = 1
        type = 'DWord'
    },
    @{
        name = 'Dark mode (apps)'
        path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'
        name2 = 'AppsUseLightTheme'
        applyValue = 0
        type = 'DWord'
    },
    @{
        name = 'Dark mode (system)'
        path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'
        name2 = 'SystemUsesLightTheme'
        applyValue = 0
        type = 'DWord'
    },
    @{
        name = 'Disable Bing search in Start'
        path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search'
        name2 = 'BingSearchEnabled'
        applyValue = 0
        type = 'DWord'
    },
    @{
        name = 'Disable web results in Start'
        path = 'HKCU:\Software\Policies\Microsoft\Windows\Explorer'
        name2 = 'DisableSearchBoxSuggestions'
        applyValue = 1
        type = 'DWord'
    },
    @{
        name = 'Show seconds in taskbar clock'
        path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
        name2 = 'ShowSecondsInSystemClock'
        applyValue = 1
        type = 'DWord'
    },
    @{
        name = 'Disable startup boost noise (advertising ID)'
        path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo'
        name2 = 'Enabled'
        applyValue = 0
        type = 'DWord'
    },
    @{
        name = 'Long paths enabled'
        path = 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem'
        name2 = 'LongPathsEnabled'
        applyValue = 1
        type = 'DWord'
    },
    @{
        name = 'Developer Mode (sideload + symlinks)'
        path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock'
        name2 = 'AllowDevelopmentWithoutDevLicense'
        applyValue = 1
        type = 'DWord'
    }
)

switch ($Mode) {
    'Apply' {
        Write-WinForgeBanner "Tweaks: applying $($tweaks.Count) tweaks"
        foreach ($t in $tweaks) {
            $backup = Backup-WinForgeRegistryKey -Path $t.path -Tag 'tweak'
            $oldValue = $null
            try { $oldValue = (Get-ItemProperty -Path $t.path -Name $t.name2 -ErrorAction Stop).$($t.name2) } catch {}
            Set-WinForgeRegistryValue -Path $t.path -Name $t.name2 -Value $t.applyValue -Type $t.type
            Write-WinForgeLog "$($t.name): $oldValue -> $($t.applyValue)" Ok
            Add-WinForgeStateTweak -Name $t.name -BackupRef @{
                path = $t.path
                value = $t.name2
                oldValue = $oldValue
                type = $t.type
                backupFile = $backup
            }
        }
        Write-WinForgeLog "Tweaks applied. Restart Explorer to see UI changes." Warn
        if (-not $DryRun) {
            try { Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue } catch {}
        }
    }
    'Revert' {
        Write-WinForgeBanner "Tweaks: reverting from state.json"
        $state = Get-WinForgeState
        if (-not $state -or -not $state.PSObject.Properties['tweaksApplied'] -or -not $state.tweaksApplied) {
            Write-WinForgeLog "No tweaks recorded — nothing to revert." Warn
            return
        }
        foreach ($entry in $state.tweaksApplied) {
            $b = $entry.backup
            if ($null -eq $b.oldValue) {
                if ($DryRun) {
                    Write-WinForgeLog "Would remove $($b.path)\$($b.value)" DryRun
                } else {
                    try { Remove-ItemProperty -Path $b.path -Name $b.value -ErrorAction Stop; Write-WinForgeLog "Cleared $($entry.name)" Ok }
                    catch { Write-WinForgeLog "Could not clear $($entry.name): $_" Warn }
                }
            } else {
                Set-WinForgeRegistryValue -Path $b.path -Name $b.value -Value $b.oldValue -Type $b.type
                Write-WinForgeLog "Reverted $($entry.name) -> $($b.oldValue)" Ok
            }
        }
        if (-not $DryRun) {
            try { Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue } catch {}
        }
    }
}

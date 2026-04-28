# Rollback Runbook

WinForge is reversible by design. This page is the recovery cheat-sheet.

## TL;DR

```powershell
# Safe rollback (recommended): undo tweaks, restore Appx packages where possible, remove deployed configs.
.\uninstall.ps1

# Aggressive rollback: also uninstall every package WinForge installed.
.\uninstall.ps1 -RemovePackages -Force
```

Logs at `%ProgramData%\WinForge\logs\`, state at `%ProgramData%\WinForge\state.json`.

---

## What `uninstall.ps1` does

In order:

1. **Tweaks** — calls `scripts/tweaks.ps1 -Mode Revert`, which reads `state.json -> tweaksApplied[*].backup` and restores each registry value to its pre-Apply value (or removes the value if it didn't exist before).
2. **Debloat** — calls `scripts/debloat.ps1 -Mode Restore`, which iterates `state.json -> appxRemoved` and tries to re-register each Appx package from `%ProgramFiles%\WindowsApps`. If the package files are gone, it prints a Microsoft Store URL.
3. **Configs** — removes every path listed in `state.json -> configsDeployed`. Originals were copied to `%ProgramData%\WinForge\backups\config-<file>-<timestamp>` during deploy and are left in place; restore by hand if needed.
4. **Packages** — only when `-RemovePackages` is passed. Iterates `state.json -> packagesInstalled` and runs `winget uninstall --id <id>` or `scoop uninstall <id>`.

---

## Manual recovery options

### Revert a single tweak

Each tweak's `.reg` backup lives in `%ProgramData%\WinForge\backups\` named `tweak-<KeyPath>-<timestamp>.reg`.

```powershell
# Find the relevant backup
Get-ChildItem $env:ProgramData\WinForge\backups -Filter 'tweak-*Personalize*'

# Import it
reg import "$env:ProgramData\WinForge\backups\tweak-HKCU_Software_Microsoft_..._Personalize-20251114-103211.reg"
```

### Restore one Appx package

```powershell
# From WinForge state
$state = Get-Content $env:ProgramData\WinForge\state.json | ConvertFrom-Json
$state.appxRemoved

# Try to re-register from disk
$name = 'Microsoft.WindowsCalculator'
$manifest = Get-ChildItem "$env:ProgramFiles\WindowsApps" -Recurse -Filter AppxManifest.xml -ErrorAction SilentlyContinue |
    Where-Object FullName -match $name | Select-Object -First 1
Add-AppxPackage -DisableDevelopmentMode -Register $manifest.FullName
```

If that fails, install from Microsoft Store: <https://aka.ms/Calculator> (substitute the relevant `aka.ms` shortlink or search the Store).

### Reinstate a config file from backup

```powershell
# E.g. Windows Terminal settings.json
Get-ChildItem $env:ProgramData\WinForge\backups -Filter 'config-settings.json-*' | Sort-Object LastWriteTime -Descending | Select-Object -First 1 |
    Copy-Item -Destination "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json" -Force
```

### System Restore Point

If WinForge created a restore point (`WinForge install (<tier>)`), open **Settings → System → About → System protection → System Restore** or run:

```powershell
rstrui.exe
```

---

## Edge cases

| Symptom | Likely cause | Fix |
|---|---|---|
| `uninstall.ps1` says "no records" | `state.json` was deleted or never written | Recover manually with `.reg` backups |
| Appx restore fails for many apps | Bits removed from `%ProgramFiles%\WindowsApps` | Reinstall from Microsoft Store |
| Tweaks reverted but Explorer still shows old state | Explorer needs restart | `Stop-Process -Name explorer -Force` |
| Package uninstall leaves data behind | App keeps user data in `%APPDATA%` / `%LOCALAPPDATA%` | Delete those folders manually |
| WSL still installed after `-RemovePackages` | WSL components are OS features, not winget packages | `wsl --uninstall` (Windows 11 22H2+) |

---

## When to nuke and pave instead

If the machine is unrecoverably misbehaving and rollback isn't restoring sanity:

1. **Reset PC** — Settings → System → Recovery → Reset this PC → "Keep my files".
2. Reinstall WinForge in a VM first, validate the change you wanted, then re-run on the host.

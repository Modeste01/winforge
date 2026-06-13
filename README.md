<div align="center">

<img src="https://img.shields.io/badge/Windows-11-0078D4?style=for-the-badge&logo=windows11&logoColor=white"/>
<img src="https://img.shields.io/badge/PowerShell-7%2B-5391FE?style=for-the-badge&logo=powershell&logoColor=white"/>
<img src="https://img.shields.io/badge/winget%20%2B%20scoop-Verified-01696f?style=for-the-badge"/>
<img src="https://img.shields.io/badge/license-MIT-green?style=for-the-badge"/>

# 🔨 WinForge

**A comprehensive, opinionated Windows 11 power-user setup — from a fresh install to a fully configured development machine in one command.**

```powershell
iwr https://raw.githubusercontent.com/Modeste01/winforge/main/install.ps1 | iex
```

</div>

---

## ✨ What WinForge Does

WinForge is a PowerShell-based setup system that:

- **Detects** your Windows version and validates prerequisites
- **Prompts** for an install tier (minimal → standard → power-user → dev → AI)
- **Installs** every app via `winget` or `Scoop` with verified package IDs
- **Applies** PowerToys, Windows Terminal, VS Code, PowerShell, WSL2, AHK, and Espanso configs
- **Tweaks** Explorer, taskbar, performance, and privacy registry settings
- **Debloats** Windows (Cortana, Edge nags, ads, telemetry) — **reversibly**
- **Logs** everything and backs up every registry key it touches
- **Rolls back** with `uninstall.ps1`

---

## 📦 App Tiers

### Core (15 apps) — included in every tier

| App | Package ID | Purpose |
|-----|-----------|----------|
| PowerToys | `Microsoft.PowerToys` | FancyZones, Run, Color Picker, Text Extractor |
| Files App | `FilesCommunity.Files` | Modern file manager |
| Everything | `voidtools.Everything` | Instant file search |
| Flow Launcher | `Flow-Launcher.Flow-Launcher` | App/file/web launcher |
| Ditto | `Ditto.Ditto` | Clipboard history |
| ShareX | `ShareX.ShareX` | Screenshots & recording |
| 7-Zip | `7zip.7zip` | Archive manager |
| VLC | `VideoLAN.VLC` | Media player |
| Bitwarden | `Bitwarden.Bitwarden` | Password manager |
| Windows Terminal | `Microsoft.WindowsTerminal` | Modern terminal |
| PowerShell 7 | `Microsoft.PowerShell` | Modern shell |
| Scoop | *(bootstrap)* | CLI package manager |
| winget-autoupdate | `Romanitho.Winget-AutoUpdate` | Auto-update all packages |
| RoundedTB | manual / Store | Rounded taskbar corners |
| EarTrumpet | `File-New-Project.EarTrumpet` | Per-app volume control |

### Power-User (+20 apps)

Espanso, AutoHotKey v2, FancyZones configs, Komorebi, MicaForEveryone, StartAllBack, ExplorerPatcher, Process Lasso, HWiNFO64, Macrium Reflect Free, FreeFileSync, Obsidian, Notion, Mosh, WinSCP, FileZilla, Rclone, Syncthing, Stremio, AnyDesk.

### Dev (+25 apps)

WSL2 (Ubuntu), Docker Desktop, VS Code + extension pack, Cursor, Git, GitHub CLI, GPG, Node via fnm, Python via uv, Rust via rustup, Go, Java via SDKMAN, Postman, DBeaver, TablePlus, Beekeeper Studio, MongoDB Compass, Postico, ngrok, Cloudflare Tunnel, Tabby, Warp.

### AI (+15 apps)

Ollama, LM Studio, Jan, ComfyUI Portable, Whispering, Wispr Flow, Cursor, Claude Desktop, Flow Launcher, and more.

---

## ⚡ Quick Start

### Requirements
- Windows 11 (Build 22000+)
- PowerShell 5.1+ (pre-installed; script upgrades to PS7)
- Run as **Administrator**
- Internet connection

### One-line Install

```powershell
iwr https://raw.githubusercontent.com/Modeste01/winforge/main/install.ps1 | iex
```

### Manual Install (recommended)

```powershell
# 1. Clone
git clone https://github.com/Modeste01/winforge.git
cd winforge

# 2. Dry-run preview
.\install.ps1 -DryRun

# 3. Full install
.\install.ps1

# 4. Configs only
.\install.ps1 -SkipApps

# 5. Debloat + tweaks only
.\scripts\debloat.ps1
.\scripts\tweaks.ps1
```

---

## ⚙️ Script Parameters

```
install.ps1
  -Tier <string>     Core | PowerUser | Dev | AI
  -DryRun            Preview changes without applying
  -SkipApps          Skip package installation
  -SkipConfigs       Skip config deployment
  -SkipDebloat       Skip debloat sub-script
  -SkipTweaks        Skip tweaks sub-script
  -NoRestore         Skip System Restore Point creation
  -Verbose           Extra logging
```

---

## 🔧 Configs Deployed

| Config | Destination |
|--------|------------|
| Windows Terminal `settings.json` | `%LOCALAPPDATA%\Packages\Microsoft.WindowsTerminal_...\LocalState\` |
| PowerShell Profile | `%USERPROFILE%\Documents\PowerShell\Microsoft.PowerShell_profile.ps1` |
| VS Code `settings.json` | `%APPDATA%\Code\User\settings.json` |
| VS Code `keybindings.json` | `%APPDATA%\Code\User\keybindings.json` |
| VS Code extensions | `code --install-extension` for all listed |
| AutoHotKey script | `%USERPROFILE%\Documents\AutoHotkey\winforge.ahk` |
| Espanso snippets | `%APPDATA%\espanso\match\winforge.yml` |
| Starship prompt | `%USERPROFILE%\.config\starship.toml` |
| WSL2 Ubuntu bootstrap | `configs/wsl/bootstrap-ubuntu.sh` |

---

## 🔑 Key Hotkeys After Setup

| Hotkey | Action |
|--------|--------|
| `Alt+Space` | Flow Launcher / PowerToys Run |
| `Win+Shift+Z` | FancyZones layout picker |
| `Win+Shift+C` | Color Picker |
| `Win+Shift+T` | Text Extractor (OCR) |
| `Win+T` | Windows Terminal |
| `Win+E` | Files App |
| `Ctrl+Space` | Toggle always-on-top |
| `Win+Numpad4/6` | Snap window left/right half |
| `Win+Numpad7/9` | Snap window to quadrants |
| `Ctrl+Alt+R` | Reload AutoHotKey script |

---

## ↩️ Rollback & Safety

### Automatic Backups
Every registry key modified is backed up to:
```
WinForge_Backups\
  registry_backup_YYYYMMDD_HHMMSS\
    tweaks.reg
    debloat.reg
```

### Full Uninstall
```powershell
.\uninstall.ps1
# Or restore a specific backup:
reg import WinForge_Backups\registry_backup_20260101_120000\tweaks.reg
```

### Windows Restore Point
`install.ps1` creates a System Restore Point before changes. To roll back:
```
Settings → System → Recovery → Open System Restore
```

> ⚠️ **Disclaimer:** WinForge modifies system settings and installs software. Always run `-DryRun` first. Back up important data before running on a production machine.

---

## 📁 Repo Structure

```
winforge/
├── install.ps1
├── uninstall.ps1
├── tiers/
│   ├── core.json
│   ├── poweruser.json
│   ├── dev.json
│   └── ai.json
├── scripts/
│   ├── debloat.ps1
│   └── tweaks.ps1
├── configs/
│   ├── terminal/settings.json
│   ├── powershell/
│   ├── vscode/
│   ├── ahk/winforge.ahk
│   ├── espanso/default.yml
│   ├── powertoys/README.md
│   └── wsl/
├── tests/
│   └── Test-Manifest.ps1
└── .github/
    └── workflows/
        └── windows-validate.yml
```

---

## 🤝 Contributing

1. Fork → Branch → PR
2. Add apps to the correct `tiers/*.json`
3. Verify the winget ID: `winget search <app>`
4. Run `.\tests\Test-Manifest.ps1` before submitting

---

## 📄 License

MIT © [Modeste Houenou](https://github.com/Modeste01)

---

<div align="center">
Made for reuse on every future Windows machine. Star ⭐ if it saved you a day of setup.
</div>

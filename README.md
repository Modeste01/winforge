<div align="center">

# 🛠️ WinForge

**A reproducible, reversible Windows 11 setup forge.**
Tiered package install · sane tweaks · safe debloat · dotfiles for Terminal, PowerShell, VS Code, PowerToys, AHK, espanso, and WSL.

[![windows-validate](https://img.shields.io/badge/CI-windows--validate-blue?logo=github)](.github/workflows/windows-validate.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![PowerShell](https://img.shields.io/badge/PowerShell-7%2B-5391FE?logo=powershell)](https://learn.microsoft.com/powershell/)
[![Windows 11](https://img.shields.io/badge/Windows-11-0078D6?logo=windows11)](#)

> _Forge a clean, fast, opinionated Windows 11 box in one command — and unforge it just as cleanly._

</div>

---

## Why WinForge?

Most Windows setup scripts are write-once, fire-and-forget, and impossible to undo. WinForge is built around three principles:

1. **Manifest-driven** — every package lives in [`manifests/apps.json`](manifests/apps.json). Change an ID, re-run, done.
2. **Reversible** — every tweak is registry-backed up. Every Appx removal is logged. Every dotfile copy is recorded. `uninstall.ps1` reverses everything.
3. **Safety first** — defaults to dry-run-friendly behavior, never touches Edge/Defender/Store, never installs anything it can't verify, and warns loudly before destructive operations.

> [!WARNING]
> WinForge changes system settings, removes preinstalled apps, and installs software from the internet. **Test in a Windows 11 VM first** ([instructions below](#-validation--vm-testing)). A System Restore point is created automatically when possible, but you should still have a backup.

---

## ⚡ Quick start

```powershell
# 1. Open an elevated PowerShell session (Win + X → Windows Terminal (Admin))
# 2. Allow this run to execute scripts
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass

# 3. Clone & run
git clone https://github.com/<your-fork>/winforge.git
cd winforge
.\install.ps1 -Tier dev
```

**One-line install** (after publishing — placeholder):

```powershell
irm https://example.com/winforge/install | iex   # ← replace with your hosted bootstrap URL
```

**Dry-run anything** to see exactly what would happen:

```powershell
.\install.ps1 -Tier ai -DryRun
```

---

## 🎚️ Tiers

| Tier         | Apps               | Use case                                                        |
|--------------|--------------------|-----------------------------------------------------------------|
| `minimal`    | Core 15            | PowerToys, Files, Everything, Flow Launcher, Ditto, ShareX, 7-Zip, VLC, Bitwarden, Windows Terminal, PowerShell 7, Scoop, winget-autoupdate, RoundedTB, EarTrumpet |
| `power-user` | Core + 20          | Espanso, AHK, FancyZones, Komorebi, MicaForEveryone, StartAllBack, ExplorerPatcher, Process Lasso, HWiNFO, FreeFileSync, Obsidian, Notion, Mosh, WinSCP, FileZilla, Rclone, Syncthing, Stremio, AnyDesk, Macrium |
| `dev`        | + 23 dev tools     | WSL2, Docker, VS Code (+ ext pack), Cursor, Git/GH CLI/GPG, fnm, uv, rustup, Go, SDKMAN-in-WSL, Postman, DBeaver, TablePlus, Beekeeper, Mongo Compass, Postico*, ngrok, cloudflared, Tabby, Warp |
| `ai`         | + 10 AI tools      | Ollama, LM Studio, Jan, ComfyUI portable, Whispering, Wispr Flow, Cursor, Claude Desktop, Flow (Raycast alt), Recall alt |
| `all`        | alias for `ai`     | Everything                                                      |

_*Postico is macOS-only and is logged as manual on Windows._

Run interactively (no `-Tier`) for a menu, or pick one explicitly.

---

## 📦 Package tables

Concrete IDs live in [`manifests/apps.json`](manifests/apps.json) and are re-validated nightly by [`windows-validate.yml`](.github/workflows/windows-validate.yml). Highlights:

### Core 15

| App | ID | Source |
|---|---|---|
| PowerToys | `Microsoft.PowerToys` | winget |
| Files | `FilesCommunity.Files` | winget |
| Everything | `voidtools.Everything` | winget |
| Flow Launcher | `Flow-Launcher.Flow-Launcher` | winget |
| Ditto | `Ditto.Ditto` | winget |
| ShareX | `ShareX.ShareX` | winget |
| 7-Zip | `7zip.7zip` | winget |
| VLC | `VideoLAN.VLC` | winget |
| Bitwarden | `Bitwarden.Bitwarden` | winget |
| Windows Terminal | `Microsoft.WindowsTerminal` | winget |
| PowerShell 7 | `Microsoft.PowerShell` | winget |
| Scoop | _bootstrap_ | script |
| winget-autoupdate | `Romanitho.Winget-AutoUpdate` | winget |
| RoundedTB *(optional)* | `TorchGM.RoundedTB` | winget |
| EarTrumpet | `File-New-Project.EarTrumpet` | winget |

### Dev +23 highlights

| App | ID | Source |
|---|---|---|
| WSL2 | `Microsoft.WSL` | winget |
| Docker Desktop *(optional)* | `Docker.DockerDesktop` | winget |
| VS Code | `Microsoft.VisualStudioCode` | winget |
| Cursor *(optional)* | `Anysphere.Cursor` | winget |
| Git / GH CLI / GPG | `Git.Git` / `GitHub.cli` / `GnuPG.Gpg4win` | winget |
| fnm (Node) | `Schniz.fnm` | winget |
| uv (Python) | `astral-sh.uv` | winget |
| rustup | `Rustlang.Rustup` | winget |
| Go | `GoLang.Go` | winget |
| Java via SDKMAN | _WSL bootstrap_ | script |
| Postman | `Postman.Postman` | winget |
| DBeaver / Beekeeper / Mongo Compass | `dbeaver.dbeaver` / `BeekeeperStudio.BeekeeperStudio` / `MongoDB.Compass.Full` | winget |
| TablePlus *(optional, paid)* | `TablePlus.TablePlus` | winget |
| Postico | _macOS-only_ | manual |
| ngrok / cloudflared | `ngrok.ngrok` / `Cloudflare.cloudflared` | winget |
| Tabby / Warp | `Eugeny.Tabby` / `Warp.Warp` *(optional)* | winget |

### AI +10 highlights

| App | ID | Source / notes |
|---|---|---|
| Ollama | `Ollama.Ollama` | winget — local LLM runtime |
| LM Studio *(optional)* | `ElementLabs.LMStudio` | winget — alt id `LMStudio.LMStudio` checked at runtime |
| Jan *(manual)* | — | jan.ai installer |
| ComfyUI portable *(optional)* | — | script — portable zip from GitHub Releases |
| Whispering *(manual)* | — | github.com/braden-w/whispering |
| Wispr Flow *(optional)* | `WisprFlow.WisprFlow` | winget — falls back to flowvoice.ai |
| Cursor *(dedup with Dev)* | `Anysphere.Cursor` | winget — installed once via Dev tier |
| Claude Desktop *(optional)* | `Anthropic.Claude` | winget — region-dependent |
| Raycast alternative | Flow Launcher (Core 15) | script — documentation-only |
| Recall alternative | Everything + PowerToys Run + Flow Launcher | script — privacy-preserving stack, nothing forced |

> **Optional / manual** entries never block an install run. They print guidance and keep going.

See [`docs/PACKAGES.md`](docs/PACKAGES.md) for the full list with notes.

---

## 🧰 What gets configured?

| Component | Source file | Destination |
|---|---|---|
| PowerToys + FancyZones | [`configs/powertoys/`](configs/powertoys) | `%LOCALAPPDATA%\Microsoft\PowerToys\` |
| Windows Terminal | [`configs/windows-terminal/settings.json`](configs/windows-terminal/settings.json) | `%LOCALAPPDATA%\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json` |
| PowerShell profile | [`configs/powershell/Microsoft.PowerShell_profile.ps1`](configs/powershell/Microsoft.PowerShell_profile.ps1) | `$PROFILE` (and Windows PowerShell variant) |
| VS Code | [`configs/vscode/`](configs/vscode) | `%APPDATA%\Code\User\` |
| AutoHotkey | [`configs/autohotkey/winforge.ahk`](configs/autohotkey/winforge.ahk) | `%USERPROFILE%\Documents\AutoHotkey\` |
| espanso | [`configs/espanso/match/base.yml`](configs/espanso/match/base.yml) | `%APPDATA%\espanso\match\` |
| WSL Ubuntu | [`configs/wsl/bootstrap-ubuntu.sh`](configs/wsl/bootstrap-ubuntu.sh) | run inside WSL |

Existing files at any destination are backed up to `%ProgramData%\WinForge\backups\` before being replaced.

---

## 🛡️ Safety model

- ✅ Run only as Administrator (the script enforces this).
- ✅ Creates a System Restore point before debloat/tweaks.
- ✅ Exports any registry key it modifies to `%ProgramData%\WinForge\backups\` as `.reg`.
- ✅ Records every action to `%ProgramData%\WinForge\state.json`; `uninstall.ps1` consumes it.
- ✅ Never removes Edge, Defender, the Microsoft Store, or App Installer.
- ✅ Manifest-driven: paid / region-locked / Store-only apps are marked `optional` or `manual` and never hard-fail the run.
- ✅ Logs everything to `%ProgramData%\WinForge\logs\winforge-<timestamp>.log`.

Read the full safety doc at [`docs/SAFETY.md`](docs/SAFETY.md).

---

## ↩️ Rollback

```powershell
# Safe rollback — reverses tweaks, restores debloat where possible, removes deployed configs.
.\uninstall.ps1

# Full rollback — also uninstall every package WinForge installed.
.\uninstall.ps1 -RemovePackages -Force
```

Detailed runbook: [`docs/ROLLBACK.md`](docs/ROLLBACK.md).

---

## 🧪 Validation & VM testing

> _Always_ test in a VM before running on your daily driver.

### Hyper-V (built into Windows 11 Pro/Enterprise)

```powershell
# Enable once
Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All

# Quick Create -> Windows 11 dev environment image (free, expires periodically)
vmconnect.exe localhost "Win11-WinForge-Test"
```

Inside the VM:

```powershell
# Take a checkpoint
Checkpoint-VM -Name Win11-WinForge-Test -SnapshotName "pre-winforge"

# Pull the repo and try a tier
git clone https://github.com/<your-fork>/winforge.git
cd winforge
.\install.ps1 -Tier dev -DryRun     # see what would happen
.\install.ps1 -Tier dev             # do it for real
```

### Other options

- **VirtualBox / VMware** — same flow; take a snapshot first.
- **Windows Sandbox** — too ephemeral for full installs but useful for spot-checking scripts.
- **Microsoft Dev Box / Cloud PC** — perfect throwaway target.

The repo's CI ([windows-validate.yml](.github/workflows/windows-validate.yml)) does:

1. PSScriptAnalyzer over every `.ps1`/`.psm1`.
2. JSON & YAML syntax validation across the repo.
3. `winget show` against every required (non-optional) package ID, with results in the run summary.
4. `install.ps1 -DryRun -Tier minimal` end-to-end on a fresh `windows-latest` runner.

---

## 🖼️ Screenshots

> _Drop your own screenshots into `docs/img/` and link them here._

- `docs/img/install-run.png` — install in progress
- `docs/img/terminal.png` — Windows Terminal + starship
- `docs/img/fancyzones.png` — FancyZones layout
- `docs/img/vscode.png` — VS Code with the WinForge profile

---

## 🧑‍💻 Contributing

PRs welcome — especially manifest updates as upstream IDs change. Run the validation workflow on your branch before requesting review.

```powershell
# Local lint (mirror of CI)
Invoke-ScriptAnalyzer -Path . -Recurse
Get-ChildItem -Recurse -Include *.json | % { Get-Content -Raw $_ | ConvertFrom-Json | Out-Null }
```

---

## 📜 License

[MIT](LICENSE) — do whatever you want, no warranty. See `LICENSE`.

---

<div align="center"><sub>Built with too much coffee and a healthy distrust of bloatware.</sub></div>

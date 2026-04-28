# Package Reference

The single source of truth is [`manifests/apps.json`](../manifests/apps.json). This page is a human-readable expansion with rationale, gotchas, and known-bad alternatives.

> **Runtime verification:** `install.ps1` runs `winget show --id <id> --exact` against every winget entry before attempting the install. If an upstream id has drifted or the package isn't in the user's region, the entry degrades to a warning instead of a hard failure. Optional / manual entries never block a run.

---

## Source legend

| Source | What it means |
|---|---|
| `winget` | Microsoft App Installer; native Windows package manager. Verified at runtime. |
| `scoop`  | Scoop, with the bucket name stamped in the entry |
| `manual` | No reliable headless install path; install.ps1 prints the upstream URL/instructions instead of failing |
| `script` | Not a package — orchestration step (Scoop bootstrap, FancyZones config import, SDKMAN-in-WSL, etc.) |
| `optional: true` | Won't break the run if it fails (paid, region-locked, account-required, drifting id) |

---

## Core 15 — essentials every Windows 11 box should have

| App | ID | Source | Notes |
|---|---|---|---|
| PowerToys | `Microsoft.PowerToys` | winget | FancyZones, PowerRename, Run, Color Picker, Peek |
| Files (Files App) | `FilesCommunity.Files` | winget | Modern multi-tab Explorer alternative |
| Everything | `voidtools.Everything` | winget | Sub-second filename search across the disk |
| Flow Launcher | `Flow-Launcher.Flow-Launcher` | winget | Fast keystroke launcher; runtime verifies the id |
| Ditto | `Ditto.Ditto` | winget | Clipboard manager with history |
| ShareX | `ShareX.ShareX` | winget | Best-in-class screenshot / screen-recording |
| 7-Zip | `7zip.7zip` | winget | Archive utility |
| VLC | `VideoLAN.VLC` | winget | Plays everything |
| Bitwarden | `Bitwarden.Bitwarden` | winget | Password manager (desktop) |
| Windows Terminal | `Microsoft.WindowsTerminal` | winget | Modern Windows terminal |
| PowerShell 7 | `Microsoft.PowerShell` | winget | `pwsh`, the preferred host for everything else |
| Scoop | _bootstrap_ | script | Installed by `install.ps1` via the official web installer at `https://get.scoop.sh`; not a winget package. Also enables the `extras`, `main`, `nerd-fonts`, and `versions` buckets. |
| winget-autoupdate (WAU) | `Romanitho.Winget-AutoUpdate` | winget | Daily background app updater. Runtime verifies the id. |
| RoundedTB *(optional)* | `TorchGM.RoundedTB` | winget | Taskbar tweaker. Optional because the winget id has drifted historically; falls back to a manual hint if not found. |
| EarTrumpet | `File-New-Project.EarTrumpet` | winget | Per-app volume mixer for the system tray |

> Browsers (Chrome / Firefox / Edge), Discord, Slack, Spotify, Notepad++, Process Explorer, OneDrive, Sysinternals, Telegram, qBittorrent, etc. are intentionally **not** in any tier — install them yourself if you want them. WinForge only installs what's on the list above.

## Power-user +20 — productivity, window mgmt, system insight, sync

| App | ID | Source | Notes |
|---|---|---|---|
| Espanso | `Espanso.Espanso` | winget | Cross-platform text expander |
| AutoHotkey | `AutoHotkey.AutoHotkey` | winget | v2. Runtime verifies the id (alt: `Lexikos.AutoHotkey`). |
| FancyZones configs | _import_ | script | `deploy-configs.ps1` imports `configs/powertoys/fancyzones-layouts.json`. Requires PowerToys (Core 15). |
| Komorebi *(optional)* | `LGUG2Z.komorebi` | winget | Tiling window manager. Optional; also available via Scoop (`extras/komorebi`). Runtime verifies. |
| MicaForEveryone *(optional)* | `MicaForEveryone.MicaForEveryone` | winget | Apply Mica/Acrylic to legacy windows. |
| StartAllBack *(optional, paid)* | `StartIsBack.StartAllBack` | winget | ~$5 lifetime, 30-day trial. Marked optional; runtime verifies. |
| ExplorerPatcher *(manual, risky)* | — | manual | Restores classic Explorer/taskbar UI. **Carries breakage risk on Windows 11 feature updates** — install from `github.com/valinet/ExplorerPatcher` only after reading the upstream README. See [`SAFETY.md`](SAFETY.md). |
| Process Lasso | `Bitsum.ProcessLasso` | winget | CPU/IO priority manager |
| HWiNFO | `REALiX.HWiNFO` | winget | Deep hardware sensor reporting |
| Macrium Reflect *(manual)* | `Macrium.ReflectFree` | manual | Macrium Reflect Free was discontinued. Use Macrium Reflect X (paid) or substitute Veeam Agent Free / Hasleo Backup Suite Free. |
| FreeFileSync | `FreeFileSync.FreeFileSync` | winget | Folder comparison & sync |
| Obsidian | `Obsidian.Obsidian` | winget | Local-first markdown notes |
| Notion | `Notion.Notion` | winget | Notes & wiki |
| Mosh *(optional, scoop)* | `main/mosh` | scoop | Mobile shell client. Scoop is the most reliable Windows path; also runs in WSL. |
| WinSCP | `WinSCP.WinSCP` | winget | SFTP/SCP/FTP GUI |
| FileZilla | `TimKosse.FileZilla.Client` | winget | FTP client |
| Rclone | `Rclone.Rclone` | winget | Cloud-storage CLI |
| Syncthing | `Syncthing.Syncthing` | winget | Continuous peer-to-peer file sync |
| Stremio | `Stremio.Stremio` | winget | Streaming media center |
| AnyDesk | `AnyDeskSoftwareGmbH.AnyDesk` | winget | Remote desktop |

## Dev +23 — toolchains, IDEs, runtimes, containers, DB GUIs

WSL2 is bootstrapped separately (`wsl --install -d Ubuntu-24.04`) plus the Linux side ([`configs/wsl/bootstrap-ubuntu.sh`](../configs/wsl/bootstrap-ubuntu.sh)) which installs zsh + oh-my-zsh, starship, **SDKMAN**, fnm, uv, rustup, Go, gh, and Docker integration.

| App | ID | Source | Notes |
|---|---|---|---|
| WSL2 | `Microsoft.WSL` | winget | OS feature; `wsl --install` does the rest |
| Docker Desktop *(optional)* | `Docker.DockerDesktop` | winget | Requires WSL2; commercial-license check applies |
| VS Code | `Microsoft.VisualStudioCode` | winget | Default editor |
| VS Code extension pack | _from manifest_ | script | `install.ps1` runs `code --install-extension <id>` for every entry in `vscodeExtensions[]` (see below) |
| Cursor *(optional)* | `Anysphere.Cursor` | winget | AI-first VS Code fork. Runtime verifies (alt: `Cursor.Cursor`). |
| Git | `Git.Git` | winget | Git for Windows |
| GitHub CLI | `GitHub.cli` | winget | `gh` |
| GPG (Gpg4win) | `GnuPG.Gpg4win` | winget | Commit + email signing |
| fnm | `Schniz.fnm` | winget | Fast Node Manager — installs Node toolchains on demand |
| uv | `astral-sh.uv` | winget | Python venvs & deps |
| rustup | `Rustlang.Rustup` | winget | Rust toolchain installer |
| Go | `GoLang.Go` | winget | |
| Java via SDKMAN | _WSL bootstrap_ | script | SDKMAN is Linux/macOS only. `configs/wsl/bootstrap-ubuntu.sh` installs SDKMAN inside WSL Ubuntu and uses it for Java/Maven/Gradle. **Not a Windows winget package.** |
| Postman | `Postman.Postman` | winget | API client |
| DBeaver | `dbeaver.dbeaver` | winget | Universal DB GUI |
| TablePlus *(optional, paid)* | `TablePlus.TablePlus` | winget | Windows build is paid after trial |
| Beekeeper Studio | `BeekeeperStudio.BeekeeperStudio` | winget | Open-source SQL GUI |
| MongoDB Compass | `MongoDB.Compass.Full` | winget | |
| Postico | — | manual | **macOS-only** — no Windows build exists. WinForge logs this and recommends DBeaver / Beekeeper Studio / TablePlus instead. |
| ngrok | `ngrok.ngrok` | winget | |
| Cloudflare Tunnel | `Cloudflare.cloudflared` | winget | `cloudflared` |
| Tabby | `Eugeny.Tabby` | winget | Cross-platform terminal |
| Warp *(optional)* | `Warp.Warp` | winget | Warp Terminal for Windows is in active development; runtime verifies. Falls back to a manual hint pointing at `app.warp.dev/download` if no stable id is found. |

## AI +10 — local LLMs, AI editors, voice, alternatives

| App | ID | Source | Notes |
|---|---|---|---|
| Ollama | `Ollama.Ollama` | winget | Local LLM runtime; `ollama run llama3.1` |
| LM Studio *(optional)* | `ElementLabs.LMStudio` | winget | GUI for local models. Runtime verifies (alt: `LMStudio.LMStudio`). Manual hint at `lmstudio.ai` if neither resolves. |
| Jan *(manual)* | — | manual | `jan.ai` — open-source local LLM client. No stable winget id at time of writing; download from upstream. |
| ComfyUI portable *(optional)* | _portable zip_ | script | install.ps1 offers to download the latest portable zip from `github.com/comfyanonymous/ComfyUI/releases` and unpack to `%USERPROFILE%\AI\ComfyUI`. Heavy GPU recommended. |
| Whispering *(manual)* | — | manual | `github.com/braden-w/whispering` — local-first dictation. Install from GitHub Releases. |
| Wispr Flow *(optional)* | `WisprFlow.WisprFlow` | winget | Voice-to-text. Runtime verifies; falls back to manual install from `flowvoice.ai`. |
| Cursor *(dedup with Dev)* | `Anysphere.Cursor` | winget | Already in Dev tier. The tier resolver dedupes by `source:id`, so Cursor is never installed twice. Listed here for completeness. |
| Claude Desktop *(optional)* | `Anthropic.Claude` | winget | Runtime verifies; not yet GA in winget for all regions. |
| Raycast alternative | _Flow Launcher_ | script | Raycast has no Windows build. WinForge installs **Flow Launcher** (already in Core 15) as the canonical Raycast alternative. Documentation-only entry; resolver records the choice and skips. |
| Recall alternative | _stack_ | script | Privacy-preserving alternative to Windows Recall. WinForge does **not** auto-install any third-party recall-style timeline tool. Recommended stack (already provided): **Everything** (instant file index) + **PowerToys Run** + **Flow Launcher**. Optionally evaluate Rewind / Recall replacements yourself; nothing is forced. |

---

## VS Code extensions

`manifests/apps.json -> vscodeExtensions` mirrors `configs/vscode/extensions.json -> recommendations`. install.ps1 runs `code --install-extension <id> --force` for each one after VS Code itself is installed.

## Adding / changing packages

1. Edit `manifests/apps.json`. Use `optional: true` if the install can fail (paid, region-locked, account-gated, drifting upstream id). Use `manual: true` if there is no clean headless install path. Use `source: script` for orchestration steps that aren't packages.
2. Run `pwsh ./tests/Test-Manifest.ps1` locally for offline checks, or `-OnlineCheck` to also run `winget show` against every required id.
3. Open a PR. The CI workflow validates JSON, runs PSScriptAnalyzer, and re-checks every required winget ID with `winget show`.

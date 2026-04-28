# WinForge tier patch — summary

Local-only patch (no GitHub push) to align the repo with the user's exact requested inventory.

## Files changed

| File | Change |
|---|---|
| `manifests/apps.json` | **Rewritten** — exact tier inventory, manifest version bumped to `2.0.0`, added `script` source for orchestration entries, richer per-entry notes documenting runtime verification fallback. |
| `manifests/apps.schema.json` | Added `script` to the `source` enum and a new optional `script` property describing it. |
| `scripts/lib/WinForge.psm1` | `Install-WinForgePackage` now: (a) handles `source: script` entries by logging and continuing instead of failing; (b) emits a clearer message when a winget id fails runtime verification. |
| `install.ps1` | Interactive tier menu now reflects the new counts (Core 15, Power-user +20, Dev +23, AI +10) and the actual headline apps. |
| `docs/PACKAGES.md` | **Rewritten** — every tier table matches the user's exact list, with notes on optional/manual/script handling and runtime verification. |
| `README.md` | Tier table and per-tier highlights tables match the new manifest. |

No other files were modified. No `.git` actions were performed.

## Tier inventories (after patch)

| Tier | Declared count | Actual entries | After dedupe-walk |
|---|---|---|---|
| `core` | 15 | 15 | 15 |
| `power-user` | +20 | 20 | 35 (core + power-user) |
| `dev` | +23 | 23 | 58 (core + power-user + dev) |
| `ai` | +10 | 10 | 67 (Cursor dedupes against Dev tier) |

Dedupe verified: `Anysphere.Cursor` is listed in both `dev` and `ai`, but `Resolve-WinForgeTier` keys on `source:id` so it is only installed once.

## Source mix per tier (after dedupe walk)

```
core         winget=14  script=1
power-user   winget=30  script=2   manual=2   scoop=1
dev          winget=50  script=4   manual=3   scoop=1
ai           winget=54  script=7   manual=5   scoop=1
```

## Apps removed from prior tiers (now intentionally absent)

The previous build shipped a lot of items the user did not request. All of these were removed:

- **Browsers:** Mozilla.Firefox, Google.Chrome
- **Chat/social:** Discord, Slack, Zoom, Telegram, Spotify
- **Editors / sysinternals creep:** Notepad++, Microsoft.Sysinternals.ProcessExplorer, Microsoft.Sysinternals.Autoruns, Microsoft.Sysinternals.Suite, WinDirStat
- **Misc:** qBittorrent, GitHub Desktop, JetBrains Toolbox, Visual Studio 2022 Community, Insomnia, Kitware.CMake, ninja-build.ninja, LLVM.LLVM, sccache, OpenJS.NodeJS.LTS, Python.Python.3.12 (system fallback), Microsoft.DotNet.SDK.8, EclipseAdoptium.Temurin.21.JDK (Java is now SDKMAN-in-WSL only), Microsoft.OneDrive, PuTTY, ueli, twpayne.chezmoi, starship/fzf/ripgrep/bat/zoxide/lazygit/CascadiaCode-NF (these now live in `configs/wsl/bootstrap-ubuntu.sh`, where they belong on the WSL side; if they're wanted on the Windows side too they can be re-added later).
- **AI noise:** OpenAI.ChatGPT, Codeium.Windsurf, Continue.Continue (still present as a VS Code extension), Msty, AnythingLLM, Pinokio, GitHub Copilot CLI, huggingface-cli, NVIDIA.CUDA, Stability.StableDiffusionWebUI.
- **Core moves:** Git and VS Code moved out of Core into Dev (they aren't on the user's Core-15 list).

The `vscodeExtensions[]` list was trimmed slightly (removed `wakatime.vscode-wakatime` because it requires an account). Everything else there matches the user's "VS Code + extension pack" requirement.

## Runtime verification & safety semantics

- Every `winget` entry is checked with `winget show --id <id> --exact --accept-source-agreements` before install.ps1 attempts the install. If the id doesn't resolve:
  - `optional: true` → warning, run continues, status `not-found`.
  - `optional` not set → error log line, run continues with the rest of the manifest, status `not-found`.
- `manual: true` / `source: manual` entries always print the upstream URL/instructions and never attempt an install. Used for: Postico (macOS-only), ExplorerPatcher (risky — explicit safety note), Macrium Reflect (free tier discontinued), Jan, Whispering, Postico.
- `source: script` entries are bookkeeping placeholders (Scoop bootstrap, FancyZones import, SDKMAN-in-WSL, Cursor dedupe, Raycast/Recall alternatives, ComfyUI portable, VS Code extension pack). They log and continue.
- `optional: true` flags applied to: RoundedTB, Komorebi, MicaForEveryone, StartAllBack, Mosh, Cursor (both placements), TablePlus, Warp, LM Studio, ComfyUI portable, Wispr Flow, Claude Desktop.

## Notable id choices and fallbacks

| App | Chosen id | Fallback / reasoning |
|---|---|---|
| Files | `FilesCommunity.Files` | Per the upstream Files project. |
| winget-autoupdate | `Romanitho.Winget-AutoUpdate` | Standard upstream id. |
| RoundedTB | `TorchGM.RoundedTB` | Marked optional in case the id has drifted. |
| EarTrumpet | `File-New-Project.EarTrumpet` | Stable. |
| Flow Launcher | `Flow-Launcher.Flow-Launcher` | Standard. |
| Ditto | `Ditto.Ditto` | Standard. |
| AutoHotkey | `AutoHotkey.AutoHotkey` | Note in entry mentions `Lexikos.AutoHotkey` as alt. |
| Komorebi | `LGUG2Z.komorebi` | Optional; Scoop `extras/komorebi` documented as alt. |
| MicaForEveryone | `MicaForEveryone.MicaForEveryone` | Optional. |
| StartAllBack | `StartIsBack.StartAllBack` | Optional, paid (~$5). |
| ExplorerPatcher | — | **Manual only** with explicit safety warning (breaks on Win11 feature updates). |
| Process Lasso | `Bitsum.ProcessLasso` | Standard. |
| HWiNFO | `REALiX.HWiNFO` | Standard. |
| Macrium Reflect | `Macrium.ReflectFree` | **Manual** — free tier discontinued; alternatives suggested in entry notes. |
| FreeFileSync | `FreeFileSync.FreeFileSync` | Standard. |
| Mosh | `main/mosh` (Scoop) | Optional. |
| FileZilla | `TimKosse.FileZilla.Client` | Standard. |
| Syncthing | `Syncthing.Syncthing` | Standard. |
| Stremio | `Stremio.Stremio` | Standard. |
| AnyDesk | `AnyDeskSoftwareGmbH.AnyDesk` | Standard. |
| Cursor | `Anysphere.Cursor` | Note covers `Cursor.Cursor` alt. Listed in Dev and AI; resolver dedupes. |
| GPG | `GnuPG.Gpg4win` | Per user spec. |
| Java via SDKMAN | _WSL bootstrap_ | **Script entry** — SDKMAN runs inside WSL Ubuntu (`configs/wsl/bootstrap-ubuntu.sh`), not on Windows. |
| TablePlus | `TablePlus.TablePlus` | Optional, paid after trial. |
| Postico | — | **Manual** — macOS-only, no Windows build. Alternative DBeaver/Beekeeper/TablePlus called out. |
| Tabby | `Eugeny.Tabby` | Standard. |
| Warp | `Warp.Warp` | Optional — Warp on Windows is in active development. Manual fallback to `app.warp.dev/download`. |
| LM Studio | `ElementLabs.LMStudio` | Optional. Note documents `LMStudio.LMStudio` as alt. |
| Jan | — | Manual; jan.ai. |
| ComfyUI portable | _portable zip_ | **Script** — install.ps1 hint to download from GitHub Releases. |
| Whispering | — | Manual. |
| Wispr Flow | `WisprFlow.WisprFlow` | Optional; manual fallback to flowvoice.ai. |
| Claude Desktop | `Anthropic.Claude` | Optional — region-dependent. |
| Raycast alt | _Flow Launcher_ | Documentation-only script entry. |
| Recall alt | _Everything + PowerToys Run + Flow Launcher_ | Documentation-only; nothing forced. |

## Validation results

Run `2025-04-28` against the patched repo (offline checks; live `winget show` happens in CI / on user's box).

| Check | Result |
|---|---|
| `jq -e .` over every JSON file (9 files) | **all ok** |
| Python `yaml.safe_load` over every YAML file (2 files) | **all ok** |
| `bash -n` over every `.sh` file (1 file) | **ok** |
| Brace + paren balance over every `.ps1` / `.psm1` (8 files) | **all balanced** |
| Tier counts match user spec | **15 / 20 / 23 / 10** |
| `Resolve-WinForgeTier` simulation (Python) — dedupe by `source:id` | **Cursor correctly dedupes between dev and ai** |
| `apps.schema.json` accepts new `script` source | **yes** (`source` enum: winget/scoop/store/manual/script) |

The CI workflow `.github/workflows/windows-validate.yml` is unchanged and will additionally run live `winget show` checks on every push.

## Not done (intentional)

- No `git` operations. Repo state is dirty — the parent agent should commit/push as desired.
- No edits to `configs/wsl/bootstrap-ubuntu.sh`. SDKMAN should already be there; if not, the Dev tier `sdkman-wsl` script entry documents the expectation.
- Did not add new orchestration scripts for ComfyUI portable / FancyZones import — they're flagged as `script` in the manifest and described in `docs/PACKAGES.md`. Implementing them is a separate task.

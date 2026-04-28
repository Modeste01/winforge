# WinForge Safety Model

WinForge changes a live OS. This document explains exactly **what it touches**, **what it never touches**, and **how to recover** if something goes wrong.

## Guarantees

1. **Elevation enforced.** `install.ps1`, `uninstall.ps1`, `debloat.ps1`, and `tweaks.ps1` will refuse to run unless launched as Administrator.
2. **Windows 11 only by default.** `Assert-WinForgePrereqs` blocks non-Win11 unless `-Force` is passed. The script also runs on Windows 11 IoT/LTSC variants.
3. **Restore point.** A `Checkpoint-Computer` is attempted before debloat or tweaks; failures are logged but non-fatal (some VMs disable System Protection).
4. **Registry backups.** Every key a tweak modifies is exported to `%ProgramData%\WinForge\backups\tweak-<key>-<timestamp>.reg` _before_ change. Restore by double-clicking the `.reg` or running `reg import`.
5. **State file.** Every action — package install, tweak applied, Appx removed, config deployed — is recorded in `%ProgramData%\WinForge\state.json`. `uninstall.ps1` reads it back for rollback.
6. **Logs.** Full transcript at `%ProgramData%\WinForge\logs\winforge-<timestamp>.log`.

## Things WinForge will **never** do

- Remove or disable **Microsoft Edge**, even though it's commonly debloated. Edge is now an OS dependency for several built-in features (PDF rendering, WebView2-based apps, etc.). Removing it can brick Outlook for Windows, Settings panes, etc.
- Disable **Windows Defender** or any security feature.
- Touch **BitLocker**, secure boot, TPM, or Windows Update agents.
- Remove **Microsoft Store** or **App Installer** (winget depends on it).
- Install any app it cannot verify with `winget show` first (unless you mark it `manual: true` in the manifest, in which case it just prints instructions).
- Push secrets or tokens into config files.

The full keep-list lives in [`manifests/appx-allowlist.json`](../manifests/appx-allowlist.json) under `neverRemove`.

## Tweaks applied (and reversible)

See [`scripts/tweaks.ps1`](../scripts/tweaks.ps1) for the canonical list. All are user- or machine-scope registry values — no service changes, no policy changes that survive a `Revert`.

| Setting | Scope | Default after Apply |
|---|---|---|
| Show file extensions | HKCU | On |
| Show hidden files | HKCU | On |
| Taskbar align left | HKCU | Yes |
| Disable taskbar widgets / chat | HKCU | Disabled |
| Compact Explorer mode | HKCU | On |
| Dark mode (apps + system) | HKCU | On |
| Disable Bing in Start | HKCU | Disabled |
| Show seconds in clock | HKCU | On |
| Disable advertising ID | HKCU | Disabled |
| Long paths enabled | HKLM | On |
| Developer Mode (sideload + symlinks) | HKLM | On |

## Debloat policy

Debloat operates on three lists in [`manifests/appx-allowlist.json`](../manifests/appx-allowlist.json):

- **`neverRemove`** — hard block. Patterns here are skipped even if they match `debloatCandidates`.
- **`alwaysKeep`** — informational; documents apps WinForge considers required.
- **`debloatCandidates`** — wildcard patterns matching apps that get removed unless they appear in `neverRemove`.

Removed apps are recorded in `state.json -> appxRemoved`. `debloat.ps1 -Mode Restore` and `uninstall.ps1` will attempt to re-register packages from `%ProgramFiles%\WindowsApps`, falling back to a "install from Microsoft Store" instruction if the bits are gone.

## What can still go wrong?

- **Vendor-pulled packages.** Manifest IDs sometimes vanish from the winget repo. The CI workflow's `package-availability` job catches this nightly; failures are soft, never fatal.
- **First-boot OOBE provisioning.** On a brand-new account that hasn't completed first sign-in, some Appx packages aren't yet provisioned and debloat will silently skip them.
- **Group Policy / MDM.** Corporate-managed devices may overwrite our HKCU/HKLM tweaks at the next policy sync. WinForge does not fight policy — by design.
- **Pending Windows Updates.** A device with pending updates can interleave installs and produce confusing winget output. Consider running Windows Update first.

## If something breaks

1. Check `%ProgramData%\WinForge\logs\` for the most recent log.
2. Run `.\uninstall.ps1` (without `-RemovePackages`) — this is non-destructive.
3. If a registry tweak misbehaves, find its backup `.reg` file in `%ProgramData%\WinForge\backups\` and double-click to import it.
4. If an Appx removal broke something, run `.\scripts\debloat.ps1 -Mode Restore` or reinstall from the Microsoft Store.
5. Worst case: roll back to the System Restore point named `WinForge install (<tier>)`.

## Reporting bugs

Open an issue with:

- `winforge-<timestamp>.log` (redact anything sensitive).
- Output of `winforge-status` (PowerShell profile helper) or `Get-Content $env:ProgramData\WinForge\state.json`.
- Windows version (`winver`).

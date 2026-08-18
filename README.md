# Droid Purifier

Droid Purifier is an offline-first Flutter desktop assistant for **De-Googling and debloating Android phones over ADB without root**. It is intentionally conservative: the app does not guess that an unknown system package is safe.

> Removing system packages can always carry device-specific risk. Droid Purifier combines a curated package knowledge list with a live scan of the connected phone and defaults unknown packages to **Unknown / Review** rather than “safe”.
>
<img width="1920" height="1080" alt="image" src="https://github.com/user-attachments/assets/83a35b68-f17a-4c33-ae6e-8d6d312464bb" />


## Version 1.3 highlights

- Clean three-part interface: **De-Google / Apps / Restore**.
- Large compact package list with two-line rows and explanations in tooltips.
- Four user-facing classifications only:
  - **Known Removable** — explicitly recognised and appropriate for bulk selection.
  - **Feature Dependent** — Android should remain functional, but a specific feature/app can stop working.
  - **Unknown** — Droid Purifier cannot verify the package; never bulk-selected.
  - **Protected** — Android/OEM infrastructure or a critical role on this specific device.
- **Recommended De-Google** selects only curated Google apps that are Known Removable.
- **Full De-Google** additionally selects curated Google service/framework packages such as Play Services, GSF and Play Store, while dynamically protected Android core stays locked.
- Presets replace the previous selection rather than accumulating selections.
- **Analyze Phone** performs a dry-run safety scan without removing anything.
- **Export report** saves a local JSON device/package analysis for troubleshooting or GitHub issue reports.
- **Expert Mode** is hidden behind an explicit warning and allows advanced users to manually select protected packages.
- Every removal gets a final safety re-scan immediately before execution.
- Post-removal **health check** verifies ADB, System UI, Settings, launcher, keyboard and WebView availability.
- Every removal batch is stored as a **session**, making whole-session rollback available from Restore.
- Individual APK/split-APK backups are still supported.
- No telemetry and no runtime network calls; analysis is performed locally through bundled ADB.

## Dynamic device safety scan

Droid Purifier does not rely only on package names. On connection it probes the current phone and, where supported by that Android version/vendor shell, detects:

- Android version and API level
- system vs user packages
- APEX/Mainline packages
- runtime resource overlays through Android's overlay manager
- current launcher
- current keyboard/IME
- current dialer
- current SMS app
- enabled accessibility services
- current/default browser
- current WebView provider
- device provisioning/setup state

Dynamic facts override static rules. For example, a keyboard package can be Feature Dependent on one phone but **Protected** on another phone when it is the active keyboard.

Unsupported commands on old/vendor Android builds fail conservatively; they do not cause unknown packages to become Known Removable.

## De-Google behavior

### Recommended De-Google

Recommended De-Google is the conservative preset. It selects only explicitly curated Google consumer apps that Droid Purifier currently classifies as Known Removable on the connected phone.

It deliberately does not automatically remove unknown Google packages, current role apps, Android Mainline/core components, overlays, or WebView.

### Full De-Google

Full De-Google additionally includes curated Google framework and feature packages such as:

- Google Play Services
- Google Services Framework
- Google Play Store
- Google app / Assistant
- Google backup/restore and sync components
- Google Location History
- Android Auto
- Digital Wellbeing
- Google Text-to-Speech
- other curated Google integrations

Removing these can break third-party apps or features that depend on Google APIs, FCM, Play Integrity, Google account services, TTS, Android Auto, etc. Droid Purifier shows those consequences before removal.

Role-sensitive apps such as a current launcher, keyboard, dialer, SMS app, accessibility service or WebView provider are dynamically protected. Users should install/select a replacement before attempting to remove them.

## Why some `com.google.*` packages remain

A Google package namespace does not always mean a Google consumer app or tracking service. Google-certified Android builds can use Google-namespaced implementations of real Android platform modules.

Examples include Permission Controller, DocumentsUI, ExtServices, networking modules, WebView and modern Mainline/APEX modules. Droid Purifier protects these rather than trying to achieve “zero package names containing Google” at the cost of breaking Android.

## Manual Apps mode

The Apps tab exposes all installed packages.

Normal mode:

- Known Removable packages can be selected normally.
- Feature Dependent and Unknown packages can be selected manually and receive stronger review warnings.
- Protected packages cannot be selected.

Expert Mode:

- Requires typing `EXPERT` to enable.
- Allows manual selection of Protected packages.
- Protected removals require a stronger `FORCE` confirmation before execution.

Presets never use Expert Mode and never auto-select Unknown or Protected packages.

## Safety and rollback

Before a batch runs, Droid Purifier re-scans the device so a package that has become the active launcher/IME/provider can be blocked at the last moment.

Backups are stored under:

`DroidPurifier/Backups/<device-id>/<package>/`

Removal history is stored under:

`DroidPurifier/Sessions/<device-id>/`

Reports are exported under:

`DroidPurifier/Reports/`

Backup is recovery assistance, not a guarantee: if a device cannot boot far enough to expose ADB, a desktop ADB tool may not be able to restore packages automatically.

## Removal method

Droid Purifier uses:

`adb shell pm uninstall -k --user 0 <package>`

For many preinstalled system packages this removes the package for Android user 0 instead of deleting the read-only system APK. Restore first tries `cmd package install-existing`, then `pm install-existing`, then a local APK/split-APK backup when available.

## Android compatibility strategy

Droid Purifier targets old Android package-manager workflows while adding newer capabilities when the device supports them.

- Legacy Android uses widely available `pm`, `settings`, `dumpsys` and role/default-app fallbacks.
- Android 10+ additionally receives APEX/Mainline detection when supported.
- Overlay and role probes are capability-based: unsupported vendor commands are ignored safely.
- Unknown future Android/OEM packages remain Unknown rather than being guessed removable.

No static list can prove every proprietary OEM dependency on every Android release. Conservative Unknown classification is therefore a deliberate safety feature.

## Build and release

GitHub Actions validates Flutter analysis/tests, builds a real Windows x64 Flutter release, bundles Android Platform Tools, and creates:

- `DroidPurifier-Windows-x64.zip`
- `DroidPurifier-Setup.exe`
- `DroidPurifier-macOS.zip` on manual/tagged macOS runs

The generated Windows runner opens with a larger workspace so the package list remains the main focus of the interface.

## Project origin

Droid Purifier is an independent implementation inspired by workflow/safety ideas from the MIT-licensed [System Purifier](https://github.com/orailnoor/sys-purifier) project. Droid Purifier's UI, dynamic safety scanner, package policy, presets and rollback workflow are independently implemented.

## License

MIT. See `LICENSE`.

# Droid Purifier

Droid Purifier is an offline-first Flutter desktop assistant for **De-Googling and debloating Android phones over ADB without root**. It is intentionally conservative: the app does not guess that an unknown system package is safe.

> Removing system packages can always carry device-specific risk. Droid Purifier combines dynamic device analysis with conservative package policy and defaults unknown system/vendor packages to **Review** rather than guessing that they are removable.
>
<img width="1920" height="1080" alt="image" src="https://github.com/user-attachments/assets/83a35b68-f17a-4c33-ae6e-8d6d312464bb" />

## TechyDruid

Website: https://techydruid.com/  
YouTube: https://www.youtube.com/@TechyDruid

## Download

**[Download the latest published version of Droid Purifier](https://github.com/techydruid/DroidPurifier/releases/latest)**

For most Windows users, use the Setup EXE from the release page. A portable ZIP is also provided.

## Version 1.4.0 highlights

Version 1.4.0 keeps the interface simple while moving more device-specific intelligence into the background scanner.

- Dynamic detection of user apps, Google apps, OEM apps and system/vendor packages instead of relying mainly on hard-coded package names.
- Real application labels and richer local metadata through the temporary on-device scan helper.
- Manufacturer/ROM-aware OEM categorization.
- Generic detection of future/unknown Google consumer apps when metadata supports that classification.
- Four clear safety states: **Removable / Caution / Review / Protected**.
- Live protection for launcher, keyboard, dialer, SMS, accessibility services, current WebView, APEX/Mainline modules and runtime overlays.
- Data-sensitive warnings for apps such as Google Authenticator before removal.
- Dynamic **Recommended** and **Full De-Google** presets.
- Recommended and Full De-Google now show a clear active state: only the selected preset is highlighted.
- App filtering is split into independent **Category** and **Status** filters so both can be combined without mixing different concepts in one menu.
- Refined dark interface with subtle green accents, cleaner counters, clearer metadata tags, polished dialogs and more compact package rows.
- **Review & remove** remains the primary action; **Analyze** remains secondary.
- Typed confirmations use clearly muted placeholders such as `Type BACKUP here` and `Type EXPERT here`.
- Batch health checkpoints, removal sessions and rollback support remain enabled.
- No telemetry and no runtime network calls; analysis is performed locally through bundled ADB and the local scan helper.

## Dynamic device safety scan

Droid Purifier does not rely only on package names. On connection it probes the current phone and, where supported by that Android version/vendor shell, detects:

- Android version and API level
- system vs user packages
- application labels and package metadata
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
- OEM/vendor context such as manufacturer, brand and ROM naming

Dynamic facts override static rules. For example, an app that would normally be removable can become **Protected** when it is the active launcher, keyboard, dialer, SMS handler, accessibility service or WebView provider.

Unsupported commands on old/vendor Android builds fail conservatively; they do not cause unknown packages to become Removable.

## De-Google behavior

### Recommended De-Google

Recommended De-Google is the conservative preset. It dynamically selects Google consumer apps that Droid Purifier currently classifies as **Removable** on the connected phone.

It deliberately does not automatically remove unknown Google background/system packages, current role apps, Android Mainline/core components, overlays, or WebView.

### Full De-Google

Full De-Google additionally includes Google framework and feature packages that are classified as removable or caution-level candidates, such as Play Services, Google Services Framework and Play Store when the current device state allows them to be selected.

Removing these can break third-party apps or features that depend on Google APIs, FCM, Play Integrity, Google account services, TTS, Android Auto, etc. Droid Purifier shows those consequences before removal.

Role-sensitive apps such as a current launcher, keyboard, dialer, SMS app, accessibility service or WebView provider are dynamically protected. Users should install/select a replacement before attempting to remove them.

## Why some `com.google.*` packages remain

A Google package namespace does not always mean a Google consumer app or tracking service. Google-certified Android builds can use Google-namespaced implementations of real Android platform modules.

Examples include Permission Controller, DocumentsUI, ExtServices, networking modules, WebView and modern Mainline/APEX modules. Droid Purifier protects these rather than trying to achieve “zero package names containing Google” at the cost of breaking Android.

## Manual Apps mode

The Apps tab exposes all installed packages while keeping the main workflow straightforward.

Filters are separated by purpose:

- **Category:** All / User apps / Google / OEM / System
- **Status:** All / Removable / Caution / Review / Protected

Both filters are applied together, so a user can—for example—show only OEM apps that are currently Caution, or only Google apps that are Removable.

Normal mode:

- Removable packages can be selected normally.
- Caution and Review packages can be selected manually and receive stronger review warnings.
- Protected packages cannot be selected.

Expert Mode:

- Requires typing `EXPERT` to enable.
- Allows manual selection of Protected packages.
- Protected removals require a stronger `FORCE` confirmation before execution.

Presets never require Expert Mode and never auto-select Protected packages.

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
- Enhanced metadata scanning is local and falls back to ADB-only detection if the helper cannot be used.
- Unknown future Android/OEM packages remain Review rather than being guessed removable.

No static list can prove every proprietary OEM dependency on every Android release. Conservative Review classification is therefore a deliberate safety feature.

## Build and release

GitHub Actions validates Flutter analysis/tests, builds a real Windows x64 Flutter release, bundles Android Platform Tools and the local scan helper, and creates:

- `DroidPurifier-1.4.0-Windows-x64.zip`
- `DroidPurifier-1.4.0-Setup.exe`
- `DroidPurifier-1.4.0-macOS.zip` on manual/tagged macOS runs

The generated Windows runner opens with a larger workspace so the package list remains the main focus of the interface.

## Project origin

Droid Purifier is an independent implementation inspired by workflow/safety ideas from the MIT-licensed [System Purifier](https://github.com/orailnoor/sys-purifier) project. Droid Purifier's UI, dynamic safety scanner, package policy, presets and rollback workflow are independently implemented.

## License

MIT. See `LICENSE`.

# Droid Purifier

Droid Purifier is a Flutter desktop tool for **De-Googling and debloating Android phones over ADB without root**. It focuses on direct multi-select package removal while protecting Android components that must remain for the operating system to function.

> Removing system packages always carries risk and OEM builds differ. Droid Purifier is intentionally conservative: unknown Google/system packages are never auto-selected, Android core/Mainline modules are protected, and every removal batch is reviewed before execution.

## Version 1.2 highlights

- **Recommended De-Google** — selects ordinary Google apps and curated non-core Google services while keeping Google Play services, Google Services Framework, and Play Store.
- **Full De-Google** — additionally selects Play services, GSF, Play Store, Google account/sync/backup/Assistant-style services and other curated Google integrations.
- **Android core stays protected even in Full De-Google.** A package using a `com.google.*` name is not automatically considered bloatware.
- Detects Android version and API level.
- Detects APEX/Mainline packages on modern Android and locks them automatically.
- Protects Android 10 Google-build core packages such as Permission Controller, DocumentsUI, ExtServices and Module Metadata.
- Protects modern Mainline aliases such as Android permission, networking, Conscrypt, DNS Resolver, ART/runtime and other platform modules.
- Protects Google Android resource overlays (`com.google.android.overlay.*`).
- Protects Android System WebView by default because a working WebView provider may be required by many apps.
- Unknown future `com.google.*` packages fail safe as **Manual Review** instead of being automatically selected.
- Setup Wizard is protected while Android initial provisioning is incomplete.
- Role-sensitive apps such as keyboard, dialer, SMS, camera, launcher, TalkBack and some carrier/enterprise components are **Manual Review** and are not auto-selected.
- **Select safe shown** replaces unrestricted Select Visible.
- High/Critical removals require typing `CONFIRM`.
- Optional APK + split-APK backup before each removal.
- Restore tries multiple Android-compatible methods, then falls back to the saved APK files.

## What “Full De-Google” means

Full De-Google aims to remove Google applications and Google service infrastructure that can be removed for Android user 0 without deliberately removing Android platform components.

It may select packages such as:

- Google Play services
- Google Services Framework
- Google Play Store
- Google app / Assistant
- Google account/sync/backup/restore components
- Google Location History
- Android Auto
- Digital Wellbeing
- Google TTS
- Gmail, YouTube, Maps, Photos, Drive, Calendar, Contacts and other Google apps

Removing Google Play services/GSF can make third-party apps that rely on Google APIs, FCM push notifications, Play Integrity, Google location APIs, or other Google services stop working. That is separate from protecting Android itself.

### Google-namespaced packages that should remain

Some stock Android builds use Google package names for Android platform components. Droid Purifier identifies these as **ANDROID CORE** and disables their checkboxes. Examples include:

- `com.google.android.permissioncontroller`
- `com.google.android.permission`
- `com.google.android.documentsui`
- `com.google.android.ext.services`
- `com.google.android.ext.shared`
- `com.google.android.modulemetadata`
- `com.google.android.networkstack`
- `com.google.android.captiveportallogin`
- `com.google.android.webview`
- `com.google.android.conscrypt`
- `com.google.android.resolv`
- Android Mainline/APEX modules detected dynamically
- Google Android runtime-resource overlays

Keeping these does not mean the app failed to remove a normal Google application; many are implementations of Android platform functionality.

## Android version compatibility

Droid Purifier is designed around ADB package-manager commands available on **Android 5.1+**, while adding special handling for the modular/Mainline/APEX architecture introduced on newer Android versions.

Compatibility strategy:

- **Older Android:** recognizes legacy packages such as Google Account Manager (`com.google.android.gsf.login`), Google Backup Transport, One-Time Initializer, Partner Setup, legacy Play Music and other older Google packages.
- **Android 10:** explicitly protects the Google-build Permission Controller, DocumentsUI, ExtServices, Module Metadata and related overlays.
- **Android 11 and later:** protects newer Mainline package aliases and detects APEX modules dynamically when supported by the device shell.
- **Future Android releases:** unknown Google packages are never automatically removed, and packages detected as APEX are always protected.

OEM firmware can rename, add or remove packages, so no static package database can safely promise identical behavior on every device. The conservative unknown-package policy is intentional.

## Multi-select workflow

1. Connect an Android phone with USB debugging enabled.
2. Choose **Recommended De-Google**, **Full De-Google**, or another curated preset.
3. Review the selected packages.
4. Manually review any packages marked **MANUAL REVIEW** if you want to go further.
5. Keep **Back up APK files first** enabled when possible.
6. Confirm the batch and remove the selected packages.

Presets select packages only; they never execute removals immediately.

## How removal works

Droid Purifier uses a per-user uninstall:

`adb shell pm uninstall -k --user 0 <package>`

This normally removes/disables the preinstalled package for Android user 0 rather than erasing the APK from a read-only system partition. A factory reset or firmware reinstallation can therefore bring preinstalled packages back.

Before removal, Droid Purifier can run:

`adb shell pm path <package>`

and pull the base APK plus split APKs to:

`DroidPurifier/Backups/<device-id>/<package>/`

For restoration it first tries `cmd package install-existing`, then `pm install-existing`, then falls back to the local APK backup.

## Windows build

1. Install Flutter with Windows desktop support.
2. Clone this repository.
3. Run:

   `powershell -ExecutionPolicy Bypass -File scripts/bootstrap_windows.ps1`

4. Start with:

   `flutter run -d windows`

Release builds bundle Android Platform Tools, so end users do not need to install ADB separately.

## GitHub Actions

The workflow runs Flutter analysis/tests and creates:

- `DroidPurifier-Windows-x64.zip` — portable Windows build with ADB.
- `DroidPurifier-Setup.exe` — Windows installer with ADB.
- `DroidPurifier-macOS.zip` — macOS build on manual/tagged runs.

Pushes to `main` automatically validate/build Windows. Tagged releases can attach the artifacts automatically.

## Project origin

Droid Purifier is an independent implementation inspired by workflow/safety ideas from the MIT-licensed [System Purifier](https://github.com/orailnoor/sys-purifier) project. Droid Purifier's multi-select UI, De-Google policy, preset model and source code in this repository are independently implemented.

## License

MIT. See `LICENSE`.

# Droid Purifier

Droid Purifier is a cross-platform Flutter desktop app for auditing and removing Android packages over ADB **without root**. Its main UX difference is first-class **multi-select bulk removal directly from the installed-app list**, plus curated one-click selection presets.

> Removing Android system packages can break device features. Use this software at your own risk. Droid Purifier removes packages only for Android user 0 using `pm uninstall -k --user 0`; it does not erase APKs from the read-only system partition.

## Highlights

- Windows and macOS desktop UI built with Flutter.
- Detects multiple connected ADB devices and shows manufacturer/model/Android version.
- Search and filter installed packages.
- Checkbox selection directly in the main package list.
- **Recommended Safe Debloat** preset.
- **Remove Google Apps** preset that deliberately excludes Google Play services, Google Services Framework, and Play Store.
- **Manufacturer Bloatware** preset with curated Samsung, Xiaomi/MIUI, OPPO/ColorOS/HeyTap, realme-related and Meta preload packages.
- Presets only select packages; they never remove anything automatically.
- **Select visible** and **Clear selection** shortcuts.
- Bulk review screen before removal.
- Built-in Low / Medium / High / Critical / Protected risk levels.
- Protected Android core packages cannot be selected.
- High/Critical bulk operations require typing `CONFIRM`.
- Optional APK + split-APK backup before every removal.
- If one package backup fails, that package is not removed.
- Bulk progress and per-package failure results.
- Restore via `cmd package install-existing --user 0`, with backed-up APK fallback.
- No telemetry or network calls from the app itself.

## Preset safety model

The presets are intentionally allow-list based. Droid Purifier does **not** select every package beginning with `com.samsung`, `com.miui`, `com.google`, etc. Only package IDs in the curated preset database are selected.

The Google preset does not include:

- `com.google.android.gms` — Google Play services
- `com.google.android.gsf` — Google Services Framework
- `com.android.vending` — Google Play Store

Those packages can affect core Google functionality and therefore remain outside the quick Google preset.

## Build on Windows

1. Install Flutter and enable Windows desktop development.
2. Clone this repository.
3. From PowerShell in the repository folder, run:

   `powershell -ExecutionPolicy Bypass -File scripts/bootstrap_windows.ps1`

4. Start the app:

   `flutter run -d windows`

The bootstrap script generates the standard Flutter Windows runner and downloads Google Android platform-tools into `tools/platform-tools`.

## Build on macOS

1. Install Flutter and Xcode command-line tools.
2. Clone this repository.
3. Run:

   `./scripts/bootstrap_macos.sh`

4. Start the app:

   `flutter run -d macos`

## GitHub Actions releases

The included workflow builds:

- `DroidPurifier-Windows-x64.zip` — portable Flutter Windows release including ADB.
- `DroidPurifier-Setup.exe` — single Windows installer including the Flutter application and ADB.
- `DroidPurifier-macOS.zip` — macOS application bundle.

Every push to `main` builds the Windows app automatically. You can also run the workflow manually from **Actions → Build desktop releases**, or push a version tag such as `v1.1.0`. Tagged builds are attached to the GitHub Release automatically.

## How removal works

For each selected package, Droid Purifier can first query APK paths with:

`adb shell pm path <package>`

It pulls the base APK and any split APKs into the user's `DroidPurifier/Backups/<device-id>/<package>/` folder. It then performs:

`adb shell pm uninstall -k --user 0 <package>`

Because this is a per-user uninstall, the package normally remains on the system image. The Restore tab first attempts:

`adb shell cmd package install-existing --user 0 <package>`

and falls back to the local APK backup if needed.

## Device preparation

1. Enable Developer options on Android.
2. Enable USB debugging.
3. Connect the phone by USB.
4. Approve the computer's RSA debugging prompt.
5. Open Droid Purifier and choose the detected device.

## Safety model

The built-in database marks core packages such as Android System UI, Settings, Package Installer, and Phone Services as **Protected**. They cannot be selected from the UI. Google Play services and Google Services Framework are marked Critical and require typed confirmation if manually selected.

Unknown OEM-prefixed packages are marked Medium instead of being assumed safe. The preset database should continue to be expanded conservatively as device-specific packages are researched.

## Project origin

This is an independent implementation inspired by the workflow and safety ideas of the MIT-licensed [System Purifier](https://github.com/orailnoor/sys-purifier) project by `orailnoor`. Droid Purifier's bulk-selection UI, preset workflow, and source code in this repository are independently implemented.

## License

MIT. See `LICENSE`.

#!/usr/bin/env bash
set -euo pipefail

command -v flutter >/dev/null 2>&1 || { echo "Flutter is not installed or not in PATH." >&2; exit 1; }

flutter config --enable-macos-desktop
flutter create --platforms=macos --project-name droid_purifier .
flutter pub get

mkdir -p tools
curl -fL "https://dl.google.com/android/repository/platform-tools-latest-darwin.zip" -o /tmp/platform-tools.zip
rm -rf tools/platform-tools
unzip -q /tmp/platform-tools.zip -d tools
chmod +x tools/platform-tools/adb
rm -f /tmp/platform-tools.zip

echo "Ready. Run: flutter run -d macos"

# Contributing

Contributions are welcome.

When adding package recommendations, prefer conservative allow-lists over broad package-prefix matching. Include the device/OEM, Android version, package purpose, and any known side effects in the pull request description.

Before opening a pull request, run:

- `flutter pub get`
- `flutter analyze`
- `flutter test`

Do not commit downloaded Android platform-tools or generated desktop build folders.

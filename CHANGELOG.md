# Changelog

## 1.4.0 (unreleased)

- Reworked app detection around dynamic device metadata instead of relying mainly on hard-coded package names.
- Added real application labels and richer metadata through a temporary local Android scan helper.
- Added manufacturer/ROM-aware OEM categorization and generic detection for future/unknown Google consumer apps.
- Added separate safety states: Removable, Caution, Review and Protected.
- Added live protection for current launcher, keyboard, dialer, SMS, accessibility services, WebView, APEX/Mainline packages and overlays.
- Added data-sensitive removal warnings such as Google Authenticator migration reminders.
- Added dynamic Recommended and Full De-Google presets.
- Fixed preset highlighting so only the currently selected Recommended or Full De-Google preset uses the filled active state.
- Split app filtering into independent Category and Status filters that work together.
- Made typed confirmation hints clearly look like placeholders, including `Type BACKUP here` and `Type EXPERT here`.
- Refined the dark UI with clearer visual hierarchy, cleaner status counters, better metadata tags, more polished dialogs and refined package rows.
- Kept Review & remove as the primary action and Analyze as a secondary action.
- Added batch health checkpoints, session rollback and v1.4.0 release packaging with bundled ADB and the scan helper.

## 1.1.0

- Added direct checkbox multi-selection in the installed-app list.
- Added Recommended Safe Debloat preset.
- Added curated Remove Google Apps preset.
- Added curated Manufacturer Bloatware preset.
- Google preset excludes Play Services, Google Services Framework, and Play Store.
- Added bulk review, typed confirmation for dangerous packages, progress, and per-package results.
- Added APK backup and restore support.
- Added automatic Windows portable ZIP and Setup EXE builds with GitHub Actions.

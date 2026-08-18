# Security and safety

Droid Purifier can remove Android packages for user 0 over ADB. Removing the wrong package can disable device features or require recovery steps.

Please report security issues privately to the repository owner rather than publishing exploitation details in a public issue.

## Safety rules used by the app

- Known core Android packages are marked Protected and cannot be selected.
- High/Critical packages require typed confirmation before a batch starts.
- Curated presets select packages only; the user must review and confirm removal.
- Backups can be created before removal, and a backup failure prevents removal of that package.
- The uninstall command is scoped to Android user 0 and does not delete files from the read-only system partition.

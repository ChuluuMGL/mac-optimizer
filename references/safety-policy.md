# Safety Policy

Mac Optimizer follows a diagnosis-first safety model.

## Required Defaults

- Generate a diagnostic report before cleanup.
- Treat every recommendation as optional.
- Run `--dry-run` before deletion or settings changes.
- Ask for confirmation before execution.
- Prefer `--safe` when the user wants conservative maintenance.
- Keep generated logs and data in `logs/` and `data/`.

## High-Risk Boundary

The following actions must not be added to automatic quick or one-click flows:

- Deleting Time Machine local snapshots.
- Removing Docker volumes or broad Docker system data.
- Erasing simulator data.
- Disabling system services.
- Changing power, sleep, or hibernation policy.
- Deleting project directories, source folders, documents, photos, or user-created media.

High-risk items may appear in reports as manual review recommendations only.

## Privacy Boundary

Reports may summarize sizes, paths, and categories needed for maintenance. Do not expose secrets, file contents, private messages, credentials, or unrelated personal data.

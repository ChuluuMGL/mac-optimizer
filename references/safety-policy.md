# Safety Policy

Mac Optimizer follows a diagnosis-first safety model.

## Required Defaults

- Generate a diagnostic report before cleanup.
- Treat every recommendation as optional.
- Run `--dry-run` before deletion or settings changes.
- Ask for confirmation before execution.
- Prefer `--safe` when the user wants conservative maintenance.
- In automatic flows, treat Trash, Downloads, broad application logs, app containers, and developer data as report-only.
- Require `--tune-ui`, `--flush-dns`, or `--truncate-v2ray-log` before the corresponding UI, DNS, or named-log action.
- Keep generated logs and data in `logs/` and `data/`.
- Run DNS/HTTPS connectivity probes only when `full-check.sh --network` is explicitly requested; never change DNS, proxy, routes, or Wi-Fi settings as part of a diagnostic.

## Automatic Cleanup Boundary

Automatic quick and one-click flows may clean only:

- Regenerable browser, package-manager, and known application caches.
- Codex Crashpad pending reports older than seven days.
- A specifically named log only when its explicit opt-in flag is present and `--safe` is absent.

They must not empty Trash, delete Downloads by age, or delete broad log matches. Those findings remain visible for item-level review.

## High-Risk Boundary

The following actions must not be added to automatic quick or one-click flows:

- Deleting Time Machine local snapshots.
- Removing Docker volumes or broad Docker system data.
- Erasing simulator data.
- Disabling system services.
- Changing power, sleep, or hibernation policy.
- Deleting project directories, source folders, documents, photos, or user-created media.

High-risk items may appear in reports as manual review recommendations only.

## Advanced Scripts (`03-优化方案/`)

- `deep-storage-cleanup.sh`, `power-optimization.sh`, and `ai-tools-cleanup.sh` accept `--dry-run`. In that mode they report the paths, sizes, and `pmset`/`defaults` changes they would make, and they make zero changes: no `rm`, no `sudo`, no `xcrun simctl`, and no setting writes.
- Without `--dry-run`, each destructive step asks for its own confirmation. Prompts must name what is permanently lost. For example, Android AVD removal deletes whole emulator images, not cache.
- All paths derive from `MAC_OPT_USER_HOME`, never a bare `~`, so running under `sudo` cannot target `/var/root`.
- Scripts must not hard-code personal project folders. Project-level cleanup, such as `__pycache__`, runs only on directories the user lists in `MAC_OPT_PYCACHE_DIRS`.

## Privacy Boundary

Reports may summarize sizes, paths, and categories needed for maintenance. Do not expose secrets, file contents, private messages, credentials, or unrelated personal data.

# Risk Model

Use this model when adding or reviewing recommendations.

| Risk | Definition | Examples | Allowed automation |
|------|------------|----------|--------------------|
| Low | Reversible or naturally regenerated data with low user impact. | Browser caches, old logs, DNS cache, package manager caches. | May be previewed and optionally executed. |
| Medium | User-visible data or preferences where mistakes are annoying but usually recoverable. | Trash cleanup, old downloads, Dock/animation preferences. | Requires dry-run and clear confirmation. |
| High | Data loss, backup integrity, developer environment breakage, or system behavior changes are plausible. | Time Machine snapshots, Docker volumes, simulator erase, system services, power policy. | Report only; do not auto-run. |

## Classification Questions

1. Could this delete user-created work?
2. Could this remove backup or recovery data?
3. Could this break a development environment or local database?
4. Could this change system behavior outside the current maintenance session?
5. Is rollback uncertain or expensive?

If any answer is yes, classify the recommendation as high risk unless there is a narrow, tested, reversible implementation.

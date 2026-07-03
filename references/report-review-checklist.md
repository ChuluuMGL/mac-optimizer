# Report Review Checklist

Use this checklist after a diagnostic report is generated and before recommending cleanup.

## Read The Report First

- Confirm the report path and check time.
- Check free space, disk usage, and health score.
- Identify the top storage pressure categories.
- Separate actual findings from empty sections or unavailable system data.

## Classify Recommendations

| Risk | Review rule | User-facing guidance |
|------|-------------|----------------------|
| 低风险 | Data is regenerated or naturally temporary. | Offer dry-run preview first. |
| 中风险 | Data may be user-visible or preference-changing. | Ask for confirmation and mention rollback when available. |
| 高风险 | Data loss, backup impact, developer environment breakage, or system behavior change is plausible. | Explain only; keep it out of automatic flows. |

## Handoff Format

Return a short summary with:

- Report location.
- Current health score and main pressure points.
- Low-risk actions that can be previewed.
- Medium-risk actions that require confirmation.
- High-risk items that were intentionally skipped.
- Suggested command for the next preview step.

## Stop Conditions

Do not recommend execution when:

- The report is missing or stale.
- The user has not seen a dry-run preview.
- The action could delete source files, project data, backups, or user-created documents.
- The rollback path is unclear.

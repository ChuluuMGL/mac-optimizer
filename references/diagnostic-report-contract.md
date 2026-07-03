# Diagnostic Report Contract

The diagnostic report is the source of truth for optimization suggestions.

## Required Sections

- Check time, tool version, macOS version, model, and data volume.
- System overview: CPU, memory, disk size, free space, disk usage, battery basics when available.
- Disk usage analysis.
- Memory and process overview.
- Cache and log overview.
- Startup and service hints.
- Time Machine snapshot visibility.
- Health score.
- Optional low, medium, and high risk recommendations.
- Suggested commands for preview and confirmed execution.

## Generated Data

The check script writes:

- `logs/check-report-YYYY-MM-DD.md`
- `logs/check-YYYY-MM-DD.log`
- `data/check-YYYY-MM-DD.json`
- `data/check-latest.json`
- `data/recommendations-latest.json`

## Recommendation Requirements

Every recommendation should include:

- Risk level.
- Situation where it applies.
- Recommended next action.
- Whether it is allowed in automatic flows.

High-risk recommendations must say that they are not automatically executed.

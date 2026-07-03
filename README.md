# Mac Optimizer Skill

Diagnosis-first macOS maintenance skill for safe local cleanup, health reports, and risk-ranked optimization recommendations.

Created and maintained by **Chuluu**.

[中文说明](README.zh-CN.md) · [Testing](TESTING.md) · [Skill entry](SKILL.md)

## What It Does

Mac Optimizer is a shareable Agent/Codex Skill plus a local macOS maintenance toolkit. It is built around a diagnosis-first workflow:

1. Generate a read-only diagnostic report.
2. Produce optional low, medium, and high risk recommendations.
3. Preview cleanup actions before execution.
4. Execute only confirmed low/medium risk maintenance.
5. Keep high risk actions as warnings and manual prompts.

It covers routine cache cleanup, old log cleanup, startup item inspection, developer-tool storage checks, DNS refresh, conservative UI preference tuning, rollback, and monthly maintenance orchestration.

## Quick Start

Run the read-only diagnostic report first:

```bash
bash ./01-检查脚本/full-check.sh
```

Preview the standard maintenance flow:

```bash
bash ./04-自动化脚本/one-click-optimization.sh --dry-run
```

Run confirmed maintenance:

```bash
bash ./04-自动化脚本/one-click-optimization.sh
```

Use conservative mode when you want to avoid system preference and admin-permission actions:

```bash
bash ./04-自动化脚本/one-click-optimization.sh --safe
```

## Skill Installation

Install into the default local Agent/Codex skills folder:

```bash
bash ./scripts/install.sh
```

Package a runtime ZIP for sharing:

```bash
python3 ./scripts/package_runtime_skill.py
```

The generated package is written to `dist/mac-optimizer-skill.zip`.

## Included Files

- `SKILL.md`: Agent-facing operating rules and workflow.
- `skill.json`: Machine-readable metadata for GitHub and skill registries.
- `01-检查脚本/full-check.sh`: Read-only macOS diagnostic report.
- `04-自动化脚本/one-click-optimization.sh`: Standard maintenance entrypoint.
- `04-自动化脚本/quick-optimization.sh`: Faster routine maintenance.
- `04-自动化脚本/rollback.sh`: Rollback for tool-managed preference changes.
- `05-维护计划/monthly.sh`: Monthly diagnosis plus maintenance orchestration.
- `references/`: Safety policy, risk model, report contract, and distribution notes.

## Safety Positioning

Mac Optimizer is not a blind cleaner. Optimization scripts refuse to run until diagnostic data exists. `--dry-run` previews actions without deleting files or changing settings. Time Machine snapshots, Docker volumes, simulator data, system-service changes, and power policy changes are treated as high risk and are not part of automatic quick or one-click flows.

iPhone optimization is intentionally separate. iOS does not allow the same local cleanup model as macOS, so this repository only includes iPhone guidance as a reference document.

## Recommended Prompts

```text
Use mac-optimizer to diagnose my Mac first, then tell me which suggestions are low, medium, or high risk.
```

```text
Use mac-optimizer in dry-run mode and do not execute cleanup until I confirm.
```

```text
Review this Mac Optimizer report and only recommend safe next steps.
```

## Testing

Run the full local validation suite:

```bash
bash tests/run.sh
```

The suite checks shell syntax, dry-run safety, diagnosis-first enforcement, high-risk exclusion from automatic flows, documentation freshness, and shareable Skill package metadata.

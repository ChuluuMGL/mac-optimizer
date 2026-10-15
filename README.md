# Mac Optimizer Skill

> **Diagnosis-first macOS maintenance Skill for AI Agents**  
> An open-source Agent Skill for safe local Mac diagnostics, opt-in network connectivity checks, storage cleanup previews, and risk-ranked recommendations.
>
> Created and maintained by **Chuluu**.

[中文说明](README.zh-CN.md) | English

[![AI Skill](https://img.shields.io/badge/AI%20Skill-mac--optimizer-0E5E43)](./SKILL.md)
[![Version](https://img.shields.io/badge/version-0.2.0-green)](./skill.json)
[![License: MIT](https://img.shields.io/badge/license-MIT-yellow)](./LICENSE)
[![by Chuluu](https://img.shields.io/badge/by-Chuluu-0E5E43)](https://github.com/ChuluuMGL)
[![Workflow](https://img.shields.io/badge/workflow-diagnosis--first-purple)](./SKILL.md)
[![Safety](https://img.shields.io/badge/safety-dry--run--first-blue)](./references/safety-policy.md)

[GitHub Repository](https://github.com/ChuluuMGL/mac-optimizer) | [Repository Metadata](./.github/repository-metadata.json) | [Workflow Fixtures](./examples/) | [Sample Report](./examples/basic-maintenance/sample-report.md) | [Review Checklist](./references/report-review-checklist.md) | [Release Guide](./references/release-guide.md) | [Changelog](./CHANGELOG.md) | [Testing Matrix](./TESTING.md) | [License](./LICENSE)

## About

Diagnosis-first macOS maintenance Agent Skill for safe diagnostics, dry-run cleanup previews, and risk-ranked recommendations.

## What It Does

Mac Optimizer is a shareable Agent/Codex Skill plus a local macOS maintenance toolkit. It is built around a diagnosis-first workflow:

1. Generate a read-only diagnostic report.
2. Produce optional low, medium, and high risk recommendations.
3. Preview cleanup actions before execution.
4. Execute only confirmed low/medium risk maintenance.
5. Keep high risk actions as warnings and manual prompts.

It covers routine cache cleanup, old log cleanup, startup item inspection, developer-tool storage checks, DNS refresh, conservative UI preference tuning, rollback, and monthly maintenance orchestration.

## Quick Start

```bash
git clone https://github.com/ChuluuMGL/mac-optimizer.git
cd mac-optimizer
scripts/install.sh codex
```

Run the read-only diagnostic report first:

```bash
bash ./01-检查脚本/full-check.sh
```

Network probes are opt-in because they contact external hosts. To add short DNS, gateway, direct HTTPS, and configured-proxy checks to the report, run:

```bash
bash ./01-检查脚本/full-check.sh --network
```

The network section hides local IPs, Wi-Fi names, and proxy addresses; it does not change settings or affect the disk health score.

Since 0.2.0 the report also sizes AI-agent and developer directories read-only (`~/.codex/{worktrees,sessions,artifacts}`, `node_modules` inside worktrees, `~/.pm2/logs`, `~/.cache`, `~/.npm`, `~/.gemini`, `~/.ollama`, Xcode DeviceSupport/DerivedData, CoreSimulator, top `~/Library/Caches`, `/private/tmp`) and classifies each as 安全可清 (safe to clear), 需确认 (needs confirmation), or 不要动 (do not touch: credentials, `auth.json`, memories, active sqlite, Hermes/OpenClaw configs). This is scan-only; nothing is deleted, and the results are also written to the `agent_dirs` field of `recommendations-latest.json`.

Preview the standard maintenance flow:

```bash
bash ./04-自动化脚本/one-click-optimization.sh --dry-run
```

Run confirmed maintenance:

```bash
bash ./04-自动化脚本/one-click-optimization.sh
```

Use conservative mode for cache-only maintenance. It also preserves Trash, Downloads, broad logs, and developer/app data:

```bash
bash ./04-自动化脚本/one-click-optimization.sh --safe
```

UI tuning and DNS refresh are separate opt-ins:

```bash
bash ./04-自动化脚本/one-click-optimization.sh --tune-ui
bash ./04-自动化脚本/one-click-optimization.sh --flush-dns
bash ./04-自动化脚本/one-click-optimization.sh --truncate-v2ray-log
```

## Skill Installation

The core skill follows the open Agent Skills shape: a folder with `SKILL.md`, plus optional `references/`, `scripts/`, and local tools. Most compatible agents only require the folder to be placed under their skills directory.

Installer script:

```bash
scripts/install.sh codex
scripts/install.sh claude
scripts/install.sh cursor
scripts/install.sh custom "$HOME/.config/agents/skills"
```

Package a runtime ZIP for sharing:

```bash
python3 ./scripts/package_runtime_skill.py
```

The generated package is written to `dist/mac-optimizer-skill.zip`.
A versioned archive is also generated, for example `dist/mac-optimizer-skill-0.2.0.zip`.

### Install And Compatibility

| Agent/runtime | Suggested install path | Status |
|---|---|---|
| Codex | `~/.codex/skills/mac-optimizer/` | Maintainer-tested |
| Claude Code | `./.claude/skills/mac-optimizer/` | Expected compatible |
| Cursor | `./.cursor/skills/mac-optimizer/` | Expected compatible |
| Trae | `./.trae/skills/mac-optimizer/` | Expected compatible |
| Antigravity | `./.agent/skills/mac-optimizer/` | Expected compatible |
| OpenClaw | Workspace or user skills root documented by OpenClaw | Expected compatible |
| Hermes | `~/.hermes/skills/mac-optimizer/` | Expected compatible |
| Gemini CLI | `./.gemini/skills/mac-optimizer/` | Expected compatible |
| Kimi Code CLI | `./.kimi/skills/mac-optimizer/` | Expected compatible |

Only Codex-specific UI metadata lives in `agents/openai.yaml`. Other agents can ignore that file and use `SKILL.md` directly.

### Ask An AI Agent

You can ask a coding agent:

> Install mac-optimizer from https://github.com/ChuluuMGL/mac-optimizer

## Included Files

- `SKILL.md`: Agent-facing operating rules and workflow.
- `skill.json`: Machine-readable metadata for GitHub and skill registries.
- `CHANGELOG.md`: Version history and release notes.
- `01-检查脚本/full-check.sh`: Read-only macOS diagnostic report.
- `lib/agent_dirs.sh`: Read-only sizing and three-tier classification of AI-agent and developer directories used by `full-check.sh`.
- `lib/network_diagnostics.sh`: Opt-in read-only network probe used by `full-check.sh --network`.
- `04-自动化脚本/one-click-optimization.sh`: Standard maintenance entrypoint.
- `04-自动化脚本/quick-optimization.sh`: Faster routine maintenance.
- `04-自动化脚本/rollback.sh`: Rollback for tool-managed preference changes.
- `05-维护计划/monthly.sh`: Monthly diagnosis plus maintenance orchestration.
- `03-优化方案/`: Advanced, interactive item-by-item scripts. `deep-storage-cleanup.sh`, `power-optimization.sh`, `ai-tools-cleanup.sh`, and `system-services-optimization.sh` support `--dry-run`, which lists the paths, sizes, and `pmset` settings they would change without changing anything. Without it, each destructive or setting-changing step asks for its own confirmation; `system-services-optimization.sh` defaults every step to No even with `--yes`. For example, the Android step permanently deletes all AVD emulator images. Project `__pycache__` cleanup runs only for directories listed in `MAC_OPT_PYCACHE_DIRS`.
- `examples/basic-maintenance/sample-report.md`: Sanitized sample diagnostic report.
- `references/`: Safety policy, risk model, report contract, report-review-checklist.md, release-guide.md, and distribution notes.

## Safety Positioning

Mac Optimizer is not a blind cleaner. Optimization scripts refuse to run until diagnostic data exists. `--dry-run` previews actions without deleting files or changing settings. Automatic flows clean only regenerable caches and old Crashpad reports; Trash, Downloads, broad logs, app containers, and developer data are report-only. Time Machine snapshots, Docker volumes, simulator data, system-service changes, and power policy changes remain high risk.

## License And Publishing

Mac Optimizer Skill is released under the [MIT License](./LICENSE).

- Copyright: `Copyright (c) 2026 Chuluu`
- Maintainer: [ChuluuMGL](https://github.com/ChuluuMGL)
- Repository: [https://github.com/ChuluuMGL/mac-optimizer](https://github.com/ChuluuMGL/mac-optimizer)
- Notice: [NOTICE](./NOTICE)

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

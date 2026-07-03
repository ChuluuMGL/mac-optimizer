---
name: mac-optimizer
description: Use when a user wants to diagnose or safely optimize macOS storage, caches, startup items, logs, developer-tool residue, or routine Mac maintenance with risk-aware recommendations.
---

# Mac Optimizer

Created and maintained by **Chuluu**.

## Overview

Mac Optimizer 是一个诊断报告优先的 macOS 维护 Skill。核心原则是：先只读诊断，再输出可选优化建议；低/中风险动作必须先预览，高风险动作只提示，不自动执行。

## When to Use

Use this skill when the user asks to:

- 检查 Mac 是否还有优化空间。
- 清理缓存、日志、下载目录旧文件、废纸篓或开发工具缓存。
- 生成 Mac 健康诊断报告。
- 按风险等级给出优化建议。
- 做日常或月度 Mac 维护。
- 判断某个优化动作是否安全。

## Operating Rules

| Rule | Required behavior |
|------|-------------------|
| 诊断报告优先 | Always run or request `bash ./01-检查脚本/full-check.sh` before cleanup. |
| 建议可选 | Treat recommendations as options, not commands. |
| Dry-run first | Use `--dry-run` before any cleanup unless the user explicitly confirms after seeing the plan. |
| 高风险只提示 | Never include high-risk actions in `quick` or `one-click` automatic flows. |
| 明确确认 | Ask before deleting files, changing settings, or running admin actions. |
| 保守默认 | Prefer `--safe` when the user wants minimal risk. |
| 隐私保护 | Do not expose private file contents, secrets, or personal paths beyond what is needed for the report summary. |

## Workflow

1. Clarify scope: routine check, storage pressure, slow startup, developer cache, or monthly maintenance.
2. Run diagnostics: `bash ./01-检查脚本/full-check.sh`.
3. Summarize the report: health score, free space, main pressure points, and low/medium/high risk suggestions.
4. Offer optional next steps. Keep high-risk items as manual warnings.
5. Preview safe maintenance: `bash ./04-自动化脚本/one-click-optimization.sh --dry-run`.
6. Execute only after confirmation. Use `--safe` for conservative mode.
7. Verify with `bash ./04-自动化脚本/verify.sh` or a fresh diagnostic report.

## Risk Model

| Risk | Examples | Automation policy |
|------|----------|-------------------|
| Low | Browser cache, old logs, package-manager caches, DNS refresh | Can be previewed and optionally executed. |
| Medium | Trash cleanup, old downloads, Dock/animation preference changes | Requires clear confirmation and rollback notes when relevant. |
| High | Time Machine snapshots, Docker volumes, simulator data, system services, power policy | Report and explain only; do not auto-run. |

See `references/risk-model.md`, `references/report-review-checklist.md`, and `references/safety-policy.md` before expanding cleanup behavior.

## Commands

```bash
bash ./01-检查脚本/full-check.sh
bash ./04-自动化脚本/one-click-optimization.sh --dry-run
bash ./04-自动化脚本/one-click-optimization.sh --safe
bash ./04-自动化脚本/quick-optimization.sh --dry-run
bash ./04-自动化脚本/rollback.sh
bash ./04-自动化脚本/verify.sh
bash ./05-维护计划/monthly.sh --dry-run
```

## Common Mistakes

| Mistake | Correction |
|---------|------------|
| Running cleanup before diagnostics | Stop and generate the diagnostic report first. |
| Treating all report suggestions as mandatory | Present them as optional recommendations. |
| Bundling high-risk cleanup into one-click mode | Keep it out of automatic flows. |
| Skipping dry-run because the action sounds safe | Preview first unless the user has already confirmed. |

## Final Handoff

When responding to the user, report:

- Where the diagnostic report was generated.
- The key low/medium/high risk findings.
- Which actions were previewed or executed.
- What was intentionally skipped as high risk.
- Any manual review items the user should decide on.

# Changelog

All notable changes to Mac Optimizer Skill are tracked here.

## Unreleased

- Preserve protected Agent-directory rows when size scans fail and avoid Top-N broken pipes.
- Display failed, timed-out, or incomplete Agent-directory sizes and worktree totals as unknown instead of 0K.
- Add strict-mode and complete-report regressions with isolated fixtures and mocked scan failures.
- Add `--dry-run` to `03-优化方案/deep-storage-cleanup.sh` (lists the paths and sizes it would delete; no `rm`, no `xcrun simctl`) and `03-优化方案/power-optimization.sh` (lists every `pmset`/`defaults` change; no `sudo`, no setting writes).
- Make the Android step in `deep-storage-cleanup.sh` state explicitly that it permanently deletes all AVD emulator images, and make the simulator step say it erases all device contents.
- Remove the author's personal `~/Documents/AI_Collection_Tool` and `~/Documents/Batch` folders from `ai-tools-cleanup.sh`; project `__pycache__` cleanup is now opt-in via `MAC_OPT_PYCACHE_DIRS` (colon-separated).
- Make advanced cleanup scripts resolve every path from `MAC_OPT_USER_HOME` instead of `~`, so running under `sudo` cannot target `/var/root`.
- Ollama `*.cache` removal in `ai-tools-cleanup.sh` now defaults to No; the EasyOCR prompt says it deletes all downloaded models.
- Reclassify `power-optimization.sh` as high risk to match the risk model.
- Rework `03-优化方案/system-services-optimization.sh`:
  - Add `--dry-run`, which lists every `defaults`, `launchctl`, `killall`, and `sudo tmutil` command without running any of them.
  - Every setting change and the Time Machine snapshot deletion now ask for their own confirmation and default to No. `--yes` does not auto-approve them, and `--safe` skips them.
  - The script previously disabled Dashboard without asking; that step now asks too.
  - Turning off automatic update checks is now a separate step and is labelled not recommended.
  - Snapshot deletion is labelled permanent.
  - The script is reclassified as high risk, refuses to run under `sudo` because user preferences would be written for root, and points to `rollback.sh` for restoring settings.
- Audit `one-click`, `quick`, and `monthly`: all three forward `--dry-run` and route every change through the shared preview helpers, and none of them call `03-优化方案/` scripts. Regression tests now cover this with every opt-in flag set.
- Add `tests/advanced_scripts.sh`: dry-run no-change checks against a synthetic `MAC_OPT_USER_HOME` with `sudo`/`pmset`/`xcrun`/`defaults` shims, plus a personal-path guard.

## 0.2.0 - 2026-10-10

- Added a read-only "AI Agent 与开发者目录" section to `full-check.sh` (new `lib/agent_dirs.sh`) that sizes `~/.codex/{worktrees,sessions,artifacts}`, `node_modules` under `~/.codex/worktrees`, `~/.pm2/logs`, `~/.cache` (uv/npm/model caches), `~/.npm/_cacache`, `~/.gemini`, `~/.ollama`, Xcode DeviceSupport/DerivedData, CoreSimulator devices/caches/runtimes, the largest `~/Library/Caches` entries, and `/private/tmp`.
- Classified every finding as 安全可清 (safe to clear), 需确认 (needs confirmation), or 不要动 (do not touch). Credentials, `auth.json`, memories, active sqlite/WAL files, and Hermes/OpenClaw configuration are listed by size only and are never suggested for deletion.
- Added an `agent_dirs` block (`safe_to_clean`, `needs_confirmation`, `do_not_touch`) to `recommendations-latest.json` and three new rows to the risk-ranked recommendation table.
- Scan only: no new cleanup actions were added. Existing destructive options remain behind their explicit flags and `--safe` stays cache-only.
- Added `MAC_OPT_TMP_DIR` and `MAC_OPT_SYSTEM_LIB` overrides for tests, a fixture-based read-only/classification test, and bumped the runtime script suite to 1.5.0.

## 0.1.8 - 2026-10-01

- Added opt-in `full-check.sh --network` diagnostics for the default route, gateway packet loss/latency, macOS DNS resolution, direct HTTPS, and configured proxy connectivity.
- Kept network probes disabled by default, redacted local/proxy addresses, and excluded network status from the disk health score.
- Added deterministic mock-based network tests and bumped the runtime script suite to 1.4.2.

## 0.1.7 - 2026-09-11

- Moved Homebrew cache removal after `brew cleanup` so API and bootsnap caches recreated by Homebrew do not remain after a safe run.
- Added a regression test that verifies Homebrew-created cache files are removed without widening the safe-cleanup boundary.
- Updated the runtime script suite version to 1.4.1.

## 0.1.6 - 2026-09-10

- Made `--safe` cache-only: Trash, Downloads, broad logs, UI settings, DNS, app containers, and developer data are preserved.
- Changed automatic Downloads, Trash, and broad-log cleanup into report-only findings.
- Added seven-day Codex Crashpad cleanup plus before/after reclaimed-space reporting.
- Added targeted storage-pressure reporting for WeChat documents, Xcode DeviceSupport, DerivedData, simulators, and Crashpad.
- Replaced the destructive monthly script with diagnosis, safe maintenance, and verification orchestration.
- Tightened health scoring for disks at or above 90% usage.
- Made deep cleanup report-only for Downloads, project logs, Docker resources, and Time Machine snapshots.
- Preserved n8n, ZAI, and Trae logs in the AI-tools cleanup flow and corrected its risk label.
- Updated the runtime script suite version to 1.4.0.
- Required explicit `--truncate-v2ray-log` opt-in before truncating the named v2ray log.

## 0.1.5 - 2026-07-08

- Hardened `full-check.sh`: rewrote the report as incremental sections so a single slow command can no longer blank the whole report.
- Added `scan()` timeout wrapper, `list_large_files()` (Spotlight-first with find fallback), and APFS-aware physical/logical size + sparse-file detection in `lib/common.sh`.
- Switched the three unbounded `find` calls to `-prune` + `-xdev` so scans no longer descend into `~/Library` and hang developer machines.
- Large files now report physical vs logical size with a `SPARSE` flag, avoiding inflated "reclaimable space" advice on sparse/clone files.
- Redacted `$HOME` paths in the report by default (new `--full-paths` switch) and split `~/Library` usage into per-subdirectory scans.
- Replaced per-file `-exec ... \;` with batched `-exec ... +` in cleanup scripts, and ignored `.DS_Store`.

## 0.1.4 - 2026-07-03

- Added a release-readiness checker for version consistency and required publishing assets.
- Added a tag-based GitHub Release workflow that packages runtime ZIP artifacts.
- Updated runtime packaging to produce both stable and versioned archive names.
- Added a release guide for `v0.1.4` tagging and upload flow.

## 0.1.3 - 2026-07-03

- Added a sanitized sample diagnostic report for public review.
- Added a report review checklist to make low, medium, and high risk handoff decisions clearer.
- Linked changelog, sample report, and review checklist from the README files and `skill.json`.
- Expanded tests so release notes, sample outputs, and review references stay wired into the package.

## 0.1.2 - 2026-07-03

- Narrowed the project scope to Mac-only maintenance documentation.
- Removed unrelated device guidance from docs, metadata, verification, and runtime packaging.
- Added a test guard to keep publishing files focused on Mac Optimizer scope.

## 0.1.1 - 2026-07-03

- Polished publishing metadata to match Chuluu-style Skill repositories.
- Added visible version, license, maintainer, workflow, and safety badges.
- Expanded `NOTICE`, `skill.json`, and installer metadata.
- Added multi-agent installation targets.

## 0.1.0 - 2026-07-03

- Packaged Mac Optimizer as a shareable Agent Skill.
- Added `SKILL.md`, `skill.json`, English and Chinese README files, installer, runtime packaging, and GitHub validation.
- Enforced diagnosis-first behavior, dry-run previews, and risk-ranked recommendations.

# Changelog

All notable changes to Mac Optimizer Skill are tracked here.

## Unreleased

No unreleased changes.

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

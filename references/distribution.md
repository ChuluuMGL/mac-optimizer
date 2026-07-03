# Distribution

This repository is intended to be shareable as a GitHub-maintained Skill.

## Repository Shape

- `SKILL.md` is the agent-facing entrypoint.
- `skill.json` is the machine-readable metadata file.
- `README.md` is the English GitHub landing page.
- `README.zh-CN.md` is the Chinese user guide.
- `references/` stores safety and operating contracts.
- `scripts/install.sh` installs the Skill locally.
- `scripts/package_runtime_skill.py` creates the shareable ZIP package.
- `.github/workflows/validate.yml` runs repository validation.

## Local Install

```bash
scripts/install.sh codex
scripts/install.sh claude
scripts/install.sh cursor
scripts/install.sh custom "$HOME/.config/agents/skills"
```

Common targets:

| Target | Path |
|---|---|
| `codex` | `~/.codex/skills/mac-optimizer` |
| `claude` | `./.claude/skills/mac-optimizer` |
| `cursor` | `./.cursor/skills/mac-optimizer` |
| `trae` | `./.trae/skills/mac-optimizer` |
| `antigravity` | `./.agent/skills/mac-optimizer` |
| `gemini` | `./.gemini/skills/mac-optimizer` |
| `kimi` | `./.kimi/skills/mac-optimizer` |
| `hermes` | `~/.hermes/skills/mac-optimizer` |
| `agents` | `./.agents/skills/mac-optimizer` |
| `custom PATH` | `PATH/mac-optimizer` |

For an exact installation path, use `scripts/install.sh --target /path/to/mac-optimizer`.

## Runtime Package

```bash
python3 scripts/package_runtime_skill.py
```

The package is written to:

```text
dist/mac-optimizer-skill.zip
```

## Source Of Truth

GitHub is the source of truth:

```text
https://github.com/ChuluuMGL/mac-optimizer
```

Release metadata should stay synchronized across `README.md`, `README.zh-CN.md`, `NOTICE`, `skill.json`, and `package.json`.

## GitHub About

The repository sidebar metadata is documented in `.github/repository-metadata.json`.

Current public description:

```text
Diagnosis-first macOS maintenance Agent Skill for safe diagnostics, dry-run cleanup previews, and risk-ranked recommendations.
```

Recommended topics:

```text
agent-skills, cleanup, diagnosis-first, dry-run, mac, macos, optimizer, skill, system-maintenance
```

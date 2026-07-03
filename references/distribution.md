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
bash scripts/install.sh
```

The default target is:

```text
~/.agents/skills/mac-optimizer
```

Set a custom target with:

```bash
bash scripts/install.sh --target /path/to/skills/mac-optimizer
```

## Runtime Package

```bash
python3 scripts/package_runtime_skill.py
```

The package is written to:

```text
dist/mac-optimizer-skill.zip
```

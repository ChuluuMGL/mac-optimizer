# Testing

Run the full local validation suite:

```bash
bash tests/run.sh
```

The suite validates:

- Required Skill package files exist.
- `skill.json` and `package.json` are valid JSON.
- `SKILL.md` includes trigger metadata, diagnosis-first rules, and high-risk warnings.
- Shell scripts avoid old hard-coded install paths.
- `quick` and `one-click` expose `--dry-run` and `--yes`.
- Optimization scripts refuse to run before a diagnostic report exists.
- Dry-run mode leaves user files untouched.
- Diagnostic reports include optional low, medium, and high risk recommendations.
- High-risk cleanup commands are not present in automatic quick or one-click flows.
- Documentation references current script names.
- Shell syntax is valid on system bash.
- The verification script runs without making cleanup changes.

## Smoke Test

Use an isolated temporary home when checking behavior on a development machine:

```bash
bash tests/run.sh
```

Then package the runtime Skill:

```bash
python3 scripts/package_runtime_skill.py
```

The package should be created at:

```text
dist/mac-optimizer-skill.zip
```

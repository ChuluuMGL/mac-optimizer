# Release Guide

Use this guide when preparing a public release such as `v0.1.4`.

## Preflight

```bash
python3 scripts/check_release_ready.py
bash tests/run.sh
python3 scripts/package_runtime_skill.py
```

Expected package outputs:

```text
dist/mac-optimizer-skill.zip
dist/mac-optimizer-skill-0.1.4.zip
```

## Tag And Publish

After the working tree is clean and `main` is pushed:

```bash
git tag v0.1.4
git push origin v0.1.4
```

The `Release` GitHub Action validates metadata, runs the test suite, builds the runtime ZIP files, and creates a GitHub Release with both stable and versioned package names.

## Version Checklist

- `skill.json`
- `package.json`
- `agents/openai.yaml`
- README badges
- `README.zh-CN.md` badges
- `CHANGELOG.md`
- This release guide

All of these are checked by `scripts/check_release_ready.py`.

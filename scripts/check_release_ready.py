#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


REQUIRED_FILES = [
    "SKILL.md",
    "skill.json",
    "package.json",
    "README.md",
    "README.zh-CN.md",
    "CHANGELOG.md",
    "LICENSE",
    "NOTICE",
    "TESTING.md",
    "agents/openai.yaml",
    "examples/basic-maintenance/sample-report.md",
    "references/report-review-checklist.md",
    "references/release-guide.md",
    "scripts/package_runtime_skill.py",
    "scripts/install.sh",
    ".github/workflows/validate.yml",
    ".github/workflows/release.yml",
]


def read_text(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def read_json(path: str) -> dict:
    return json.loads(read_text(path))


def fail(message: str) -> None:
    print(f"FAIL: {message}", file=sys.stderr)
    raise SystemExit(1)


def require(condition: bool, message: str) -> None:
    if not condition:
        fail(message)


def yaml_version(text: str) -> str | None:
    match = re.search(r"^version:\s*([0-9]+\.[0-9]+\.[0-9]+)\s*$", text, re.MULTILINE)
    return match.group(1) if match else None


def main() -> None:
    parser = argparse.ArgumentParser(description="Validate Mac Optimizer release metadata.")
    parser.add_argument("--tag", help="Optional tag to validate, for example v0.1.4")
    args = parser.parse_args()

    missing = [path for path in REQUIRED_FILES if not (ROOT / path).is_file()]
    require(not missing, f"missing required files: {', '.join(missing)}")

    skill = read_json("skill.json")
    package = read_json("package.json")
    version = skill.get("version")
    require(bool(re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+", str(version))), "skill.json version must be semver")
    require(package.get("version") == version, "package.json version must match skill.json")
    require(yaml_version(read_text("agents/openai.yaml")) == version, "agents/openai.yaml version must match skill.json")

    if args.tag:
        require(args.tag == f"v{version}", f"tag {args.tag} must match v{version}")

    readme = read_text("README.md")
    readme_zh = read_text("README.zh-CN.md")
    changelog = read_text("CHANGELOG.md")
    release_guide = read_text("references/release-guide.md")

    require(f"version-{version}" in readme, "README badge version is stale")
    require(f"version-{version}" in readme_zh, "README.zh-CN badge version is stale")
    require(f"## {version} " in changelog or f"## {version} -" in changelog, "CHANGELOG missing current version section")
    require(f"v{version}" in release_guide, "release guide missing current tag")
    require(skill.get("changelog") == "CHANGELOG.md", "skill.json changelog pointer missing")
    require(skill.get("sample_report") == "examples/basic-maintenance/sample-report.md", "skill.json sample report pointer missing")
    require(
        skill.get("workflow_references", {}).get("release_guide") == "references/release-guide.md",
        "skill.json release guide pointer missing",
    )

    print(f"Release ready: v{version}")


if __name__ == "__main__":
    main()

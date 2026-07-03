#!/usr/bin/env python3
from __future__ import annotations

import os
import json
import zipfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DIST_DIR = ROOT / "dist"
PACKAGE = DIST_DIR / "mac-optimizer-skill.zip"

INCLUDE_PATHS = [
    "SKILL.md",
    "skill.json",
    "README.md",
    "README.zh-CN.md",
    "CHANGELOG.md",
    "LICENSE",
    "NOTICE",
    "TESTING.md",
    "agents",
    "references",
    "examples",
    "scripts",
    "tests",
    "lib",
    "00-系统概览",
    "01-检查脚本",
    "03-优化方案",
    "04-自动化脚本",
    "05-维护计划",
    "INSTALL.md",
    "Mac优化系统-快速开始.md",
    "Obsidian-Integration-Guide.md",
    "Index.md",
]

EXCLUDED_DIRS = {
    ".git",
    ".github",
    "data",
    "dist",
    "logs",
    "__pycache__",
}


def should_include(path: Path) -> bool:
    rel_parts = path.relative_to(ROOT).parts
    return not any(part in EXCLUDED_DIRS for part in rel_parts)


def add_path(zf: zipfile.ZipFile, path: Path) -> None:
    if not path.exists():
      return

    if path.is_file():
        if should_include(path):
            zf.write(path, path.relative_to(ROOT).as_posix())
        return

    for dirpath, dirnames, filenames in os.walk(path):
        current = Path(dirpath)
        dirnames[:] = [name for name in dirnames if name not in EXCLUDED_DIRS]
        for filename in filenames:
            file_path = current / filename
            if should_include(file_path):
                zf.write(file_path, file_path.relative_to(ROOT).as_posix())


def skill_version() -> str:
    with (ROOT / "skill.json").open(encoding="utf-8") as fh:
        return json.load(fh)["version"]


def create_package(package: Path) -> None:
    with zipfile.ZipFile(package, "w", compression=zipfile.ZIP_DEFLATED) as zf:
        for item in INCLUDE_PATHS:
            add_path(zf, ROOT / item)


def main() -> None:
    DIST_DIR.mkdir(exist_ok=True)
    versioned_package = DIST_DIR / f"mac-optimizer-skill-{skill_version()}.zip"
    create_package(PACKAGE)
    create_package(versioned_package)
    print(f"Created {PACKAGE}")
    print(f"Created {versioned_package}")


if __name__ == "__main__":
    main()

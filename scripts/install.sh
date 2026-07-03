#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET_DIR="${HOME}/.agents/skills/mac-optimizer"

usage() {
  cat <<'USAGE'
Usage: bash scripts/install.sh [--target PATH]

Installs Mac Optimizer into a local Agent/Codex skill directory.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target)
      TARGET_DIR="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'Unknown option: %s\n' "$1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ -z "$TARGET_DIR" ]]; then
  printf 'Target path cannot be empty.\n' >&2
  exit 1
fi

mkdir -p "$TARGET_DIR"

rsync -a --delete \
  --exclude '.git/' \
  --exclude '.github/' \
  --exclude 'dist/' \
  --exclude 'logs/' \
  --exclude 'data/' \
  "$ROOT_DIR/" "$TARGET_DIR/"

printf 'Installed mac-optimizer skill to %s\n' "$TARGET_DIR"

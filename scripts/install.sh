#!/usr/bin/env bash
set -euo pipefail

SKILL_NAME="mac-optimizer"
REPO_URL="${MAC_OPTIMIZER_SKILL_REPO:-https://github.com/ChuluuMGL/mac-optimizer.git}"

usage() {
  cat <<'EOF'
Install mac-optimizer into a local agent skills directory.

Usage:
  scripts/install.sh <target>
  scripts/install.sh custom <skills-root>
  scripts/install.sh --target <exact-skill-path>

Targets:
  codex        ~/.codex/skills/mac-optimizer
  claude       ./.claude/skills/mac-optimizer
  cursor       ./.cursor/skills/mac-optimizer
  trae         ./.trae/skills/mac-optimizer
  antigravity  ./.agent/skills/mac-optimizer
  gemini       ./.gemini/skills/mac-optimizer
  kimi         ./.kimi/skills/mac-optimizer
  hermes       ~/.hermes/skills/mac-optimizer
  agents       ./.agents/skills/mac-optimizer
  custom PATH  PATH/mac-optimizer
  --target PATH
               Install directly to PATH

Examples:
  scripts/install.sh codex
  scripts/install.sh claude
  scripts/install.sh custom "$HOME/.config/agents/skills"
EOF
}

target="${1:-}"
exact_dest=""

if [[ -z "$target" || "$target" == "-h" || "$target" == "--help" ]]; then
  usage
  exit 0
fi

case "$target" in
  codex) root="${CODEX_HOME:-$HOME/.codex}/skills" ;;
  claude) root="$PWD/.claude/skills" ;;
  cursor) root="$PWD/.cursor/skills" ;;
  trae) root="$PWD/.trae/skills" ;;
  antigravity) root="$PWD/.agent/skills" ;;
  gemini) root="$PWD/.gemini/skills" ;;
  kimi) root="$PWD/.kimi/skills" ;;
  hermes) root="$HOME/.hermes/skills" ;;
  agents) root="$PWD/.agents/skills" ;;
  custom)
    root="${2:-}"
    if [[ -z "$root" ]]; then
      echo "custom target requires a skills root path" >&2
      exit 2
    fi
    ;;
  --target)
    exact_dest="${2:-}"
    if [[ -z "$exact_dest" ]]; then
      echo "--target requires an exact skill path" >&2
      exit 2
    fi
    root="$(dirname "$exact_dest")"
    ;;
  *)
    echo "unknown target: $target" >&2
    usage >&2
    exit 2
    ;;
esac

dest="${exact_dest:-$root/$SKILL_NAME}"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source_root="$(cd "$script_dir/.." && pwd)"

mkdir -p "$root"

if [[ "$source_root" == "$dest" ]]; then
  echo "Already installed at $dest"
  exit 0
fi

if [[ -f "$source_root/SKILL.md" && -f "$source_root/skill.json" ]]; then
  mkdir -p "$dest"
  if command -v rsync >/dev/null 2>&1; then
    rsync -a \
      --delete \
      --exclude ".git" \
      --exclude ".github" \
      --exclude ".DS_Store" \
      --exclude "__pycache__" \
      --exclude "*.pyc" \
      --exclude "data" \
      --exclude "dist" \
      --exclude "logs" \
      "$source_root/" "$dest/"
  else
    (cd "$source_root" && tar \
      --exclude ".git" \
      --exclude ".github" \
      --exclude ".DS_Store" \
      --exclude "__pycache__" \
      --exclude "*.pyc" \
      --exclude "data" \
      --exclude "dist" \
      --exclude "logs" \
      -cf - .) | (cd "$dest" && tar -xf -)
  fi
else
  if [[ -e "$dest" ]]; then
    echo "destination already exists: $dest" >&2
    echo "remove it first or run this script from a local checkout to update in place" >&2
    exit 1
  fi
  git clone "$REPO_URL" "$dest"
fi

echo "Installed $SKILL_NAME to $dest"

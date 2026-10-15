#!/usr/bin/env bash
# Regressions for 03-优化方案 advanced scripts. Every run uses a synthetic
# MAC_OPT_USER_HOME under a temp dir and PATH shims for macOS/admin commands
# (sudo, pmset, defaults, xcrun, tmutil, pip, conda), so nothing real is touched.
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
failures=0
fail() { printf 'FAIL: %s\n' "$1"; failures=$((failures + 1)); }
pass() { printf 'PASS: %s\n' "$1"; }

DEEP="03-优化方案/deep-storage-cleanup.sh"
POWER="03-优化方案/power-optimization.sh"
AI="03-优化方案/ai-tools-cleanup.sh"

# --- PATH shims: record every call; never escalate or change settings. ---
bin="$tmp/bin"
calls="$tmp/calls.log"
mkdir -p "$bin"
: > "$calls"
for cmd in sudo defaults xcrun tmutil pip conda ollama docker; do
  cat > "$bin/$cmd" <<EOF
#!/bin/sh
printf '%s %s\n' "$cmd" "\$*" >> "$calls"
exit 0
EOF
done
cat > "$bin/pmset" <<EOF
#!/bin/sh
printf 'pmset %s\n' "\$*" >> "$calls"
if [ "\$1" = "-g" ]; then
  printf ' hibernatemode 3\n sleep 1\n displaysleep 10\n disksleep 10\n'
fi
exit 0
EOF
cat > "$bin/system_profiler" <<EOF
#!/bin/sh
if [ -n "\${MOCK_BATTERY:-}" ]; then
  printf 'Battery Information:\n  Cycle Count: 42\n  Condition: Normal\n'
fi
exit 0
EOF
chmod +x "$bin"/*
SHIM_PATH="$bin:/usr/bin:/bin"

make_home() {
  local h="$1"
  mkdir -p "$h/Library/Developer/Xcode/DerivedData/Proj-abc" \
    "$h/Library/Developer/CoreSimulator/Devices/UDID" \
    "$h/.android/avd/Pixel.avd" \
    "$h/Library/Caches/Google" \
    "$h/Downloads" "$h/Documents/proj/logs" \
    "$h/.cursor/Cache" "$h/.gemini/Cache" "$h/.EasyOCR/model" \
    "$h/.ollama/models" "$h/.zai/cache" "$h/.trae/cache"
  printf 'x\n' > "$h/Library/Developer/Xcode/DerivedData/Proj-abc/build.o"
  printf 'x\n' > "$h/Library/Developer/CoreSimulator/Devices/UDID/data"
  printf 'x\n' > "$h/.android/avd/Pixel.avd/userdata.img"
  # >10MB so the app-cache section offers it for cleanup.
  dd if=/dev/zero of="$h/Library/Caches/Google/blob" bs=1048576 count=11 2>/dev/null
  printf 'x\n' > "$h/Downloads/old.txt"
  touch -t 202001010000 "$h/Downloads/old.txt"
  printf 'x\n' > "$h/.cursor/Cache/c"
  printf 'x\n' > "$h/.gemini/Cache/c"
  printf 'x\n' > "$h/.EasyOCR/model/m.pth"
  printf 'x\n' > "$h/.ollama/models/blob"
  printf 'x\n' > "$h/.ollama/x.cache"
  printf 'x\n' > "$h/.zai/cache/c"
  printf 'x\n' > "$h/.trae/cache/c"
}

snapshot() { (cd "$1" && find . -print | LC_ALL=C sort); }

run_script() {
  local h="$1"; shift
  HOME="$tmp/realhome" MAC_OPT_USER_HOME="$h" \
    MAC_OPT_LOG_DIR="$tmp/logs" MAC_OPT_DATA_DIR="$tmp/data" \
    MAC_OPT_NO_CLEAR=1 PATH="$SHIM_PATH" "$@"
}

mkdir -p "$tmp/realhome" "$tmp/logs" "$tmp/data"
printf 'sentinel\n' > "$tmp/realhome/sentinel"
mkdir -p "$tmp/realhome/.cursor/Cache" && printf 'x\n' > "$tmp/realhome/.cursor/Cache/keep"

# 1. Help exposes --dry-run for the advanced scripts.
for s in "$DEEP" "$POWER" "$AI"; do
  if [[ "$(bash "$s" --help 2>&1)" == *"--dry-run"* ]]; then
    pass "$s --help documents --dry-run"
  else
    fail "$s --help must document --dry-run"
  fi
done

# 2. deep-storage --dry-run: reports paths/sizes, deletes nothing, no simctl.
h="$tmp/deep-dry"
make_home "$h"
before="$(snapshot "$h")"
: > "$calls"
out="$(run_script "$h" bash "$DEEP" --dry-run </dev/null 2>&1)" || { printf '%s\n' "$out"; fail "deep-storage --dry-run exits 0"; }
after="$(snapshot "$h")"
if [[ "$before" == "$after" ]] \
  && ! grep -qE '^(xcrun|sudo)' "$calls" \
  && [[ "$out" == *"[预览]"*"DerivedData"* ]] \
  && [[ "$out" == *"永久删除"*"AVD"* ]] \
  && [[ "$out" == *"Library/Caches/Google"* ]] \
  && [[ "$out" == *"未删除任何文件"* ]]; then
  pass "deep-storage --dry-run previews paths and changes nothing"
else
  printf '%s\n' "$out"; cat "$calls"
  fail "deep-storage --dry-run must preview and make zero changes"
fi

# 3. deep-storage confirmed run deletes only under MAC_OPT_USER_HOME, never $HOME.
h="$tmp/deep-run"
make_home "$h"
: > "$calls"
run_script "$h" bash "$DEEP" >"$tmp/deep-run.out" 2>&1 <<<'yyyy' || true
if [[ -z "$(find "$h/Library/Developer/Xcode/DerivedData" -mindepth 1 -print -quit)" \
  && -z "$(find "$h/.android/avd" -mindepth 1 -print -quit)" \
  && ! -e "$h/Library/Caches/Google/blob" \
  && -f "$h/Downloads/old.txt" \
  && -f "$tmp/realhome/sentinel" ]] \
  && grep -q '^xcrun simctl erase all' "$calls"; then
  pass "deep-storage confirmed run targets MAC_OPT_USER_HOME and keeps Downloads"
else
  cat "$tmp/deep-run.out"
  fail "deep-storage confirmed run must target MAC_OPT_USER_HOME only"
fi

# 4. power-optimization --dry-run (desktop and laptop): no sudo, no pmset writes.
for battery in "" 1; do
  : > "$calls"
  out="$(MOCK_BATTERY="$battery" run_script "$tmp/realhome" bash "$POWER" --dry-run </dev/null 2>&1)" || { printf '%s\n' "$out"; fail "power --dry-run exits 0 (battery=${battery:-0})"; continue; }
  if ! grep -vE '^pmset -g' "$calls" | grep -q . \
    && [[ "$out" == *"[预览] 将执行: sudo pmset"* ]] \
    && [[ "$out" == *"未修改任何电源设置"* ]]; then
    pass "power-optimization --dry-run lists pmset changes without writing (battery=${battery:-0})"
  else
    printf '%s\n' "$out"; cat "$calls"
    fail "power-optimization --dry-run must not call sudo/pmset writes/defaults (battery=${battery:-0})"
  fi
done

# 5. ai-tools --dry-run: nothing deleted, opt-in pycache dirs are only previewed.
h="$tmp/ai-dry"
make_home "$h"
mkdir -p "$h/Projects/app/__pycache__" && printf 'x\n' > "$h/Projects/app/__pycache__/m.pyc"
before="$(snapshot "$h")"
: > "$calls"
out="$(MAC_OPT_PYCACHE_DIRS="$h/Projects" run_script "$h" bash "$AI" --dry-run </dev/null 2>&1)" || { printf '%s\n' "$out"; fail "ai-tools --dry-run exits 0"; }
after="$(snapshot "$h")"
if [[ "$before" == "$after" ]] && ! grep -qE '^(pip|conda|sudo)' "$calls" \
  && [[ "$out" == *"__pycache__"* ]]; then
  pass "ai-tools --dry-run changes nothing"
else
  printf '%s\n' "$out"; cat "$calls"
  fail "ai-tools --dry-run must make zero changes"
fi

# 6. ai-tools confirmed run uses MAC_OPT_USER_HOME, keeps models by default,
#    and cleans __pycache__ only in explicitly listed directories.
h="$tmp/ai-run"
make_home "$h"
mkdir -p "$h/Projects/app/__pycache__" "$h/Other/__pycache__"
printf 'x\n' > "$h/Projects/app/__pycache__/m.pyc"
printf 'x\n' > "$h/Other/__pycache__/m.pyc"
MAC_OPT_PYCACHE_DIRS="$h/Projects" run_script "$h" bash "$AI" --yes \
  >"$tmp/ai-run.out" 2>&1 <<<'nn' || true
if [[ ! -e "$h/.cursor/Cache" && ! -e "$h/.gemini/Cache" \
  && -f "$h/.ollama/x.cache" && -f "$h/.ollama/models/blob" \
  && -f "$h/.EasyOCR/model/m.pth" \
  && ! -e "$h/Projects/app/__pycache__" && -f "$h/Other/__pycache__/m.pyc" \
  && -f "$tmp/realhome/.cursor/Cache/keep" ]]; then
  pass "ai-tools targets MAC_OPT_USER_HOME and only opt-in pycache dirs"
else
  cat "$tmp/ai-run.out"
  fail "ai-tools must delete only under MAC_OPT_USER_HOME and opt-in pycache dirs"
fi

# 7. No author-specific personal paths remain in shell scripts.
if grep -rnE 'AI_Collection_Tool|Documents/Batch' --include='*.sh' 01-检查脚本 03-优化方案 04-自动化脚本 05-维护计划 lib scripts; then
  fail "shell scripts must not hard-code personal project folders"
else
  pass "shell scripts contain no personal project folders"
fi

# 8. Advanced cleanup scripts delete via MAC_OPT_USER_HOME, never a bare ~.
if grep -nE '(^|[[:space:]=(])~/' "$DEEP" "$AI" | grep -vE '^\S+:[0-9]+:\s*#|echo|info|log|warn'; then
  fail "advanced cleanup scripts must use MAC_OPT_USER_HOME instead of ~"
else
  pass "advanced cleanup scripts avoid bare ~ paths"
fi

[[ "$failures" -eq 0 ]]

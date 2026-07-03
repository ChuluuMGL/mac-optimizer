#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

failures=0

fail() {
  printf 'FAIL: %s\n' "$1"
  failures=$((failures + 1))
}

pass() {
  printf 'PASS: %s\n' "$1"
}

has_pattern() {
  local pattern="$1"
  shift

  if command -v rg >/dev/null 2>&1; then
    rg -q "$pattern" "$@"
  else
    grep -Eq "$pattern" "$@"
  fi
}

list_pattern() {
  local pattern="$1"
  shift

  if command -v rg >/dev/null 2>&1; then
    rg -n "$pattern" "$@"
  else
    grep -En "$pattern" "$@"
  fi
}

list_shell_pattern() {
  local pattern="$1"

  if command -v rg >/dev/null 2>&1; then
    rg -n "$pattern" --glob '*.sh' --glob '!tests/**' .
  else
    find . -name '*.sh' -not -path './tests/*' -print0 | xargs -0 grep -En "$pattern"
  fi
}

list_markdown_pattern() {
  local pattern="$1"

  if command -v rg >/dev/null 2>&1; then
    rg -n "$pattern" --glob '*.md' .
  else
    find . -name '*.md' -print0 | xargs -0 grep -En "$pattern"
  fi
}

assert_file() {
  local path="$1"
  if [[ -f "$path" ]]; then
    pass "file exists: $path"
  else
    fail "missing file: $path"
  fi
}

assert_no_script_hardcoded_install_path() {
  if list_shell_pattern 'Mac-Optimization-System' >/tmp/mac-opt-hardcoded-paths.$$ 2>/dev/null; then
    cat /tmp/mac-opt-hardcoded-paths.$$
    rm -f /tmp/mac-opt-hardcoded-paths.$$
    fail "shell scripts must not hard-code ~/Mac-Optimization-System"
  else
    rm -f /tmp/mac-opt-hardcoded-paths.$$
    pass "shell scripts avoid hard-coded install path"
  fi
}

assert_common_options_present() {
  local script="$1"
  if ! has_pattern 'parse_common_args' "$script"; then
    fail "$script must use common option parsing"
    return
  fi

  local help_output
  help_output="$(bash "$script" --help 2>&1)"
  if [[ "$help_output" == *"--dry-run"* && "$help_output" == *"--yes"* ]]; then
    pass "$script exposes dry-run and yes modes"
  else
    fail "$script --help must mention --dry-run and --yes"
  fi
}

assert_safe_dry_run_execution() {
  local script="$1"
  if ! has_pattern 'parse_common_args' "$script"; then
    fail "$script cannot be dry-run tested yet"
    return
  fi

  local tmp
  tmp="$(mktemp -d)"
  mkdir -p "$tmp/home/Library/Caches/Google/Chrome/Default/Cache"
  mkdir -p "$tmp/home/Library/Logs"
  mkdir -p "$tmp/home/Downloads"
  mkdir -p "$tmp/home/.Trash"
  printf 'cache\n' > "$tmp/home/Library/Caches/Google/Chrome/Default/Cache/keep.txt"
  mkdir -p "$tmp/home/Library/Caches/Google/Chrome/Default/Cache/unreadable"
  printf 'log\n' > "$tmp/home/Library/Logs/old.log"
  printf 'download\n' > "$tmp/home/Downloads/old-download.txt"
  printf 'trash\n' > "$tmp/home/.Trash/keep.txt"
  touch -t 202001010000 "$tmp/home/Library/Logs/old.log" "$tmp/home/Downloads/old-download.txt"
  chmod 000 "$tmp/home/Library/Caches/Google/Chrome/Default/Cache/unreadable"
  mkdir -p "$tmp/logs" "$tmp/data"
  printf '{"date":"test","score":90}\n' > "$tmp/data/check-latest.json"

  HOME="$tmp/home" MAC_OPT_LOG_DIR="$tmp/logs" MAC_OPT_DATA_DIR="$tmp/data" MAC_OPT_NO_CLEAR=1 bash "$script" --dry-run --yes >/tmp/mac-opt-dry-run.$$ 2>&1 || {
    cat /tmp/mac-opt-dry-run.$$
    chmod 700 "$tmp/home/Library/Caches/Google/Chrome/Default/Cache/unreadable" 2>/dev/null || true
    rm -rf "$tmp" /tmp/mac-opt-dry-run.$$
    fail "$script --dry-run exits successfully"
    return
  }

  chmod 700 "$tmp/home/Library/Caches/Google/Chrome/Default/Cache/unreadable" 2>/dev/null || true
  if [[ -f "$tmp/home/Library/Caches/Google/Chrome/Default/Cache/keep.txt" \
    && -f "$tmp/home/Library/Logs/old.log" \
    && -f "$tmp/home/Downloads/old-download.txt" \
    && -f "$tmp/home/.Trash/keep.txt" ]]; then
    pass "$script dry-run leaves user files untouched"
  else
    cat /tmp/mac-opt-dry-run.$$
    fail "$script dry-run deleted files"
  fi

  rm -rf "$tmp" /tmp/mac-opt-dry-run.$$
}

assert_optimizer_requires_diagnostic() {
  local script="$1"
  local tmp
  tmp="$(mktemp -d)"
  mkdir -p "$tmp/home/Library/Caches" "$tmp/home/Library/Logs" "$tmp/logs" "$tmp/data"

  if HOME="$tmp/home" MAC_OPT_LOG_DIR="$tmp/logs" MAC_OPT_DATA_DIR="$tmp/data" MAC_OPT_NO_CLEAR=1 bash "$script" --dry-run --yes >/tmp/mac-opt-no-diagnostic.$$ 2>&1; then
    cat /tmp/mac-opt-no-diagnostic.$$
    rm -rf "$tmp" /tmp/mac-opt-no-diagnostic.$$
    fail "$script must require a diagnostic report before optimization"
    return
  fi

  if has_pattern '请先运行诊断' /tmp/mac-opt-no-diagnostic.$$; then
    pass "$script requires diagnostic report first"
  else
    cat /tmp/mac-opt-no-diagnostic.$$
    fail "$script must explain that diagnostics come first"
  fi

  rm -rf "$tmp" /tmp/mac-opt-no-diagnostic.$$
}

assert_diagnostic_report_has_risk_recommendations() {
  local tmp
  tmp="$(mktemp -d)"
  mkdir -p "$tmp/home/Documents" "$tmp/home/Downloads" "$tmp/home/Desktop" \
    "$tmp/home/Movies" "$tmp/home/Music" "$tmp/home/Pictures" \
    "$tmp/home/Library/Caches/SampleApp" "$tmp/home/Library/Logs" \
    "$tmp/logs" "$tmp/data"
  printf 'sample\n' > "$tmp/home/Library/Caches/SampleApp/cache.txt"

  HOME="$tmp/home" MAC_OPT_USER_HOME="$tmp/home" MAC_OPT_LOG_DIR="$tmp/logs" MAC_OPT_DATA_DIR="$tmp/data" bash ./01-检查脚本/full-check.sh --yes >/tmp/mac-opt-check.$$ 2>&1 || {
    cat /tmp/mac-opt-check.$$
    rm -rf "$tmp" /tmp/mac-opt-check.$$
    fail "full-check must generate a diagnostic report"
    return
  }

  if has_pattern 'command not found' /tmp/mac-opt-check.$$; then
    cat /tmp/mac-opt-check.$$
    rm -rf "$tmp" /tmp/mac-opt-check.$$
    fail "full-check report generation must not execute markdown inline code"
    return
  fi

  local report
  report="$(find "$tmp/logs" -name 'check-report-*.md' -print | head -1)"
  if [[ -n "$report" ]] \
    && has_pattern '风险分级优化建议' "$report" \
    && has_pattern '低风险' "$report" \
    && has_pattern '中风险' "$report" \
    && has_pattern '高风险' "$report" \
    && has_pattern '可选' "$report" \
    && [[ -f "$tmp/data/recommendations-latest.json" ]]; then
    pass "diagnostic report includes optional risk-ranked recommendations"
  else
    [[ -n "${report:-}" ]] && cat "$report"
    fail "diagnostic report must include optional low/medium/high risk recommendations"
  fi

  rm -rf "$tmp" /tmp/mac-opt-check.$$
}

assert_high_risk_not_auto_run() {
  if list_pattern 'docker system prune -a --volumes|tmutil deletelocalsnapshots|simctl erase all' \
    04-自动化脚本/one-click-optimization.sh 04-自动化脚本/quick-optimization.sh >/tmp/mac-opt-high-risk.$$ 2>/dev/null; then
    cat /tmp/mac-opt-high-risk.$$
    rm -f /tmp/mac-opt-high-risk.$$
    fail "one-click and quick scripts must not auto-run high-risk cleanup"
  else
    rm -f /tmp/mac-opt-high-risk.$$
    pass "high-risk cleanup is not in automatic scripts"
  fi
}

assert_shell_syntax() {
  local files=("$@")
  bash -n "${files[@]}"
  pass "shell syntax is valid"
}

assert_verify_runs() {
  if MAC_OPT_NO_CLEAR=1 bash ./04-自动化脚本/verify.sh >/tmp/mac-opt-verify.$$ 2>&1; then
    pass "verify script runs on system bash"
  else
    cat /tmp/mac-opt-verify.$$
    fail "verify script must run on system bash"
  fi
  rm -f /tmp/mac-opt-verify.$$
}

assert_docs_are_current() {
  local failed=0
  if list_markdown_pattern 'Mac-Optimization-System|execute-optimizations\.sh|disk-optimization\.sh|performance-tuning\.sh|startup-optimization\.sh|04-自动化脚本/rollback\.sh.*不存在' >/tmp/mac-opt-docs.$$ 2>/dev/null; then
    cat /tmp/mac-opt-docs.$$
    failed=1
  fi
  rm -f /tmp/mac-opt-docs.$$

  if [[ "$failed" -eq 1 ]]; then
    fail "documentation must not reference old install paths or removed scripts"
  else
    pass "documentation references current scripts"
  fi
}

assert_json_valid() {
  local path="$1"
  if python3 -m json.tool "$path" >/tmp/mac-opt-json.$$ 2>&1; then
    pass "json is valid: $path"
  else
    cat /tmp/mac-opt-json.$$
    fail "invalid json: $path"
  fi
  rm -f /tmp/mac-opt-json.$$
}

assert_skill_package_metadata() {
  local files=(
    "SKILL.md"
    "skill.json"
    "README.zh-CN.md"
    "LICENSE"
    "NOTICE"
    "TESTING.md"
    "agents/openai.yaml"
    "references/safety-policy.md"
    "references/risk-model.md"
    "references/diagnostic-report-contract.md"
    "references/distribution.md"
    "scripts/install.sh"
    "scripts/package_runtime_skill.py"
    ".github/workflows/validate.yml"
  )

  local path
  for path in "${files[@]}"; do
    assert_file "$path"
  done

  assert_json_valid "skill.json"
  assert_json_valid "package.json"

  if has_pattern '^name: mac-optimizer$' SKILL.md \
    && has_pattern '^description: Use when' SKILL.md \
    && has_pattern '诊断报告优先' SKILL.md \
    && has_pattern '高风险' SKILL.md; then
    pass "skill entrypoint includes trigger metadata and safety rules"
  else
    fail "SKILL.md must include trigger metadata and safety rules"
  fi

  if has_pattern 'ChuluuMGL/mac-optimizer' skill.json README.md README.zh-CN.md \
    && has_pattern 'diagnosis-first' skill.json README.md; then
    pass "skill metadata and readmes include repository and diagnosis-first positioning"
  else
    fail "skill metadata/readmes must describe the shareable repository and diagnosis-first positioning"
  fi
}

assert_file "lib/common.sh"
assert_file "README.md"
assert_file "00-系统概览/README.md"
assert_file "04-自动化脚本/verify.sh"
assert_file "04-自动化脚本/rollback.sh"
assert_file "iPhone-Optimization-Guide.md"
assert_skill_package_metadata

assert_no_script_hardcoded_install_path
assert_common_options_present "04-自动化脚本/one-click-optimization.sh"
assert_common_options_present "04-自动化脚本/quick-optimization.sh"
assert_optimizer_requires_diagnostic "04-自动化脚本/quick-optimization.sh"
assert_optimizer_requires_diagnostic "04-自动化脚本/one-click-optimization.sh"
assert_safe_dry_run_execution "04-自动化脚本/quick-optimization.sh"
assert_safe_dry_run_execution "04-自动化脚本/one-click-optimization.sh"
assert_diagnostic_report_has_risk_recommendations
assert_high_risk_not_auto_run
assert_docs_are_current
assert_shell_syntax $(find . -maxdepth 3 -name '*.sh' -print)
assert_verify_runs

if [[ "$failures" -gt 0 ]]; then
  printf '\n%d test(s) failed.\n' "$failures"
  exit 1
fi

printf '\nAll tests passed.\n'

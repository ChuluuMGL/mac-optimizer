#!/usr/bin/env bash
# End-to-end report regression: all scans stay inside synthetic fixtures.
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
h="$tmp/home"
mkdir -p "$tmp/bin" "$tmp/logs" "$tmp/data" "$tmp/tmp" "$tmp/syslib" \
  "$h/.codex/memories" "$h/.codex/secrets" \
  "$h/.codex/worktrees/good/node_modules" "$h/.codex/worktrees/bad/node_modules" \
  "$h/.gemini" "$h/.ollama" "$h/.hermes" "$h/.openclaw" \
  "$h/Library/Caches/App One" "$h/Library/Caches/App Two"
for f in .codex/auth.json .codex/config.toml .codex/state.sqlite \
  .codex/state.sqlite-wal .codex/state.sqlite-shm .gemini/oauth_creds.json \
  .gemini/google_accounts.json .ollama/id_ed25519; do
  printf 'synthetic fixture only\n' > "$h/$f"
done

# Partial numeric output must not masquerade as a successful size.
cat > "$tmp/bin/du" <<'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == -sk ]]; then
  shift
  case "$1" in
    */Library/Caches/*) printf '64\t%s\n' "$1"; exit 1 ;;
    */.codex/auth.json|*/bad/node_modules) printf '128\t%s\n' "$1"; exit 1 ;;
    */.ollama) exit 124 ;;
    */.gemini) exit 1 ;;
    */.codex/memories) printf '0\t%s\n' "$1"; exit 0 ;;
    *) printf '8\t%s\n' "$1"; exit 0 ;;
  esac
fi
# Other report sections need no real disk traversal in this regression.
exit 0
EOF
cat > "$tmp/bin/sysctl" <<'EOF'
#!/bin/sh
case "$2" in
  hw.memsize) echo 8589934592 ;;
  hw.ncpu) echo 4 ;;
  machdep.cpu.brand_string) echo 'Mock CPU' ;;
esac
EOF
cat > "$tmp/bin/sw_vers" <<'EOF'
#!/bin/sh
echo 'mock-macOS'
EOF
for cmd in system_profiler vm_stat launchctl tmutil mdfind ps; do
  printf '#!/bin/sh\nexit 0\n' > "$tmp/bin/$cmd"
done
chmod +x "$tmp/bin/"*

PATH="$tmp/bin:$PATH" HOME="$h" MAC_OPT_USER_HOME="$h" \
  MAC_OPT_TMP_DIR="$tmp/tmp" MAC_OPT_SYSTEM_LIB="$tmp/syslib" \
  MAC_OPT_LOG_DIR="$tmp/logs" MAC_OPT_DATA_DIR="$tmp/data" \
  "$BASH" ./01-检查脚本/full-check.sh --yes > "$tmp/output" 2>&1

python3 - "$tmp" <<'PY'
import json
import pathlib
import sys

root = pathlib.Path(sys.argv[1])
reports = list((root / 'logs').glob('check-report-*.md'))
assert len(reports) == 1, 'one complete report required'
report = reports[0].read_text()
data = json.loads((root / 'data/recommendations-latest.json').read_text())['agent_dirs']
expected = {
    '~/.codex/auth.json', '~/.codex/config.toml', '~/.codex/memories',
    '~/.codex/secrets', '~/.codex/state.sqlite', '~/.codex/state.sqlite-wal',
    '~/.codex/state.sqlite-shm', '~/.gemini/oauth_creds.json',
    '~/.gemini/google_accounts.json', '~/.ollama/id_ed25519',
    '~/.hermes', '~/.openclaw',
}
assert set(data['do_not_touch']) == expected, data
assert not expected.intersection(data['safe_to_clean']), data
assert not expected.intersection(data['needs_confirmation']), data
assert '~/Library/Caches' in data['needs_confirmation'], data
assert '~/Library/Caches/App One' not in data['safe_to_clean'], data
assert all(not path.startswith('[合计]') for paths in data.values() for path in paths)
for path in expected:
    assert f'`{path}`' in report, path
for path in ('~/.codex/auth.json', '~/.gemini', '~/.ollama',
             '~/Library/Caches', '~/.codex/worktrees/bad/node_modules'):
    assert f'| 未知 | `{path}` |' in report, path
    assert f'| 0K | `{path}` |' not in report, path
assert '| 0K | `~/.codex/memories` |' in report
assert '| 未知 | `[合计]' in report
assert '列表不完整' in report
assert '## 10. 原始数据' in report, 'later report sections must survive scan failures'
assert str(root / 'home') not in report, 'home paths must stay redacted'
assert 'synthetic fixture only' not in report, 'fixture contents must never appear'
assert '检查完成' in (root / 'output').read_text()
assert len(list((root / 'home').rglob('*'))) > 0
for file in (root / 'home').rglob('*'):
    if file.is_file():
        assert file.read_text() == 'synthetic fixture only\n', file
print('PASS: full report retains protected JSON/Markdown rows and distinguishes unknown from zero after failures')
PY

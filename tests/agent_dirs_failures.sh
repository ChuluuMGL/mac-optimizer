#!/usr/bin/env bash
# Read-only scanner regressions. All discovered paths and scan commands are fixtures.
# Override MAC_OPT_TEST_LIB_DIR to exercise an isolated historical lib/ snapshot.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIB_DIR="${MAC_OPT_TEST_LIB_DIR:-$ROOT_DIR/lib}"
TEST_TMP="$(mktemp -d "${TMPDIR:-/tmp}/mac-opt-agent-failures.XXXXXX")"
trap 'rm -rf "$TEST_TMP"' EXIT
# macOS TMPDIR ends in /; keep shell and pathlib fixture prefixes identical.
TEST_TMP="$(cd "$TEST_TMP" && pwd -P)"
export MAC_OPT_TEST_LIB_DIR="$LIB_DIR" MAC_OPT_TEST_FIXTURE="$TEST_TMP"
export MAC_OPT_TEST_BASH="$BASH"
printf 'Agent scan regression shell: %s\n' "$BASH_VERSION"
export HOME="$TEST_TMP/home" MAC_OPT_USER_HOME="$TEST_TMP/home"
export MAC_OPT_TMP_DIR="$TEST_TMP/tmp" MAC_OPT_SYSTEM_LIB="$TEST_TMP/system"
export MAC_OPT_LOG_DIR="$TEST_TMP/logs" MAC_OPT_DATA_DIR="$TEST_TMP/data"

python3 - <<'PY'
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys

root = Path(os.environ['MAC_OPT_TEST_FIXTURE'])
home = Path(os.environ['HOME'])
bin_dir = root / 'bin'
for directory in (home, bin_dir, root / 'tmp', root / 'system', root / 'logs', root / 'data'):
    directory.mkdir(parents=True, exist_ok=True)


def script(name, body):
    path = bin_dir / name
    path.write_text('#!/bin/bash\nset -eu\n' + body)
    path.chmod(0o755)
    return path


# No du/find invocation can reach the host: mocks reject paths outside the fixture.
script('du', r'''
[[ "$1" == "-sk" ]] || exit 98
shift
for p in "$@"; do
  case "$p" in "$MAC_OPT_TEST_FIXTURE"/*) ;; *) exit 97 ;; esac
done
printf 'du\n' >> "$MAC_OPT_TEST_FIXTURE/calls"
case "${MOCK_DU_MODE:-normal}" in
  empty) exit 0 ;;
  invalid) printf 'unavailable\t%s\n' "$1"; exit 0 ;;
  fail) exit 7 ;;
  partial) printf '73\t%s\n' "$1"; exit 7 ;;
  zero) printf '0\t%s\n' "$1"; exit 0 ;;
  mixed)
    case "$1" in
      */unknown/node_modules) printf '13\t%s\n' "$1"; exit 7 ;;
    esac
    ;;
esac
n=$#
for p in "$@"; do
  printf '%s\t%s\n' "$((n + 40))" "$p"
  n=$((n - 1))
done
''')
script('find', r'''
case "$1" in "$MAC_OPT_TEST_FIXTURE"/*) ;; *) exit 97 ;; esac
printf 'find\n' >> "$MAC_OPT_TEST_FIXTURE/calls"
case "${MOCK_FIND_MODE:-empty}" in
  empty) exit 0 ;;
  fail) exit 7 ;;
  paths|partial)
    while IFS= read -r p; do printf '%s\n' "$p"; done < "$MOCK_FIND_PATHS"
    [[ "$MOCK_FIND_MODE" != partial ]] || exit 7
    ;;
esac
''')
timeout_body = r'''
[[ "$1" == "${MAC_OPT_SCAN_TIMEOUT:-60}" ]] || exit 98
shift
if [[ "${MOCK_TIMEOUT_STATUS:-0}" != 0 ]]; then
  [[ -z "${MOCK_TIMEOUT_OUTPUT:-}" ]] || printf '%s\n' "$MOCK_TIMEOUT_OUTPUT"
  exit "$MOCK_TIMEOUT_STATUS"
fi
"$@"
'''
script('gtimeout', timeout_body)
script('timeout', timeout_body)
script('status', 'printf "command-output\\n"\nexit "$1"\n')
script('signal', 'kill -TERM $$\n')
script('sleep', 'exec /bin/sleep 5\n')

protected = [
    '.codex/auth.json', '.codex/memories', '.codex/secrets', '.codex/config.toml',
    '.codex/state.sqlite', '.codex/state.sqlite-wal', '.codex/state.sqlite-shm',
    '.gemini/oauth_creds.json', '.gemini/google_accounts.json', '.ollama/id_ed25519',
    '.hermes', '.openclaw',
]
for name in protected:
    path = home / name
    path.parent.mkdir(parents=True, exist_ok=True)
    # Empty fixture files are deliberately not actual credentials or databases.
    path.touch()
for name in ('.cache', 'Library/Caches', '.codex/worktrees', 'empty children'):
    (home / name).mkdir(parents=True, exist_ok=True)
for dirname in ('.cache', 'Library/Caches'):
    for i in range(1000):
        (home / dirname / ('child-%04d-' % i + 'x' * 70)).mkdir()
# Keep argv below macOS ARG_MAX while exceeding typical 64 KiB pipe capacity.
assert sum(len(str(p)) + 8 for p in (home / '.cache').iterdir()) > 128 * 1024
known_path = home / '.codex/worktrees/known/node_modules'
unknown_path = home / '.codex/worktrees/unknown/node_modules'
paths_file = root / 'find-paths'
paths_file.write_text(str(known_path) + '\n' + str(unknown_path) + '\n')
# Long synthetic paths make worktree ranking exceed pipe capacity without a slow
# real scan or thousands of timeout subprocesses. find/du only print these names.
long_paths_file = root / 'long-find-paths'
long_paths = [str(home / '.codex/worktrees' / ('x' * 220) / ('y' * 220) /
                  ('tree-%04d-' % i + 'z' * 200) / 'node_modules') for i in range(256)]
long_paths_file.write_text('\n'.join(long_paths) + '\n')
assert long_paths_file.stat().st_size > 128 * 1024

base_env = os.environ.copy()
base_env.update(PATH=str(bin_dir) + os.pathsep + os.environ['PATH'],
                MOCK_DU_MODE='normal', MOCK_FIND_MODE='empty',
                MOCK_FIND_PATHS=str(paths_file), MOCK_TIMEOUT_STATUS='0',
                MOCK_TIMEOUT_OUTPUT='', MAC_OPT_SCAN_TIMEOUT='60')
source = '''set -euo pipefail
unset MAC_OPT_COMMON_LOADED
source "$MAC_OPT_TEST_LIB_DIR/common.sh"
source "$MAC_OPT_TEST_LIB_DIR/agent_dirs.sh"
'''
failures = []
checks = 0


def run(body, env=None, status=0):
    e = base_env.copy()
    if env:
        e.update(env)
    result = subprocess.run([os.environ['MAC_OPT_TEST_BASH'], '-c', source + body],
                            env=e, text=True, stdout=subprocess.PIPE,
                            stderr=subprocess.PIPE, timeout=45)
    assert result.returncode == status, ('exit %s (expected %s), stderr=%r, output=%r' %
                                        (result.returncode, status, result.stderr, result.stdout[-1000:]))
    return result.stdout


def rows(output):
    answer = [line.split('\t') for line in output.splitlines() if line]
    assert all(len(row) == 4 for row in answer), 'malformed TSV rows: %r' % answer[:4]
    return answer


def case(name, fn):
    global checks
    checks += 1
    try:
        fn()
        print('PASS: agent scan ' + name, flush=True)
    except (AssertionError, subprocess.TimeoutExpired, ValueError) as error:
        failures.append(name)
        print('FAIL: agent scan %s: %s' % (name, error), flush=True)


def emit_case(mode, expected, env=None):
    settings = {'MOCK_DU_MODE': mode}
    if env:
        settings.update(env)
    result = rows(run('_ad_emit keep "$HOME/.codex/auth.json" "protected fixture"\n', settings))
    assert len(result) == 1 and result[0][:3] == [expected, 'keep', '~/.codex/auth.json'], result
    if expected == '?':
        assert '体积未知' in result[0][3], result
    else:
        assert '未知' not in result[0][3], result


case('known nonzero remains numeric', lambda: emit_case('normal', '41'))
case('successful zero remains zero', lambda: emit_case('zero', '0'))
for mode in ('empty', 'invalid', 'fail', 'partial'):
    case('%s size stays unknown and keeps classification' % mode,
         lambda mode=mode: emit_case(mode, '?'))
case('mocked timeout 124 stays unknown', lambda: emit_case('normal', '?', {'MOCK_TIMEOUT_STATUS': '124'}))
case('mocked timeout partial numeric output stays unknown',
     lambda: emit_case('normal', '?', {'MOCK_TIMEOUT_STATUS': '124', 'MOCK_TIMEOUT_OUTPUT': '9\tpartial'}))


def missing_path():
    assert run('_ad_emit keep "$HOME/does-not-exist" fixture\n') == ''
case('missing optional path emits nothing', missing_path)


def top_children():
    result = rows(run('_ad_emit_top_children "$HOME/.cache" 8 confirm fixture\n'))
    assert len(result) == 8, len(result)
    assert [int(row[0]) for row in result] == list(range(1040, 1032, -1)), result
    assert all(row[1] == 'confirm' for row in result), result
case('large child list survives strict pipefail and preserves Top 8', top_children)


def empty_children():
    calls = root / 'calls'
    before = calls.read_text() if calls.exists() else ''
    assert run('_ad_emit_top_children "$HOME/empty children" 8 safe fixture\n') == ''
    after = calls.read_text() if calls.exists() else ''
    assert before == after, 'empty directory should not invoke du with a literal glob'
case('empty children avoid scanning an unexpanded glob', empty_children)


def nullglob_children():
    assert run('shopt -s nullglob\n_ad_emit_top_children \"$HOME/empty children\" 8 safe fixture\n') == ''
case('empty children tolerate caller nullglob under nounset', nullglob_children)


unreadable_dir = home / 'unreadable children'
unreadable_dir.mkdir()
unreadable_dir.chmod(0)
try:
    readable = run('if [[ -r "$HOME/unreadable children" && -x "$HOME/unreadable children" ]]; then printf readable; fi\n')
    if readable == 'readable' and os.geteuid() == 0:
        print('SKIP: agent scan unreadable children (uid 0 masks chmod 000 permissions)', flush=True)
    else:
        def unreadable_children():
            assert readable == '', 'chmod 000 unexpectedly remains accessible without uid 0'
            result = rows(run('_ad_emit_top_children "$HOME/unreadable children" 8 safe fixture\n'))
            assert len(result) == 1 and result[0][:3] == ['?', 'confirm', '~/unreadable children'], result
            assert '体积未知' in result[0][3] and '不完整' in result[0][3], result
        case('unreadable children retain unknown confirmation parent', unreadable_children)
finally:
    unreadable_dir.chmod(0o700)


def failed_children(env):
    result = rows(run('_ad_emit_top_children "$HOME/.cache" 8 safe fixture\n', env))
    assert len(result) == 1 and result[0][:3] == ['?', 'confirm', '~/.cache'], result
    assert '体积未知' in result[0][3] and '不完整' in result[0][3], result
for name, env in (
    ('partial numeric failure', {'MOCK_DU_MODE': 'partial'}),
    ('empty success', {'MOCK_DU_MODE': 'empty'}),
    ('invalid output', {'MOCK_DU_MODE': 'invalid'}),
    ('timeout', {'MOCK_TIMEOUT_STATUS': '124'}),
):
    case('child %s has conservative unknown parent fallback' % name,
         lambda env=env: failed_children(env))


def protection(env):
    # Call the scanner directly as a strict-mode command. Capturing it in an `if`
    # or `|| true` would suppress errexit and conceal the original omission bug.
    scanned = run('agent_dirs_scan\n', env)
    parsed = rows(scanned)
    keep = {row[2]: row for row in parsed if row[1] == 'keep'}
    expected = {'~/' + name for name in protected}
    assert set(keep) == expected, 'missing protected rows: %r' % sorted(expected - set(keep))
    expected_size = '?' if env.get('MOCK_DU_MODE') == 'partial' else '41'
    assert all(row[0] == expected_size for row in keep.values()), keep
    rendered = run('agent_dirs_scan > "$MAC_OPT_TEST_FIXTURE/rows"\n'
                   'format_agent_dirs "$(< "$MAC_OPT_TEST_FIXTURE/rows")"\n', env)
    assert '**不要动**' in rendered
    assert all('`%s`' % path in rendered for path in expected), 'protected paths missing in report'
    summary = json.loads(run('agent_dirs_scan > "$MAC_OPT_TEST_FIXTURE/rows"\n'
                             'agent_dirs_json_summary "$(< "$MAC_OPT_TEST_FIXTURE/rows")"\n', env))
    assert set(summary['do_not_touch']) == expected, summary
    assert expected.isdisjoint(summary['safe_to_clean']), summary
    assert expected.isdisjoint(summary['needs_confirmation']), summary
    if expected_size == '?':
        assert '不代表 0K' in rendered and '| 未知 |' in rendered, rendered
        assert '| 0K |' not in rendered, rendered
case('large cache rankings retain every protected scan/report/JSON row', lambda: protection({}))
case('failed sizes retain every protected scan/report/JSON row as unknown',
     lambda: protection({'MOCK_DU_MODE': 'partial'}))


def worktree(env, expected_count, unknown_paths=()):
    output = rows(run('_ad_emit_worktree_node_modules "$HOME"\n', env))
    assert output and output[-1][0] == '?', output
    assert output[-1][2].startswith('[合计]') and ('%s 个' % expected_count) in output[-1][2], output
    assert '不完整' in output[-1][3], output
    for path in unknown_paths:
        assert any(row[0] == '?' and row[2] == path for row in output[:-1]), output
    return output
case('partial find leaves discovered sizes but unknown total',
     lambda: worktree({'MOCK_FIND_MODE': 'partial'}, 2))
case('failed find with no results still reports unknown total',
     lambda: worktree({'MOCK_FIND_MODE': 'fail'}, 0))
case('partial du retains unknown worktree and unknown total',
     lambda: worktree({'MOCK_FIND_MODE': 'paths', 'MOCK_DU_MODE': 'mixed'}, 2,
                     ('~/.codex/worktrees/unknown/node_modules',)))
case('failed du retains every discovered worktree and unknown total',
     lambda: worktree({'MOCK_FIND_MODE': 'paths', 'MOCK_DU_MODE': 'fail'}, 2,
                     ('~/.codex/worktrees/known/node_modules', '~/.codex/worktrees/unknown/node_modules')))
case('timed-out discovery with no results still reports unknown total',
     lambda: worktree({'MOCK_TIMEOUT_STATUS': '124'}, 0))


def empty_worktree():
    assert run('_ad_emit_worktree_node_modules "$HOME"\n') == ''
case('successful empty discovery emits no misleading total', empty_worktree)


def known_worktree():
    result = rows(run('_ad_emit_worktree_node_modules "$HOME"\n', {'MOCK_FIND_MODE': 'paths'}))
    assert len(result) == 3 and result[-1][0] == '82', result
    assert all(row[0] == '41' for row in result[:-1]), result
case('successful worktree sizes keep exact numeric total', known_worktree)


def large_worktree():
    result = rows(run('_ad_emit_worktree_node_modules "$HOME"\n',
                      {'MOCK_FIND_MODE': 'paths', 'MOCK_FIND_PATHS': str(long_paths_file)}))
    assert len(result) == 6 and result[-1][0] == str(256 * 41), result[-2:]
case('large worktree ranking survives strict pipefail and retains total', large_worktree)


def unknown_format():
    fixture = '0\tkeep\t~/zero\tknown zero\n42\tkeep\t~/known\tknown size\n?\tkeep\t~/unknown\tunknown size\n'
    env = {'MOCK_ROWS': fixture}
    output = run('format_agent_dirs "$MOCK_ROWS"\n', env)
    assert '不代表 0K' in output and '| 0K | `~/zero`' in output and '| 未知 | `~/unknown`' in output, output
    assert output.index('`~/unknown`') < output.index('`~/known`') < output.index('`~/zero`'), output
    summary = json.loads(run('agent_dirs_json_summary "$MOCK_ROWS"\n', env))
    assert set(summary['do_not_touch']) == {'~/zero', '~/known', '~/unknown'}, summary
case('report distinguishes real zero, prioritizes unknown, JSON preserves all paths', unknown_format)


def legacy_scan():
    output = run('scan "$MAC_OPT_TEST_FIXTURE/bin/status" 7\nprintf "continued\\n"\n')
    assert output == 'command-output\ncontinued\n', output
    output = run('scan "$MAC_OPT_TEST_FIXTURE/bin/status" 0\nprintf "continued\\n"\n',
                 {'MOCK_TIMEOUT_STATUS': '124'})
    assert output == 'continued\n', output
    assert run('scan\nprintf "continued\\n"\n') == 'continued\n'
case('legacy scan remains nonfatal on failure, timeout, and no arguments', legacy_scan)


def checked_scan():
    assert run('scan_checked\n') == ''
    assert run('scan_checked "$MAC_OPT_TEST_FIXTURE/bin/status" 0\n') == 'command-output\n'
    assert run('scan_checked "$MAC_OPT_TEST_FIXTURE/bin/status" 7\n', status=7) == 'command-output\n'
case('checked scan preserves command status and no-argument compatibility', checked_scan)

for backend in ('gtimeout', 'timeout'):
    directory = root / ('backend-' + backend)
    directory.mkdir()
    (directory / backend).symlink_to(bin_dir / backend)

    def backend_case(backend=backend, directory=directory):
        assert run('PATH="$MOCK_BACKEND_PATH"\nscan_checked "$MAC_OPT_TEST_FIXTURE/bin/status" 0\n',
                   {'MOCK_BACKEND_PATH': str(directory), 'MOCK_TIMEOUT_STATUS': '124'}, status=124) == ''
        assert run('PATH="$MOCK_BACKEND_PATH"\nscan_checked "$MAC_OPT_TEST_FIXTURE/bin/status" 7\n',
                   {'MOCK_BACKEND_PATH': str(directory)}, status=7) == 'command-output\n'
    case('checked scan preserves %s timeout and failure status' % backend, backend_case)

perl = shutil.which('perl')
if perl:
    directory = root / 'backend-perl'
    directory.mkdir()
    (directory / 'perl').symlink_to(perl)

    def perl_backend():
        env = {'MOCK_BACKEND_PATH': str(directory)}
        prefix = 'PATH="$MOCK_BACKEND_PATH"\n'
        assert run(prefix + 'scan_checked "$MAC_OPT_TEST_FIXTURE/bin/status" 7\n', env, status=7) == 'command-output\n'
        assert run(prefix + 'scan_checked "$MAC_OPT_TEST_FIXTURE/bin/signal"\n', env, status=143) == ''
        env['MAC_OPT_SCAN_TIMEOUT'] = '1'
        assert run(prefix + 'scan_checked "$MAC_OPT_TEST_FIXTURE/bin/sleep"\n', env, status=124) == ''
    case('checked scan Perl fallback preserves failure, signal, timeout status', perl_backend)
else:
    print('SKIP: agent scan Perl fallback (perl unavailable)', flush=True)

print('\nAgent scan regressions: %s/%s passed' % (checks - len(failures), checks), flush=True)
if failures:
    sys.exit(1)
PY

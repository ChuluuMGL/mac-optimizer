#!/usr/bin/env bash

if [[ -n "${MAC_OPT_COMMON_LOADED:-}" ]]; then
  return 0
fi
MAC_OPT_COMMON_LOADED=1

COMMON_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MAC_OPT_ROOT="${MAC_OPT_ROOT:-$(cd "$COMMON_DIR/.." && pwd)}"
MAC_OPT_USER_HOME="${MAC_OPT_USER_HOME:-$HOME}"
MAC_OPT_LOG_DIR="${MAC_OPT_LOG_DIR:-$MAC_OPT_ROOT/logs}"
MAC_OPT_DATA_DIR="${MAC_OPT_DATA_DIR:-$MAC_OPT_ROOT/data}"

DRY_RUN=0
ASSUME_YES=0
SAFE_MODE=0
FULL_PATHS=0
EXTRA_ARGS=()

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

show_common_usage() {
  cat << EOF
Common options:
  --dry-run, -n   Preview actions without deleting files or changing settings.
  --yes, -y       Run without interactive confirmation.
  --safe          Skip preference changes and sudo-only operations.
  --full-paths    Show full paths in the report (default redacts $HOME to ~).
  --help, -h      Show this help.
EOF
}

parse_common_args() {
  EXTRA_ARGS=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dry-run|-n)
        DRY_RUN=1
        shift
        ;;
      --yes|-y)
        ASSUME_YES=1
        shift
        ;;
      --safe)
        SAFE_MODE=1
        shift
        ;;
      --full-paths)
        FULL_PATHS=1
        shift
        ;;
      --help|-h)
        show_common_usage
        exit 0
        ;;
      *)
        EXTRA_ARGS+=("$1")
        shift
        ;;
    esac
  done
}

ensure_work_dirs() {
  mkdir -p "$MAC_OPT_LOG_DIR" "$MAC_OPT_DATA_DIR"
}

clear_screen() {
  if [[ "${MAC_OPT_NO_CLEAR:-0}" != "1" ]]; then
    clear
  fi
}

log_line() {
  local level="$1"
  local color="$2"
  local message="$3"
  local line
  line="$(printf '%b[%s]%b %s' "$color" "$level" "$NC" "$message")"
  if [[ -n "${LOG_FILE:-}" ]]; then
    printf '%b\n' "$line" | tee -a "$LOG_FILE"
  else
    printf '%b\n' "$line"
  fi
}

log() {
  log_line "INFO" "$GREEN" "$1"
}

warn() {
  log_line "WARN" "$YELLOW" "$1"
}

error() {
  log_line "ERROR" "$RED" "$1"
}

info() {
  log_line "INFO" "$BLUE" "$1"
}

confirm_or_exit() {
  local prompt="$1"
  if [[ "$DRY_RUN" -eq 1 || "$ASSUME_YES" -eq 1 ]]; then
    return 0
  fi
  printf '%s [y/N] ' "$prompt"
  read -r reply
  if [[ ! "$reply" =~ ^[Yy]$ ]]; then
    warn "已取消，未执行任何清理。"
    exit 0
  fi
}

path_in_home() {
  local suffix="$1"
  printf '%s/%s' "$MAC_OPT_USER_HOME" "$suffix"
}

dir_size_kb() {
  local path="$1"
  { du -sk "$path" 2>/dev/null || true; } | awk '{print $1}'
}

dir_size_mb() {
  local kb
  kb="$(dir_size_kb "$1")"
  if [[ -z "$kb" ]]; then
    printf '0'
  else
    awk -v kb="$kb" 'BEGIN { printf "%.1f", kb / 1024 }'
  fi
}

file_count_in_dir() {
  local path="$1"
  if [[ -d "$path" ]]; then
    { find "$path" -mindepth 1 -print 2>/dev/null || true; } | wc -l | tr -d ' '
  else
    printf '0'
  fi
}

delete_dir_contents() {
  local path="$1"
  local label="$2"
  if [[ ! -d "$path" ]]; then
    info "$label 不存在，跳过。"
    return 0
  fi

  local size_mb count
  size_mb="$(dir_size_mb "$path")"
  count="$(file_count_in_dir "$path")"

  if [[ "$DRY_RUN" -eq 1 ]]; then
    log "[预览] $label: 约 ${size_mb}MB，${count} 个项目。"
    return 0
  fi

  find "$path" -mindepth 1 -maxdepth 1 -exec rm -rf {} + 2>/dev/null || true
  log "$label 已清理，原大小约 ${size_mb}MB。"
}

delete_matching_files() {
  local label="$1"
  local base="$2"
  shift 2
  if [[ ! -d "$base" ]]; then
    info "$label 不存在，跳过。"
    return 0
  fi

  local count
  count="$({ find "$base" "$@" -type f -print 2>/dev/null || true; } | wc -l | tr -d ' ')"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    log "[预览] $label: $count 个文件。"
    return 0
  fi

  find "$base" "$@" -type f -delete 2>/dev/null || true
  log "$label 已清理 $count 个文件。"
}

truncate_file() {
  local path="$1"
  local label="$2"
  if [[ ! -f "$path" ]]; then
    info "$label 不存在，跳过。"
    return 0
  fi
  local size_mb
  size_mb="$(dir_size_mb "$path")"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    log "[预览] $label: 约 ${size_mb}MB。"
    return 0
  fi
  : > "$path"
  log "$label 已清空，原大小约 ${size_mb}MB。"
}

run_command() {
  local label="$1"
  shift
  if [[ "$DRY_RUN" -eq 1 ]]; then
    log "[预览] $label: $*"
    return 0
  fi
  "$@" >/dev/null 2>&1 && log "$label 已完成。" || warn "$label 未完成，已跳过。"
}

run_sudo_command_if_available() {
  local label="$1"
  shift
  if [[ "$SAFE_MODE" -eq 1 ]]; then
    info "$label 在安全模式下跳过。"
    return 0
  fi
  if [[ "$DRY_RUN" -eq 1 ]]; then
    log "[预览] $label: sudo $*"
    return 0
  fi
  if [[ "$EUID" -eq 0 ]] || sudo -n true 2>/dev/null; then
    sudo "$@" >/dev/null 2>&1 && log "$label 已完成。" || warn "$label 未完成，已跳过。"
  else
    warn "$label 需要管理员权限，已跳过。"
  fi
}

choose_pip() {
  if command -v pip >/dev/null 2>&1; then
    printf 'pip'
  elif command -v pip3 >/dev/null 2>&1; then
    printf 'pip3'
  fi
}

data_volume_mount() {
  if [[ -d /System/Volumes/Data ]]; then
    printf '/System/Volumes/Data'
  else
    printf '/'
  fi
}

disk_line() {
  df -h "$(data_volume_mount)" | tail -1
}

disk_used() {
  disk_line | awk '{print $3}'
}

disk_available() {
  disk_line | awk '{print $4}'
}

disk_capacity_percent() {
  disk_line | awk '{print $5}'
}

disk_capacity_number() {
  disk_capacity_percent | tr -d '%'
}

latest_diagnostic_path() {
  if [[ -f "$MAC_OPT_DATA_DIR/check-latest.json" ]]; then
    printf '%s' "$MAC_OPT_DATA_DIR/check-latest.json"
    return 0
  fi

  local latest
  latest="$(find "$MAC_OPT_DATA_DIR" -maxdepth 1 -name 'check-*.json' -print 2>/dev/null | sort | tail -1)"
  if [[ -n "$latest" ]]; then
    printf '%s' "$latest"
    return 0
  fi

  return 1
}

require_diagnostic_report() {
  local diagnostic
  diagnostic="$(latest_diagnostic_path 2>/dev/null || true)"
  if [[ -z "$diagnostic" ]]; then
    error "请先运行诊断报告，再选择优化。"
    info "建议命令: \"$MAC_OPT_ROOT/01-检查脚本/full-check.sh\""
    info "诊断完成后，再运行当前优化命令。"
    exit 2
  fi

  log "已读取诊断报告数据: $diagnostic"
}

cpu_summary() {
  local brand
  brand="$(sysctl -n machdep.cpu.brand_string 2>/dev/null || true)"
  if [[ -n "$brand" ]]; then
    printf '%s - %s cores' "$brand" "$(sysctl -n hw.ncpu)"
    return 0
  fi
  brand="$(system_profiler SPHardwareDataType 2>/dev/null | awk -F: '/Chip|Processor Name/ {print $2; exit}' | xargs)"
  if [[ -n "$brand" ]]; then
    printf '%s - %s cores' "$brand" "$(sysctl -n hw.ncpu)"
  else
    printf 'Unknown CPU - %s cores' "$(sysctl -n hw.ncpu)"
  fi
}

# === 扫描工具（超时 / 大文件搜索 / APFS 物理大小） ===
# 这些函数让重型扫描可中断、可降级，避免单个慢命令拖垮整份报告。

# scan: 给单条命令套超时；超时或失败一律返回 0，绝不中断脚本。
# 用 MAC_OPT_SCAN_TIMEOUT 覆盖默认 60s。优先 GNU coreutils 的 timeout，
# macOS 原生没有，故用 perl alarm 兜底（系统自带 perl）。
scan() {
  [[ $# -eq 0 ]] && return 0
  local timeout_secs="${MAC_OPT_SCAN_TIMEOUT:-60}"
  if command -v gtimeout >/dev/null 2>&1; then
    gtimeout "$timeout_secs" "$@" 2>/dev/null
  elif command -v timeout >/dev/null 2>&1; then
    timeout "$timeout_secs" "$@" 2>/dev/null
  else
    perl -e '
      my $t = shift;
      my $pid = fork();
      die "fork failed" unless defined $pid;
      if ($pid == 0) { exec @ARGV; exit 127 }
      local $SIG{ALRM} = sub { kill "TERM", $pid; sleep 1; kill "KILL", $pid; exit 124 };
      alarm $t;
      waitpid($pid, 0);
      exit($? >> 8);
    ' "$timeout_secs" "$@" 2>/dev/null
  fi
  return 0
}

# list_large_files: 列出大于 min_bytes（默认 1GiB）的大文件，输出 "KB<TAB>路径"。
# Spotlight 优先（走索引，秒级）；mdfind 不可用才回退 find + prune。
# 注意：Spotlight 未索引的路径会漏报，回退仅在 mdfind 命令缺失时启用。
list_large_files() {
  local min_bytes="${1:-1073741824}"
  local home="${MAC_OPT_USER_HOME:-$HOME}"
  local f

  if command -v mdfind >/dev/null 2>&1; then
    mdfind -onlyin "$home" "kMDItemFSSize > $min_bytes" 2>/dev/null \
      | while IFS= read -r f; do
          case "$f" in
            */Library/*|*/.ollama/*|*/node_modules/*) continue ;;
          esac
          [[ -f "$f" ]] && printf '%s\t%s\n' "$(du -k "$f" 2>/dev/null | awk '{print $1}')" "$f"
        done | sort -rn | head -20
  else
    find "$home" -xdev \
      -type d \( -name Library -o -name .ollama -o -name node_modules \) -prune \
      -o -type f -size +"$min_bytes"c -print0 2>/dev/null \
      | xargs -0 du -k 2>/dev/null | sort -rn | head -20
  fi
}

# 逻辑大小（st_size，stat -f %z，字节）。空洞文件/克隆文件此项会虚高。
logical_bytes() {
  stat -f '%z' "$1" 2>/dev/null | tr -d '[:space:]'
}

# 已分配大小（du，物理占用，字节）。接近真实可回收空间。
allocated_bytes() {
  du -k "$1" 2>/dev/null | awk '{print $1*1024}'
}

logical_mb() {
  awk -v b="$(logical_bytes "$1")" 'BEGIN { printf "%.0f", b/1048576 }'
}

allocated_mb() {
  awk -v b="$(allocated_bytes "$1")" 'BEGIN { printf "%.0f", b/1048576 }'
}

# is_sparse: 判断是否稀疏/空洞文件（逻辑>1MB 且物理<逻辑的 1/4）。
# 返回 0=稀疏，1=非稀疏。调用方请用 if/&& 包裹。
is_sparse() {
  local l a
  l="$(logical_bytes "$1")"
  if [[ ! "$l" =~ ^[0-9]+$ ]] || (( l <= 1048576 )); then
    return 1
  fi
  a="$(allocated_bytes "$1")"
  if [[ ! "$a" =~ ^[0-9]+$ ]]; then
    return 1
  fi
  (( a * 4 < l ))
}

# redact_path: 报告里默认隐藏用户名——把 $MAC_OPT_USER_HOME 前缀换成 ~，
# 再截到末两级目录（parent/basename），降低长路径暴露。
# FULL_PATHS=1（--full-paths）时原样返回完整路径。
redact_path() {
  local p="$1" home="${MAC_OPT_USER_HOME:-$HOME}"
  if [[ "${FULL_PATHS:-0}" == "1" ]]; then
    printf '%s' "$p"
    return 0
  fi
  case "$p" in
    "$home")   printf '~'; return 0 ;;
    "$home"/*) p="~/${p#"$home"/}" ;;
  esac
  local base="${p##*/}"
  local rest="${p%/*}"
  if [[ "$rest" == "$p" ]]; then
    printf '%s' "$base"
  else
    local parent="${rest##*/}"
    printf '%s/%s' "$parent" "$base"
  fi
}

# format_large_files: 把 list_large_files 的 "KB<TAB>路径" 输出格式化为
# "物理MB<TAB>逻辑MB<TAB>标记<TAB>路径(脱敏)"，对稀疏文件标注 SPARSE。
# 用 MAC_OPT_LARGE_FILE_MIN 覆盖默认 1GiB 阈值。
format_large_files() {
  list_large_files "${MAC_OPT_LARGE_FILE_MIN:-1073741824}" | while IFS=$'\t' read -r kb path; do
    [[ -n "$path" ]] || continue
    local flag=""
    if is_sparse "$path"; then flag="SPARSE"; fi
    printf '%sMB\t%sMB\t%s\t%s\n' "$(allocated_mb "$path")" "$(logical_mb "$path")" "$flag" "$(redact_path "$path")"
  done | head -20
}

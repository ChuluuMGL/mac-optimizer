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

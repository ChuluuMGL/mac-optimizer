#!/usr/bin/env bash
# Mac一键优化脚本
# 用途: 清理可再生缓存并报告需要人工确认的存储候选。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "$SCRIPT_DIR/../lib/common.sh"

VERSION="1.4.2"
parse_common_args "$@"
ensure_work_dirs
LOG_FILE="$MAC_OPT_LOG_DIR/one-click-$(date +%Y%m%d-%H%M%S).log"

clear_screen
printf 'Mac 一键优化\n'
printf '时间: %s\n版本: %s\n' "$(date)" "$VERSION" | tee -a "$LOG_FILE"
if [[ "$DRY_RUN" -eq 1 ]]; then
  warn "当前为预览模式，不会删除文件或修改设置。"
fi

require_diagnostic_report
confirm_or_exit "将清理可再生缓存和 7 天前的 Codex 崩溃报告，并执行你显式选择的可选动作，是否继续？"

START_TIME="$(date +%s)"
BEFORE_AVAILABLE_KB="$(disk_available_kb)"

log "[1/10] 浏览器缓存"
delete_dir_contents "$(path_in_home "Library/Caches/Google/Chrome/Default/Cache")" "Chrome 页面缓存"
delete_dir_contents "$(path_in_home "Library/Caches/Google/Chrome/Default/Code Cache")" "Chrome 代码缓存"
delete_dir_contents "$(path_in_home "Library/Caches/com.apple.Safari")" "Safari 缓存"

log "[2/10] 常用应用缓存"
delete_dir_contents "$(path_in_home "Library/Caches/com.alibaba.DingTalkMac")" "钉钉缓存"
delete_dir_contents "$(path_in_home "Library/Caches/ru.keepcoder.Telegram")" "Telegram 缓存"
delete_dir_contents "$(path_in_home "Library/Caches/node-gyp")" "node-gyp 缓存"

log "[3/10] Codex 历史崩溃报告"
delete_matching_files "Codex Crashpad 7 天前待上报文件" \
  "$(path_in_home "Library/Application Support/Codex/Crashpad/pending")" -mtime +7

log "[4/10] 明确日志"
if [[ "$SAFE_MODE" -eq 1 || "$TRUNCATE_V2RAY_LOG" -ne 1 ]]; then
  report_file_state "$(path_in_home "Library/Logs/v2ray-core.log")" "v2ray 日志（未显式指定 --truncate-v2ray-log）"
else
  truncate_file "$(path_in_home "Library/Logs/v2ray-core.log")" "v2ray 日志"
fi

log "[5/10] Python 和 Node.js 缓存"
PIP_CMD="$(choose_pip || true)"
if [[ -n "$PIP_CMD" ]]; then
  run_command "Python pip 缓存清理" "$PIP_CMD" cache purge
else
  info "未找到 pip/pip3，跳过。"
fi
if command -v npm >/dev/null 2>&1; then
  run_command "npm 缓存清理" npm cache clean --force
else
  info "未找到 npm，跳过。"
fi
delete_dir_contents "$(path_in_home ".npm/_npx")" "npm npx 临时文件"
delete_dir_contents "$(path_in_home ".npm/_cacache/tmp")" "npm 临时缓存"

log "[6/10] Homebrew"
if command -v brew >/dev/null 2>&1; then
  run_command "Homebrew cleanup" brew cleanup --prune=all
else
  info "未找到 Homebrew，跳过。"
fi
# Homebrew cleanup can recreate API and bootsnap caches, so remove its
# regenerable cache only after the cleanup command has finished.
delete_dir_contents "$(path_in_home "Library/Caches/Homebrew")" "Homebrew 缓存"

log "[7/10] 中风险项目仅报告"
report_dir_state "$(path_in_home ".Trash")" "废纸篓"
report_matching_files "下载目录 30 天前文件" "$(path_in_home "Downloads")" -mtime +30
report_matching_files "Library/Logs 7 天前日志" "$(path_in_home "Library/Logs")" -name "*.log" -mtime +7

log "[8/10] 界面响应设置"
if [[ "$SAFE_MODE" -eq 1 || "$TUNE_UI" -ne 1 ]]; then
  info "未显式指定 --tune-ui，跳过 Dock 和动画设置。"
else
  run_command "关闭窗口动画" defaults write NSGlobalDomain NSAutomaticWindowAnimationsEnabled -bool false
  run_command "加快 Dock 显示速度" defaults write com.apple.dock autohide-time-modifier -float 0
  run_command "减少 Dock 显示延迟" defaults write com.apple.dock autohide-delay -float 0
  run_command "重启 Dock" killall Dock
fi

log "[9/10] DNS 缓存"
if [[ "$SAFE_MODE" -eq 1 || "$FLUSH_DNS" -ne 1 ]]; then
  info "未显式指定 --flush-dns，跳过 DNS 刷新。"
else
  run_sudo_command_if_available "刷新 DNS 缓存" dscacheutil -flushcache
  run_sudo_command_if_available "通知 mDNSResponder" killall -HUP mDNSResponder
fi

log "[10/10] 磁盘状态"
AFTER_AVAILABLE_KB="$(disk_available_kb)"
RECLAIMED_MB="$(reclaimed_space_mb "$BEFORE_AVAILABLE_KB" "$AFTER_AVAILABLE_KB")"
log "数据卷可用空间: $(disk_available)，使用率: $(disk_capacity_percent)。"

END_TIME="$(date +%s)"
ELAPSED=$((END_TIME - START_TIME))

log "一键优化流程结束。"
cat << EOF | tee -a "$LOG_FILE"

摘要
  模式: $([[ "$DRY_RUN" -eq 1 ]] && echo "预览" || echo "执行")
  耗时: $((ELAPSED / 60))分$((ELAPSED % 60))秒
  本次实际增加可用空间: ${RECLAIMED_MB}MB
  数据卷可用空间: $(disk_available)
  数据卷使用率: $(disk_capacity_percent)
  日志: $LOG_FILE
EOF

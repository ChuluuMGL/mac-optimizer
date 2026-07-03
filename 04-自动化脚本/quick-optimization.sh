#!/usr/bin/env bash
# Mac快速优化脚本
# 用途: 日常低风险维护，支持预览和确认。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "$SCRIPT_DIR/../lib/common.sh"

VERSION="1.3.0"
parse_common_args "$@"
ensure_work_dirs
LOG_FILE="$MAC_OPT_LOG_DIR/quick-opt-$(date +%Y%m%d-%H%M%S).log"

clear_screen
cat << "EOF"
Mac 快速优化
EOF

echo "时间: $(date)" | tee -a "$LOG_FILE"
echo "版本: $VERSION" | tee -a "$LOG_FILE"
if [[ "$DRY_RUN" -eq 1 ]]; then
  warn "当前为预览模式，不会删除文件或修改设置。"
fi
echo "" | tee -a "$LOG_FILE"

require_diagnostic_report
confirm_or_exit "将清理常见缓存、旧日志、废纸篓并刷新部分设置，是否继续？"

START_TIME="$(date +%s)"

log "[1/10] 检查 v2ray 日志"
truncate_file "$(path_in_home "Library/Logs/v2ray-core.log")" "v2ray 日志"

log "[2/10] 检查浏览器缓存"
delete_dir_contents "$(path_in_home "Library/Caches/Google/Chrome/Default/Cache")" "Chrome 页面缓存"
delete_dir_contents "$(path_in_home "Library/Caches/Google/Chrome/Default/Code Cache")" "Chrome 代码缓存"
delete_dir_contents "$(path_in_home "Library/Caches/com.apple.Safari")" "Safari 缓存"

log "[3/10] 检查 Python 缓存"
PIP_CMD="$(choose_pip || true)"
if [[ -n "$PIP_CMD" ]]; then
  run_command "Python pip 缓存清理" "$PIP_CMD" cache purge
else
  info "未找到 pip/pip3，跳过。"
fi

log "[4/10] 检查 Node.js 缓存"
if command -v npm >/dev/null 2>&1; then
  run_command "npm 缓存清理" npm cache clean --force
else
  info "未找到 npm，跳过。"
fi
delete_dir_contents "$(path_in_home ".npm/_npx")" "npm npx 临时文件"
delete_dir_contents "$(path_in_home ".npm/_cacache/tmp")" "npm 临时缓存"

log "[5/10] 检查废纸篓"
delete_dir_contents "$(path_in_home ".Trash")" "废纸篓"

log "[6/10] 检查旧应用日志"
delete_matching_files "7 天前应用日志" "$(path_in_home "Library/Logs")" -name "*.log" -mtime +7

log "[7/10] 检查常用应用缓存"
delete_dir_contents "$(path_in_home "Library/Caches/com.alibaba.DingTalkMac")" "钉钉缓存"
delete_dir_contents "$(path_in_home "Library/Caches/ru.keepcoder.Telegram")" "Telegram 缓存"
delete_dir_contents "$(path_in_home "Library/Caches/Homebrew")" "Homebrew 缓存"

log "[8/10] 检查开发工具缓存"
delete_dir_contents "$(path_in_home "Library/Caches/node-gyp")" "node-gyp 缓存"

log "[9/10] 检查界面响应设置"
if [[ "$SAFE_MODE" -eq 1 ]]; then
  info "安全模式下跳过 Dock 和动画设置。"
else
  run_command "关闭窗口动画" defaults write NSGlobalDomain NSAutomaticWindowAnimationsEnabled -bool false
  run_command "加快 Dock 显示速度" defaults write com.apple.dock autohide-time-modifier -float 0
  run_command "重启 Dock" killall Dock
fi

log "[10/10] 检查 DNS 缓存"
run_sudo_command_if_available "刷新 DNS 缓存" dscacheutil -flushcache
run_sudo_command_if_available "通知 mDNSResponder" killall -HUP mDNSResponder

END_TIME="$(date +%s)"
ELAPSED=$((END_TIME - START_TIME))
MINUTES=$((ELAPSED / 60))
SECONDS=$((ELAPSED % 60))

echo "" | tee -a "$LOG_FILE"
log "快速优化流程结束。"
cat << EOF | tee -a "$LOG_FILE"

摘要
  模式: $([[ "$DRY_RUN" -eq 1 ]] && echo "预览" || echo "执行")
  耗时: ${MINUTES}分${SECONDS}秒
  数据卷可用空间: $(disk_available)
  数据卷使用率: $(disk_capacity_percent)
  日志: $LOG_FILE
EOF

#!/usr/bin/env bash
# 设置回滚脚本
# 用途: 恢复本工具可能修改过的 macOS 偏好设置。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "$SCRIPT_DIR/../lib/common.sh"

VERSION="1.3.0"
parse_common_args "$@"
ensure_work_dirs
LOG_FILE="$MAC_OPT_LOG_DIR/rollback-$(date +%Y%m%d-%H%M%S).log"

clear_screen
cat << "EOF"
Mac 优化设置回滚
EOF

echo "时间: $(date)" | tee -a "$LOG_FILE"
echo "版本: $VERSION" | tee -a "$LOG_FILE"
if [[ "$DRY_RUN" -eq 1 ]]; then
  warn "当前为预览模式，不会修改设置。"
fi
echo "" | tee -a "$LOG_FILE"

confirm_or_exit "将恢复 Dock、动画、Siri/Spotlight、诊断和电源相关设置，是否继续？"

run_command "恢复窗口动画设置" defaults delete NSGlobalDomain NSAutomaticWindowAnimationsEnabled
run_command "恢复 Dock 显示速度" defaults delete com.apple.dock autohide-time-modifier
run_command "恢复 Dock 显示延迟" defaults delete com.apple.dock autohide-delay
run_command "重启 Dock" killall Dock

run_command "恢复 Siri 菜单可见性" defaults delete com.apple.Siri StatusMenuVisible
run_command "恢复 Siri 语音触发" defaults delete com.apple.Siri VoiceTriggerUserEnabled
run_command "恢复输入 Siri 设置" defaults delete com.apple.Siri TypeToSiriEnabled
run_command "恢复 Spotlight 建议设置" defaults delete com.apple.Spotlight SuggestionsLookup
run_command "恢复崩溃报告弹窗" defaults delete com.apple.CrashReporter DialogType
run_command "恢复自动更新检查设置" defaults write com.apple.SoftwareUpdate AutomaticCheckEnabled -bool true

if [[ "$SAFE_MODE" -eq 1 ]]; then
  info "安全模式下跳过电源设置回滚。"
else
  run_sudo_command_if_available "恢复休眠模式" pmset -a hibernatemode 3
  run_sudo_command_if_available "恢复显示器休眠时间" pmset -a displaysleep 10
  run_sudo_command_if_available "恢复系统睡眠时间" pmset -a sleep 30
fi

log "回滚流程结束。部分设置可能需要重新登录或重启后完全生效。"

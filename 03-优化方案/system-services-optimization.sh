#!/bin/bash
# 系统服务优化脚本
# 用途: 逐项修改 macOS 系统服务设置（Siri、Spotlight 建议、诊断数据、Time Machine 本地快照等）
# 用法: ./system-services-optimization.sh [--dry-run]
#       --dry-run 只列出每一项将执行的命令/设置，不调用 sudo、不写入任何设置、不删除快照。
#       每一项都单独询问且默认 No；--yes 不会自动批准这些高风险项；--safe 下不做任何修改。
# 风险: 🟠 高风险（修改系统服务与安全相关设置；删除 Time Machine 本地快照不可恢复）

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "$SCRIPT_DIR/../lib/common.sh"
parse_common_args "$@"

VERSION="1.1.0"
CHANGED_ITEMS=0

# 日志函数（带时间戳）
log() {
    echo -e "${GREEN}[$(date '+%H:%M:%S')]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[$(date '+%H:%M:%S')]${NC} ⚠️  $1"
}

error() {
    echo -e "${RED}[$(date '+%H:%M:%S')]${NC} ❌ $1"
}

info() {
    echo -e "${BLUE}[$(date '+%H:%M:%S')]${NC} ℹ️  $1"
}

# 逐项确认，默认 No。预览/安全模式下只列出命令并返回 1（不执行）。
# --yes 不会自动批准：这些都是高风险的系统设置修改。
# 用法: ask_step "<提示>" "<命令 1>" ["<命令 2>" ...]
ask_step() {
    local prompt="$1"
    shift
    local cmd
    if [[ "$DRY_RUN" -eq 1 ]]; then
        for cmd in "$@"; do
            log "  [预览] 将执行: ${cmd}"
        done
        return 1
    fi
    if [[ "$SAFE_MODE" -eq 1 ]]; then
        info "  - 安全模式（--safe）下不修改系统设置，跳过"
        return 1
    fi
    info "  确认后将执行:"
    for cmd in "$@"; do
        echo "    ${cmd}"
    done
    REPLY=""
    read -p "${prompt} (y/N) " -n 1 -r || true
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        CHANGED_ITEMS=$((CHANGED_ITEMS + 1))
        return 0
    fi
    info "  - 跳过（保持当前设置）"
    return 1
}

# 经 sudo 运行时 defaults 会写入 root 的偏好而不是当前用户的，直接拒绝。
if [[ -n "${SUDO_USER:-}" && "$EUID" -eq 0 && "$DRY_RUN" -ne 1 ]]; then
    error "请不要用 sudo 运行本脚本；需要管理员权限的单项会在确认后单独调用 sudo。"
    exit 1
fi

# 欢迎信息
clear_screen
cat << "EOF"
╔════════════════════════════════════════╗
║   系统服务优化工具 v1.1                 ║
║   逐项确认修改系统服务设置              ║
╚════════════════════════════════════════╝
EOF

echo ""
log "开始检查系统服务设置..."
echo ""
if [[ "$DRY_RUN" -eq 1 ]]; then
    warn "当前为预览模式（--dry-run）：只列出将执行的命令，不调用 sudo、不修改任何设置。"
else
    warn "以下每一项都会单独询问，默认 No。"
    warn "Siri/Spotlight/崩溃报告/自动更新设置可用 04-自动化脚本/rollback.sh 恢复；"
    warn "删除的 Time Machine 本地快照无法恢复。"
fi
echo ""

# ============================================
# 1. Siri
# ============================================
log "[1/7] Siri"
echo ""
info "如果很少使用 Siri，可以关闭（同时关闭基于 Siri 的 Spotlight 建议）"
if ask_step "是否关闭 Siri 和 Spotlight 建议?" \
    "defaults write com.apple.Siri StatusMenuVisible -bool false" \
    "defaults write com.apple.Siri VoiceTriggerUserEnabled -bool false" \
    "defaults write com.apple.Siri TypeToSiriEnabled -bool false" \
    "defaults write com.apple.Spotlight SuggestionsLookup -bool false"; then
    defaults write com.apple.Siri StatusMenuVisible -bool false
    defaults write com.apple.Siri VoiceTriggerUserEnabled -bool false
    defaults write com.apple.Siri TypeToSiriEnabled -bool false
    defaults write com.apple.Spotlight SuggestionsLookup -bool false
    log "  ✓ Siri 已关闭（需要注销或重启后生效）"
fi
echo ""

# ============================================
# 2. Spotlight 建议
# ============================================
log "[2/7] Spotlight 建议"
echo ""
info "关闭 Spotlight 在线建议（不影响本地文件索引）"
if ask_step "是否关闭 Spotlight 在线建议并重启 Spotlight 菜单?" \
    "defaults write com.apple.Spotlight SuggestionsLookup -bool false" \
    "killall Spotlight"; then
    defaults write com.apple.Spotlight SuggestionsLookup -bool false
    killall Spotlight 2>/dev/null || true
    log "  ✓ Spotlight 在线建议已关闭"
fi
echo ""

# ============================================
# 3. 诊断数据与崩溃报告
# ============================================
log "[3/7] 诊断数据与崩溃报告"
echo ""
info "停止向 Apple 提交诊断数据，并关闭崩溃报告弹窗"
warn "  卸载系统 LaunchDaemon 需要 sudo；开启 SIP 的系统上可能失败"
if ask_step "是否停止提交诊断数据并关闭崩溃报告弹窗?" \
    "sudo launchctl unload -w /System/Library/LaunchDaemons/com.apple.SubmitDiagInfo.plist" \
    "defaults write com.apple.CrashReporter DialogType none"; then
    sudo launchctl unload -w /System/Library/LaunchDaemons/com.apple.SubmitDiagInfo.plist 2>/dev/null \
        || warn "  launchctl unload 未完成（可能受 SIP 保护），已跳过"
    defaults write com.apple.CrashReporter DialogType none
    log "  ✓ 已处理诊断数据和崩溃报告设置"
fi
echo ""

# ============================================
# 4. 自动检查软件更新
# ============================================
log "[4/7] 自动检查软件更新"
echo ""
warn "  关闭后不会自动发现 macOS 安全更新，不建议关闭"
if ask_step "是否关闭自动检查软件更新（不推荐）?" \
    "defaults write com.apple.SoftwareUpdate AutomaticCheckEnabled -bool false"; then
    defaults write com.apple.SoftwareUpdate AutomaticCheckEnabled -bool false
    log "  ✓ 自动检查更新已关闭；请定期手动检查更新"
fi
echo ""

# ============================================
# 5. Time Machine 本地快照
# ============================================
log "[5/7] Time Machine 本地快照"
echo ""
SNAPSHOTS=$(tmutil listlocalsnapshots / 2>/dev/null | grep -c 'com.apple' || true)
if [ "${SNAPSHOTS:-0}" -gt 0 ]; then
    warn "  发现 ${SNAPSHOTS} 个本地快照"
    tmutil listlocalsnapshots / 2>/dev/null | head -5 || true
    warn "  ⚠️  删除后无法用这些快照恢复文件，且不可撤销；macOS 会在空间不足时自动清理它们"
    if ask_step "确认永久删除全部 Time Machine 本地快照?" \
        "sudo tmutil deletelocalsnapshots /"; then
        if sudo tmutil deletelocalsnapshots / 2>/dev/null; then
            log "  ✓ 本地快照已删除"
        else
            warn "  删除本地快照未完成，已跳过"
        fi
    fi
else
    info "  - 没有本地快照"
fi
echo ""

# ============================================
# 6. iCloud 同步（仅建议，不修改）
# ============================================
log "[6/7] iCloud 同步（仅建议，不修改设置）"
echo ""
info "  系统设置 → Apple ID → iCloud，可按需关闭："
info "  - iCloud Drive（如果不需要）"
info "  - 照片（如果不需要）"
info "  - 钥匙串（建议保留）"
echo ""

# ============================================
# 7. Dashboard（旧版 macOS）
# ============================================
log "[7/7] Dashboard（仅旧版 macOS 有效）"
echo ""
if ask_step "是否关闭 Dashboard?" \
    "defaults write com.apple.dashboard mcx-disabled -bool true"; then
    defaults write com.apple.dashboard mcx-disabled -bool true
    log "  ✓ Dashboard 已关闭"
fi

# ============================================
# 完成
# ============================================
echo ""
if [[ "$DRY_RUN" -eq 1 ]]; then
    log "✅ 预览结束：未修改任何设置。确认后可不带 --dry-run 再执行（仍会逐项询问，默认 No）。"
    exit 0
fi
if [ "$CHANGED_ITEMS" -gt 0 ]; then
    log "✅ 已确认并执行 ${CHANGED_ITEMS} 项修改"
else
    info "未修改任何设置"
fi
echo ""
cat << EOF
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
💡 恢复方法
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Siri、Spotlight 建议、崩溃报告弹窗、自动更新检查:
   bash ./04-自动化脚本/rollback.sh

诊断数据提交:
   sudo launchctl load -w /System/Library/LaunchDaemons/com.apple.SubmitDiagInfo.plist

Dashboard:
   defaults delete com.apple.dashboard mcx-disabled

Time Machine 本地快照删除后无法恢复。
部分设置需要注销或重启后生效。
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF

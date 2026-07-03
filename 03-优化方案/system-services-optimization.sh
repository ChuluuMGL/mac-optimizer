#!/bin/bash
# 系统服务优化脚本
# 用途: 优化 macOS 系统服务，禁用不必要的功能
# 用法: ./system-services-optimization.sh
# 风险: 🟡 中风险（修改系统设置，可逆）

set -e

VERSION="1.0.0"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
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

# 欢迎信息
clear
cat << "EOF"
╔════════════════════════════════════════╗
║   系统服务优化工具 v1.0                 ║
║   禁用不必要服务 释放系统资源          ║
╚════════════════════════════════════════╝
EOF

echo ""
log "开始优化系统服务..."
echo ""
warn "⚠️  以下操作将修改系统设置"
warn "   所有操作都可以撤销（见恢复脚本）"
echo ""

# ============================================
# 1. Siri 优化
# ============================================
log "[1/6] Siri 服务优化..."

echo ""
info "Siri 会占用 CPU 和内存资源"
echo "如果很少使用 Siri，建议禁用"
echo ""
read -p "是否禁用 Siri? (y/N) " -n 1 -r
echo

if [[ $REPLY =~ ^[Yy]$ ]]; then
    # 禁用 Siri
    defaults write com.apple.Siri StatusMenuVisible -bool false
    defaults write com.apple.Siri VoiceTriggerUserEnabled -bool false
    defaults write com.apple.Siri TypeToSiriEnabled -bool false

    # 禁用 Spotlight 建议（基于 Siri）
    defaults write com.apple.Spotlight SuggestionsLookup -bool false

    log "  ✓ Siri 已禁用"
    warn "    需要重启生效"
else
    info "  - 保留 Siri"
fi

# ============================================
# 2. Spotlight 优化
# ============================================
log "[2/6] Spotlight 优化..."

echo ""
info "Spotlight 索引会占用磁盘和 CPU"
info "可以禁用不必要的索引类型"
echo ""
read -p "是否优化 Spotlight? (y/N) " -n 1 -r
echo

if [[ $REPLY =~ ^[Yy]$ ]]; then
    # 禁用 Spotlight 建议
    defaults write com.apple.Spotlight SuggestionsLookup -bool false

    # 禁用 Spotlight 网络搜索
    defaults write com.apple.Spotlight AllowedTypes -array-add "MDSpotlightGenericFileType"

    # 重启 Spotlight
    killall Spotlight 2>/dev/null

    log "  ✓ Spotlight 已优化"
else
    info "  - 保留 Spotlight 设置"
fi

# ============================================
# 3. Analytics 禁用
# ============================================
log "[3/6] 禁用发送诊断数据..."

echo ""
info "macOS 会发送使用数据和诊断信息给 Apple"
info "禁用可以保护隐私并减少网络流量"
echo ""
read -p "是否禁用数据发送? (y/N) " -n 1 -r
echo

if [[ $REPLY =~ ^[Yy]$ ]]; then
    # 禁用诊断数据提交
    sudo launchctl unload -w /System/Library/LaunchDaemons/com.apple.SubmitDiagInfo.plist 2>/dev/null

    # 禁用崩溃报告
    defaults write com.apple.CrashReporter DialogType none

    # 禁用自动更新检查
    defaults write com.apple.SoftwareUpdate AutomaticCheckEnabled -bool false

    log "  ✓ 诊断数据发送已禁用"
else
    info "  - 保留数据发送"
fi

# ============================================
# 4. Time Machine 本地快照优化
# ============================================
log "[4/6] Time Machine 本地快照优化..."

echo ""
info "Time Machine 会创建本地快照，占用磁盘空间"
info "如果使用外置备份，可以删除本地快照"
echo ""

# 列出快照
SNAPSHOTS=$(tmutil listlocalsnapshots / 2>/dev/null | wc -l)
if [ $SNAPSHOTS -gt 0 ]; then
    warn "  发现 ${SNAPSHOTS} 个本地快照"
    tmutil listlocalsnapshots / 2>/dev/null | head -5
    echo ""

    read -p "是否删除所有本地快照? (y/N) " -n 1 -r
    echo

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        sudo tmutil deletelocalsnapshots / 2>/dev/null
        log "  ✓ 本地快照已删除"
    else
        info "  - 保留本地快照"
    fi
else
    info "  - 没有本地快照"
fi

# ============================================
# 5. iCloud 同步优化
# ============================================
log "[5/6] iCloud 同步优化..."

echo ""
info "iCloud 同步会占用网络和磁盘资源"
info "可以禁用不需要的同步类型"
echo ""

read -p "是否显示 iCloud 同步建议? (y/N) " -n 1 -r
echo

if [[ $REPLY =~ ^[Yy]$ ]]; then
    info "  系统设置 → Apple ID → iCloud"
    info "  根据需要禁用："
    info "  - iCloud Drive（如果不需要）"
    info "  - 照片（如果不需要）"
    info "  - 钥匙串（建议保留）"
else
    info "  - 跳过"
fi

# ============================================
# 6. 仪表盘小组件优化
# ============================================
log "[6/6] 仪表盘小组件优化..."

echo ""
info "禁用不必要的仪表盘小组件可以节省资源"
echo ""

# 禁用 Dashboard（旧版 macOS）
defaults write com.apple.dashboard mcx-disabled -bool true

log "  ✓ Dashboard 已优化"

# ============================================
# 完成
# ============================================
echo ""
log "✅ 系统服务优化完成！"
echo ""
cat << EOF
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
💡 恢复方法
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
如果需要恢复设置，请执行:

1. Siri:
   defaults delete com.apple.Siri StatusMenuVisible
   defaults delete com.apple.Siri VoiceTriggerUserEnabled
   killall Spotlight

2. Spotlight:
   defaults delete com.apple.Spotlight SuggestionsLookup
   killall Spotlight

3. 重启 Mac 使所有更改生效
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

⚠️  注意:
  • 部分设置需要重启生效
  • 建议使用几天，观察效果
  • 如有问题可随时恢复
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF

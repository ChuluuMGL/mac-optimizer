#!/bin/bash
# 启动项管理脚本
# 用途: 查看和管理 macOS 登录项
# 用法: ./startup-manager.sh
# 风险: 🟢 低风险（仅显示信息，不自动删除）

VERSION="1.0.0"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 日志函数
log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# 欢迎信息
clear
cat << "EOF"
╔════════════════════════════════════════╗
║   启动项管理工具 v1.0                   ║
║   查看和管理登录项 优化启动速度        ║
╚══════════════════════════════━━━━━━━━━━━┛
EOF

echo ""
log "扫描启动项..."
echo ""

# ============================================
# 1. 用户登录项（系统设置）
# ============================================
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}1. 用户登录项（系统设置 → 通用 → 登录项）${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# 读取登录项
LOGIN_ITEMS=$(osascript << 'EOF'
tell application "System Events"
    set loginItems to get the name of every login item
    return loginItems as string
end tell
EOF
)

if [ -n "$LOGIN_ITEMS" ]; then
    echo "📱 当前登录项:"
    echo "$LOGIN_ITEMS" | tr ',' '\n' | nl
    echo ""

    # 获取详细信息
    osascript << 'EOF'
tell application "System Events"
    set loginItems to get every login item
    repeat with item in loginItems
        set itemName to get name of item
        set itemPath to get path of item
        set itemHidden to get hidden of item
        log "  • " & itemName & " (" & itemPath & ")"
        if itemHidden then
            log "    [隐藏]"
        end if
    end repeat
end tell
EOF
else
    info "  没有发现登录项"
fi

echo ""
warn "💡 管理方法:"
warn "   系统设置 → 通用 → 登录项"
warn "   手动移除不需要的启动项"
echo ""

# ============================================
# 2. LaunchAgents（用户级）
# ============================================
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}2. LaunchAgents（用户级自动启动）${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

AGENT_COUNT=0
if [ -d ~/Library/LaunchAgents ]; then
    echo "📄 ~/Library/LaunchAgents/:"
    ls ~/Library/LaunchAgents/*.plist 2>/dev/null | while read pl; do
        AGENT_COUNT=$((AGENT_COUNT + 1))
        filename=$(basename "$pl")
        label=$(/usr/libexec/PlistBuddy -c "Print :Label" "$pl" 2>/dev/null || echo "未知")
        echo "  • ${filename}"
        echo "    Label: ${label}"
    done

    if [ $AGENT_COUNT -eq 0 ]; then
        info "  (空)"
    fi
else
    info "  目录不存在"
fi

echo ""
warn "💡 管理方法:"
warn "   删除不需要的 .plist 文件"
echo ""

# ============================================
# 3. LaunchDaemons（系统级）
# ============================================
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}3. LaunchDaemons（系统级服务）${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

DAEMON_COUNT=0
if [ -d /Library/LaunchDaemons ]; then
    echo "📄 /Library/LaunchDaemons:"
    ls /Library/LaunchDaemons/*.plist 2>/dev/null | while read pl; do
        DAEMON_COUNT=$((DAEMON_COUNT + 1))
        filename=$(basename "$pl")
        label=$(/usr/libexec/PlistBuddy -c "Print :Label" "$pl" 2>/dev/null || echo "未知")
        echo "  • ${filename}"
        echo "    Label: ${label}"
    done | head -10  # 只显示前10个

    if [ $DAEMON_COUNT -gt 10 ]; then
        info "  ... 还有 $((DAEMON_COUNT - 10)) 个"
    fi

    if [ $DAEMON_COUNT -eq 0 ]; then
        info "  (空)"
    fi
fi

echo ""
warn "⚠️  系统级服务，建议不要随意删除"
echo ""

# ============================================
# 4. 应用程序启动项
# ============================================
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}4. 常见应用的自动启动设置${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

info "以下应用可能设置了自动启动:"
echo "  • Docker Desktop"
echo "  • Ollama"
echo "  • V2rayU/Clash"
echo "  • ToDesk"
echo "  • 钉钉/微信"
echo ""

warn "💡 管理方法:"
warn "   在各应用的设置中禁用「开机自启」"
echo ""

# ============================================
# 5. 推荐保留的启动项
# ============================================
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}5. 建议保留的启动项${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

log "✅ 推荐保留:"
echo "  • 系统工具（如密码管理器）"
echo "  • 每日必须使用的工作软件"
echo "  • 同步工具（如 iCloud）"
echo ""

warn "⚠️  建议移除:"
echo "  • 开发工具（Docker、Ollama、IDE）"
echo "  • 偶尔使用的工具"
echo "  • VPN 工具（需要时手动启动）"
echo ""

# ============================================
# 6. 禁用启动项的命令
# ============================================
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}6. 命令行禁用方法${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

echo "禁用 LaunchAgent:"
echo "  launchctl unload ~/Library/LaunchAgents/<文件名>.plist"
echo ""
echo "禁用 LaunchDaemon:"
echo "  sudo launchctl unload /Library/LaunchDaemons/<文件名>.plist"
echo ""

# ============================================
# 完成
# ============================================
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
log "✅ 启动项扫描完成！"
echo ""
cat << EOF
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
💡 优化建议
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
1. 打开「系统设置 → 通用 → 登录项」
2. 移除不需要的启动项
3. 在各应用设置中禁用「开机自启」
4. 重启 Mac 验证效果

预期效果:
  • 开机速度提升 30-50%
  • 内存占用减少
  • 系统更流畅
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF

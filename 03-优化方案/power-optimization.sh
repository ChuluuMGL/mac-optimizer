#!/bin/bash
# 电源管理优化脚本
# 用途: 优化 macOS 电源设置，适配台式机/笔记本
# 用法: ./power-optimization.sh
# 风险: 🟢 低风险（仅修改电源设置，可逆）

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
║   电源管理优化工具 v1.0                 ║
║   优化电源设置 释放空间 延长续航        ║
╚════════════════════════════════════════╝
EOF

echo ""
log "检测设备类型..."
echo ""

# ============================================
# 0. 检测设备类型
# ============================================
# 检测是否为笔记本（有电池）
HAS_BATTERY=$(system_profiler SPPowerDataType 2>/dev/null | grep -c "Battery Information")

if [ $HAS_BATTERY -gt 0 ]; then
    DEVICE_TYPE="MacBook"
    DEVICE_EMOJI="💻"
else
    DEVICE_TYPE="台式 Mac"
    DEVICE_EMOJI="🖥️"
fi

log "检测到: ${DEVICE_EMOJI} ${DEVICE_TYPE}"
echo ""

# ============================================
# 显示当前电源设置
# ============================================
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}当前电源设置${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

pmset -g | grep -E "hibernatemode|sleep|disksleep|displaysleep" || echo "无法读取电源设置"

echo ""

# ============================================
# 根据设备类型显示优化方案
# ============================================

if [ "$DEVICE_TYPE" = "台式 Mac" ]; then
    # ========== 台式机优化 ==========
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}台式 Mac 优化方案${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    log "💡 台式机不需要休眠镜像（可释放 ~2GB）"
    echo ""
    warn "当前休眠模式:"
    pmset -g | grep hibernatemode || echo "无法读取"
    echo ""

    read -p "是否禁用休眠镜像释放 2GB 空间? (y/N) " -n 1 -r
    echo

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        sudo pmset -a hibernatemode 0
        sudo rm -f /var/vm/sleepimage
        log "  ✓ 休眠镜像已禁用，释放 2GB 空间"
    else
        info "  - 跳过"
    fi

    echo ""
    read -p "是否设置显示器永不休眠? (y/N) " -n 1 -r
    echo

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        sudo pmset -c displaysleep 0
        log "  ✓ 显示器不休眠"
    else
        read -p "设置显示器休眠时间（分钟，建议30）: " time
        sudo pmset -c displaysleep $time
        log "  ✓ 显示器 ${time} 分钟后休眠"
    fi

    echo ""
    read -p "是否禁用系统睡眠? (y/N) " -n 1 -r
    echo

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        sudo pmset -c sleep 0
        log "  ✓ 系统不休眠"
    else
        info "  - 保持系统睡眠设置"
    fi

else
    # ========== MacBook 优化 ==========
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}MacBook 优化方案${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    # 获取电池信息
    BATTERY_CYCLES=$(system_profiler SPPowerDataType 2>/dev/null | grep "Cycle Count" | awk '{print $3}')
    BATTERY_HEALTH=$(system_profiler SPPowerDataType 2>/dev/null | grep "Condition" | awk '{print $2, $3}')

    log "电池状态:"
    echo "  循环次数: ${BATTERY_CYCLES}"
    echo "  健康状态: ${BATTERY_HEALTH}"
    echo ""

    # 显示优化选项
    echo "请选择优化模式:"
    echo "  1. 平衡模式（推荐）- 30分钟显示器休眠"
    echo "  2. 省电模式 - 15分钟显示器休眠 + 深度休眠"
    echo "  3. 性能模式 - 显示器不休眠（仅限电源连接）"
    echo ""
    read -p "请选择 [1-3]: " mode

    case $mode in
        1)
            echo ""
            log "设置平衡模式..."
            # 电源连接时
            sudo pmset -c displaysleep 30 disksleep 10 sleep 0
            # 电池供电时
            sudo pmset -b displaysleep 15 sleep 15
            log "  ✓ 平衡模式已设置"
            ;;
        2)
            echo ""
            log "设置省电模式..."
            # 电源连接时
            sudo pmset -c displaysleep 20 sleep 30 hibernatemode 25
            # 电池供电时
            sudo pmset -b displaysleep 15 sleep 15 hibernatemode 25
            log "  ✓ 省电模式已设置"
            ;;
        3)
            echo ""
            log "设置性能模式..."
            # 仅在电源连接时生效
            sudo pmset -c displaysleep 0 sleep 0
            # 电池供电时保持安全设置
            sudo pmset -b displaysleep 10 sleep 10
            log "  ✓ 性能模式已设置"
            warn "    仅电源连接时生效"
            ;;
        *)
            error "无效选择"
            exit 1
            ;;
    esac

    echo ""
    info "💡 MacBook 使用建议:"
    echo "  • 定期完全充放电（每月1次）"
    echo "  • 避免长期处于极端温度"
    echo "  • 循环次数超过1000考虑更换电池"
fi

# ============================================
# 通用优化
# ============================================
echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}通用优化${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# 禁用唤醒时需要密码（仅当使用电源适配器）
read -p "是否禁用电源连接时唤醒需要密码? (y/N) " -n 1 -r
echo

if [[ $REPLY =~ ^[Yy]$ ]]; then
    # 仅设置电源适配器模式
    defaults write com.apple.screensaver askForPassword -int 1
    defaults write com.apple.screensaver askForPasswordDelay -int 0
    log "  ✓ 密码设置已更新"
else
    info "  - 保持安全设置"
fi

# ============================================
# 完成
# ============================================
echo ""
log "✅ 电源优化完成！"
echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}新电源设置${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

pmset -g | grep -E "hibernatemode|sleep|disksleep|displaysleep"

echo ""
cat << EOF
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
💡 恢复默认设置
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
如需恢复默认设置:

sudo pmset -a hibernatemode 3
sudo pmset -a displaysleep 10
sudo pmset -a sleep 30

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

⚠️  注意:
  • 部分设置需要重启生效
  • MacBook 移除电源时会切换到电池设置
  • 定期检查电池健康状态
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF

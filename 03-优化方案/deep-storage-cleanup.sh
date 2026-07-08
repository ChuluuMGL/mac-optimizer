#!/bin/bash
# 深度存储清理脚本
# 用途: 清理开发工具和大文件，释放大量空间
# 用法: ./deep-storage-cleanup.sh
# 风险: 🟡 中风险（删除开发缓存，建议先查看）

VERSION="1.0.0"
FREED_SPACE=0

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

# 获取目录大小
get_size() {
    du -sh "$1" 2>/dev/null | cut -f1
}

# 欢迎信息
clear
cat << "EOF"
╔════════════════════════════════════════╗
║   深度存储清理工具 v1.0                ║
║   清理开发工具和大文件 释放空间        ║
╚════════════════════════════════════════╝
EOF

echo ""
warn "⚠️  此工具会删除开发缓存和临时文件"
warn "   建议先查看大小再决定是否清理"
echo ""

# ============================================
# 1. Xcode 派生数据
# ============================================
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}1. Xcode 派生数据${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

XCODE_DERIVED_DIR=~/Library/Developer/Xcode/DerivedData
if [ -d "$XCODE_DERIVED_DIR" ]; then
    XCODE_SIZE=$(get_size "$XCODE_DERIVED_DIR")
    warn "  大小: ${XCODE_SIZE}"
    info "  路径: ${XCODE_DERIVED_DIR}"
    echo ""

    read -p "是否删除 Xcode 派生数据? (y/N) " -n 1 -r
    echo

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -rf "$XCODE_DERIVED_DIR"/*
        log "  ✓ Xcode 派生数据已删除"
        FREED_SPACE=$((FREED_SPACE + 1))
    else
        info "  - 跳过"
    fi
else
    info "  未安装 Xcode"
fi

# ============================================
# 2. Xcode Simulator 数据
# ============================================
echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}2. Xcode Simulator 数据${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

XCODE_SIMULATOR_DIR=~/Library/Developer/CoreSimulator
if [ -d "$XCODE_SIMULATOR_DIR" ]; then
    XCODE_SIMULATOR_SIZE=$(get_size "$XCODE_SIMULATOR_DIR")
    warn "  大小: ${XCODE_SIMULATOR_SIZE}"
    info "  路径: ${XCODE_SIMULATOR_DIR}"
    echo ""

    read -p "是否删除所有 Xcode Simulator 数据? (y/N) " -n 1 -r
    echo

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        xcrun simctl erase all 2>/dev/null
        log "  ✓ Xcode Simulator 数据已删除"
        FREED_SPACE=$((FREED_SPACE + 1))
    else
        info "  - 跳过"
    fi
else
    info "  未安装 Xcode Simulator"
fi

# ============================================
# 3. Android 模拟器
# ============================================
echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}3. Android 模拟器${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

ANDROID_DIR=~/.android
if [ -d "$ANDROID_DIR" ]; then
    ANDROID_SIZE=$(get_size "$ANDROID_DIR")
    warn "  大小: ${ANDROID_SIZE}"
    info "  路径: ${ANDROID_DIR}"
    echo ""

    read -p "是否删除 Android 模拟器数据? (y/N) " -n 1 -r
    echo

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -rf "$ANDROID_DIR/avd"/*
        log "  ✓ Android 模拟器数据已删除"
        FREED_SPACE=$((FREED_SPACE + 1))
    else
        info "  - 跳过"
    fi
else
    info "  未安装 Android 工具"
fi

# ============================================
# 4. Docker 磁盘使用
# ============================================
echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}4. Docker 磁盘使用${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

if command -v docker &> /dev/null; then
    DOCKER_SIZE=$(docker system df 2>/dev/null | grep "Local Volumes" | awk '{print $4, $5}')
    warn "  Docker 磁盘占用:"
    docker system df 2>/dev/null | head -5
    echo ""

    info "  清理命令:"
    echo "    docker system prune -a --volumes"
    echo ""

    read -p "是否清理 Docker 未使用资源? (y/N) " -n 1 -r
    echo

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        docker system prune -a --volumes -f 2>/dev/null
        log "  ✓ Docker 缓存已清理"
        FREED_SPACE=$((FREED_SPACE + 1))
    else
        info "  - 跳过"
    fi
else
    info "  Docker 未安装或未运行"
fi

# ============================================
# 5. 查找大文件
# ============================================
echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}5. 用户目录大文件 (>1GB)${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

info "  扫描中..."
echo ""

LARGE_FILES=$(find ~ -xdev \
    -type d \( -name Library -o -name .ollama -o -name node_modules -o -name .Trash -o -name iCloud \) -prune \
    -o -type f -size +1G -print 2>/dev/null | head -10)

if [ -n "$LARGE_FILES" ]; then
    warn "  发现以下大文件:"
    echo "$LARGE_FILES" | while read file; do
        size=$(get_size "$file")
        echo "    • ${file}"
        echo "      ${size}"
    done
    echo ""
    warn "  ⚠️  请手动检查这些文件是否需要"
else
    info "  ✓ 没有发现超大文件"
fi

# ============================================
# 6. 下载文件夹清理
# ============================================
echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}6. 下载文件夹清理${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

OLD_DOWNLOADS=$(find ~/Downloads -type f -mtime +30 2>/dev/null | wc -l)
if [ $OLD_DOWNLOADS -gt 0 ]; then
    warn "  发现 ${OLD_DOWNLOADS} 个30天以上的文件"

    echo ""
    info "  10个最老的文件:"
    find ~/Downloads -type f -mtime +30 -exec ls -lh {} + 2>/dev/null | head -10 | awk '{print "    " $9, "  (" $5 ")"}'
    echo ""

    read -p "是否删除30天以上的文件? (y/N) " -n 1 -r
    echo

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        DELETED=$(find ~/Downloads -type f -mtime +30 -delete -print 2>/dev/null | wc -l)
        log "  ✓ 已删除 ${DELETED} 个旧文件"
        FREED_SPACE=$((FREED_SPACE + 1))
    else
        info "  - 跳过"
    fi
else
    info "  ✓ 下载文件夹很干净"
fi

# ============================================
# 7. 应用缓存批量清理
# ============================================
echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}7. 应用缓存批量清理${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

info "  扫描应用缓存..."
echo ""

# 定义可清理的缓存列表
CACHE_DIRS=(
    "Google:Chrome 缓存"
    "com.alibaba.DingTalkMac:钉钉缓存"
    "ru.keepcoder.Telegram:Telegram 缓存"
    "Trae:Trae 缓存"
    "Homebrew:Homebrew 缓存"
    "com.openai.atlas:OpenAI 缓存"
    "pip:pip 缓存"
    "node-gyp:node-gyp 缓存"
    "ms-playwright:Playwright 缓存"
    "ms-playwright-go:Playwright-go 缓存"
)

TOTAL_CACHE_SIZE=0
CACHE_TO_CLEAN=()

for item in "${CACHE_DIRS[@]}"; do
    IFS=':' read -r dir name <<< "$item"
    CACHE_PATH=~/Library/Caches/$dir
    if [ -d "$CACHE_PATH" ]; then
        SIZE=$(du -sm "$CACHE_PATH" 2>/dev/null | cut -f1)
        if [ "$SIZE" -gt 10 ]; then
            SIZE_HUMAN=$(du -sh "$CACHE_PATH" 2>/dev/null | cut -f1)
            warn "  ${name}: ${SIZE_HUMAN}"
            CACHE_TO_CLEAN+=("$dir:$name:$SIZE")
            TOTAL_CACHE_SIZE=$((TOTAL_CACHE_SIZE + SIZE))
        fi
    fi
done

if [ ${#CACHE_TO_CLEAN[@]} -gt 0 ]; then
    echo ""
    info "  可释放约 $((TOTAL_CACHE_SIZE / 1024))GB 空间"
    echo ""
    read -p "是否清理以上缓存? (y/N) " -n 1 -r
    echo

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        for item in "${CACHE_TO_CLEAN[@]}"; do
            IFS=':' read -r dir name size <<< "$item"
            rm -rf ~/Library/Caches/$dir/* 2>/dev/null
            log "  ✓ ${name} 已清理"
        done
        FREED_SPACE=$((FREED_SPACE + 1))
    else
        info "  - 跳过"
    fi
else
    info "  ✓ 应用缓存已清理或很小"
fi

# ============================================
# 8. 项目日志文件清理
# ============================================
echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}8. 项目日志文件 (>100MB)${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

info "  扫描项目日志..."
LARGE_LOGS=$(find ~/Documents -path "*/logs/*.log" -size +100M -exec ls -lh {} + 2>/dev/null | awk '{print $5, $9}')

if [ -n "$LARGE_LOGS" ]; then
    warn "  发现大型日志文件:"
    echo "$LARGE_LOGS" | while read size path; do
        echo "    • ${path} (${size})"
    done
    echo ""
    warn "  ⚠️  日志文件可以安全删除，不影响程序运行"
    echo ""
    read -p "是否删除以上日志文件? (y/N) " -n 1 -r
    echo

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        find ~/Documents -path "*/logs/*.log" -size +100M -delete 2>/dev/null
        log "  ✓ 大型日志文件已删除"
        FREED_SPACE=$((FREED_SPACE + 1))
    else
        info "  - 跳过"
    fi
else
    info "  ✓ 没有发现大型日志文件"
fi

# ============================================
# 9. Time Machine 本地快照
# ============================================
echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}9. Time Machine 本地快照${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

SNAPSHOTS=$(tmutil listlocalsnapshots / 2>/dev/null | wc -l)
if [ $SNAPSHOTS -gt 0 ]; then
    warn "  发现 ${SNAPSHOTS} 个本地快照"
    echo ""

    read -p "是否删除所有本地快照? (y/N) " -n 1 -r
    echo

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        sudo tmutil deletelocalsnapshots / 2>/dev/null
        log "  ✓ 本地快照已删除"
        FREED_SPACE=$((FREED_SPACE + 1))
    else
        info "  - 跳过"
    fi
else
    info "  ✓ 没有本地快照"
fi

# ============================================
# 完成
# ============================================
echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
log "✅ 深度存储清理完成！"
echo ""

if [ $FREED_SPACE -gt 0 ]; then
    log "📊 执行了 ${FREED_SPACE} 项清理"
else
    info "未执行任何清理"
fi

echo ""
cat << EOF
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
💡 后续建议
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
1. 定期清理下载文件夹（每月）
2. 删除不需要的 Docker 镜像和容器
3. 清理 Xcode 派生数据（开发后）
4. 检查并删除大文件
5. 检查项目日志文件（logs/*.log）
6. 定期清理应用缓存

预期释放空间:
  • Xcode: 5-20GB
  • Xcode Simulator: 10-30GB
  • Android: 5-15GB
  • Docker: 2-10GB
  • 应用缓存: 2-5GB
  • 项目日志: 可能很大（如 100GB+）
  • 总计: 20-80GB+
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF

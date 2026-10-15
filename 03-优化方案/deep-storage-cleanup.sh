#!/bin/bash
# 深度存储清理脚本
# 用途: 检查开发工具和大文件，对可再生开发缓存提供逐项清理
# 用法: ./deep-storage-cleanup.sh [--dry-run]
#       --dry-run 只报告将删除的路径和大小，不删除任何文件、不调用 simctl。
# 风险: 🟠 高风险（开发环境操作需逐项确认；用户文件只报告）

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "$SCRIPT_DIR/../lib/common.sh"
parse_common_args "$@"

VERSION="1.2.0"
CLEANED_ITEMS=0
USER_HOME="$MAC_OPT_USER_HOME"

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

# 逐项确认。预览模式下只打印将执行的动作并返回 1（不执行）。
# 用法: ask_item "<提示>" "<预览说明>"
ask_item() {
    local prompt="$1"
    local preview="$2"
    if [[ "$DRY_RUN" -eq 1 ]]; then
        log "  [预览] ${preview}"
        return 1
    fi
    read -p "${prompt} (y/N) " -n 1 -r
    echo
    [[ $REPLY =~ ^[Yy]$ ]]
}

# 欢迎信息
clear_screen
cat << "EOF"
╔════════════════════════════════════════╗
║   深度存储清理工具 v1.0                ║
║   清理开发工具和大文件 释放空间        ║
╚════════════════════════════════════════╝
EOF

echo ""
warn "⚠️  此工具仅对可再生开发缓存提供逐项确认"
warn "   下载、项目日志、Docker volumes 和 Time Machine 快照只报告，不自动删除"
if [[ "$DRY_RUN" -eq 1 ]]; then
    warn "   当前为预览模式（--dry-run）：只报告将删除的路径和大小，不做任何修改。"
fi
echo ""

# ============================================
# 1. Xcode 派生数据
# ============================================
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}1. Xcode 派生数据${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

XCODE_DERIVED_DIR="$USER_HOME/Library/Developer/Xcode/DerivedData"
if [ -d "$XCODE_DERIVED_DIR" ]; then
    XCODE_SIZE=$(get_size "$XCODE_DERIVED_DIR")
    warn "  大小: ${XCODE_SIZE}"
    info "  路径: ${XCODE_DERIVED_DIR}"
    echo ""

    if ask_item "是否删除 Xcode 派生数据（可由 Xcode 重新生成）?" \
        "将删除 ${XCODE_DERIVED_DIR} 下全部内容（${XCODE_SIZE}）"; then
        find "$XCODE_DERIVED_DIR" -mindepth 1 -maxdepth 1 -exec rm -rf {} + 2>/dev/null
        log "  ✓ Xcode 派生数据已删除"
        CLEANED_ITEMS=$((CLEANED_ITEMS + 1))
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

XCODE_SIMULATOR_DIR="$USER_HOME/Library/Developer/CoreSimulator"
if [ -d "$XCODE_SIMULATOR_DIR" ]; then
    XCODE_SIMULATOR_SIZE=$(get_size "$XCODE_SIMULATOR_DIR")
    warn "  大小: ${XCODE_SIMULATOR_SIZE}"
    info "  路径: ${XCODE_SIMULATOR_DIR}"
    echo ""

    warn "  ⚠️  将抹掉所有模拟器设备内的已安装应用和数据，不可恢复（设备本身保留）"
    if ask_item "是否抹掉所有 Xcode Simulator 设备的内容和设置?" \
        "将执行 xcrun simctl erase all（抹掉 ${XCODE_SIMULATOR_DIR} 中所有模拟器设备的内容，${XCODE_SIMULATOR_SIZE}）"; then
        xcrun simctl erase all 2>/dev/null
        log "  ✓ Xcode Simulator 设备内容已抹掉"
        CLEANED_ITEMS=$((CLEANED_ITEMS + 1))
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

ANDROID_DIR="$USER_HOME/.android"
ANDROID_AVD_DIR="$ANDROID_DIR/avd"
if [ -d "$ANDROID_DIR" ]; then
    ANDROID_SIZE=$(get_size "$ANDROID_DIR")
    warn "  大小: ${ANDROID_SIZE}"
    info "  路径: ${ANDROID_DIR}"
    echo ""

    if [ -d "$ANDROID_AVD_DIR" ] && [ -n "$(find "$ANDROID_AVD_DIR" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]; then
        AVD_SIZE=$(get_size "$ANDROID_AVD_DIR")
        info "  AVD 镜像目录: ${ANDROID_AVD_DIR} (${AVD_SIZE})"
        warn "  ⚠️  这不是缓存：将永久删除全部 Android 虚拟设备（AVD）镜像、快照和其中的应用数据，"
        warn "     不可恢复，之后需在 Android Studio 中重新创建模拟器"
        if ask_item "确认永久删除全部 AVD 模拟器镜像?" \
            "将永久删除 ${ANDROID_AVD_DIR} 下全部 AVD 模拟器镜像（${AVD_SIZE}）"; then
            find "$ANDROID_AVD_DIR" -mindepth 1 -maxdepth 1 -exec rm -rf {} + 2>/dev/null
            log "  ✓ 全部 AVD 模拟器镜像已删除"
            CLEANED_ITEMS=$((CLEANED_ITEMS + 1))
        else
            info "  - 跳过"
        fi
    else
        info "  没有 AVD 模拟器镜像"
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

    warn "  [仅报告] 未使用镜像、容器和 volume 可能仍包含项目数据。"
    info "  请先分别用 docker image/container/volume ls 核对；本脚本不执行 prune。"
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

LARGE_FILES=$(find "$USER_HOME" -xdev \
    -type d \( -name Library -o -name .ollama -o -name node_modules -o -name .Trash -o -name iCloud \) -prune \
    -o -type f -size +1G -print 2>/dev/null | head -10)

if [ -n "$LARGE_FILES" ]; then
    warn "  发现以下大文件:"
    echo "$LARGE_FILES" | while IFS= read -r file; do
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
# 6. 下载文件夹检查（只报告）
# ============================================
echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}6. 下载文件夹检查（只报告）${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

OLD_DOWNLOADS=$(find "$USER_HOME/Downloads" -type f -mtime +30 2>/dev/null | wc -l | tr -d ' ')
if [ "$OLD_DOWNLOADS" -gt 0 ]; then
    warn "  发现 ${OLD_DOWNLOADS} 个30天以上的文件"

    echo ""
    info "  10个最老的文件:"
    find "$USER_HOME/Downloads" -type f -mtime +30 -exec ls -lh {} + 2>/dev/null | head -10 | awk '{print "    " $9, "  (" $5 ")"}'
    echo ""

    warn "  [仅报告] 文件年龄不能证明可删；请手动确认用途后移到废纸篓。"
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
    CACHE_PATH="$USER_HOME/Library/Caches/$dir"
    if [ -d "$CACHE_PATH" ]; then
        SIZE=$(du -sm "$CACHE_PATH" 2>/dev/null | cut -f1)
        if [ "${SIZE:-0}" -gt 10 ]; then
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
    if [[ "$DRY_RUN" -eq 1 ]]; then
        for item in "${CACHE_TO_CLEAN[@]}"; do
            IFS=':' read -r dir name size <<< "$item"
            log "  [预览] 将清空 ${USER_HOME}/Library/Caches/${dir} 的内容（${name}，约 ${size}MB）"
        done
    elif ask_item "是否清理以上缓存?" ""; then
        for item in "${CACHE_TO_CLEAN[@]}"; do
            IFS=':' read -r dir name size <<< "$item"
            find "$USER_HOME/Library/Caches/$dir" -mindepth 1 -maxdepth 1 -exec rm -rf {} + 2>/dev/null
            log "  ✓ ${name} 已清理"
            CLEANED_ITEMS=$((CLEANED_ITEMS + 1))
        done
    else
        info "  - 跳过"
    fi
else
    info "  ✓ 应用缓存已清理或很小"
fi

# ============================================
# 8. 项目日志文件检查（只报告）
# ============================================
echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}8. 项目日志文件 (>100MB，只报告)${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

info "  扫描项目日志..."
LARGE_LOGS=$(find "$USER_HOME/Documents" -path "*/logs/*.log" -size +100M -exec ls -lh {} + 2>/dev/null | awk '{print $5, $9}')

if [ -n "$LARGE_LOGS" ]; then
    warn "  发现大型日志文件:"
    echo "$LARGE_LOGS" | while read size path; do
        echo "    • ${path} (${size})"
    done
    echo ""
    warn "  [仅报告] 日志可能是审计、故障恢复或业务记录；需按项目核对后手动处理。"
else
    info "  ✓ 没有发现大型日志文件"
fi

# ============================================
# 9. Time Machine 本地快照（只报告）
# ============================================
echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}9. Time Machine 本地快照（只报告）${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

SNAPSHOTS=$(tmutil listlocalsnapshots / 2>/dev/null | wc -l | tr -d ' ')
if [ "${SNAPSHOTS:-0}" -gt 0 ]; then
    warn "  发现 ${SNAPSHOTS} 个本地快照"
    echo ""

    warn "  [仅报告] 快照由 macOS 管理；本脚本不批量删除。"
else
    info "  ✓ 没有本地快照"
fi

# ============================================
# 完成
# ============================================
echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
if [[ "$DRY_RUN" -eq 1 ]]; then
    log "✅ 预览结束：未删除任何文件。确认后可不带 --dry-run 再执行（仍会逐项确认）。"
else
    log "✅ 深度存储清理完成！"
fi
echo ""

if [ "$CLEANED_ITEMS" -gt 0 ]; then
    log "📊 执行了 ${CLEANED_ITEMS} 项清理"
else
    info "未执行任何清理"
fi

echo ""
cat << EOF
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
💡 后续建议
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
1. 定期复核下载文件夹（确认用途后手动移到废纸篓）
2. 删除不需要的 Docker 镜像和容器
3. 清理 Xcode 派生数据（开发后）
4. 检查并删除大文件
5. 检查项目日志文件（不默认视为可删）
6. 定期清理应用缓存

预期释放空间:
  • Xcode: 5-20GB
  • Xcode Simulator: 10-30GB
  • Android AVD 镜像（删除即需重建模拟器）: 5-15GB
  • Docker: 2-10GB
  • 应用缓存: 2-5GB
  • 项目日志: 可能很大（如 100GB+）
  • 实际可回收量取决于你逐项确认的开发缓存
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF

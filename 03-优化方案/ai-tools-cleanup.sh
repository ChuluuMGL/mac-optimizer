#!/bin/bash
# AI工具缓存清理脚本
# 用途: 清理各种AI开发工具的缓存和临时文件
# 用法: ./ai-tools-cleanup.sh [--dry-run]
#       可选: MAC_OPT_PYCACHE_DIRS="/path/a:/path/b" 指定要清理 __pycache__ 的项目目录（默认不清理任何项目目录）
# 风险: 🟡 中风险（缓存可清理；执行历史和模型需额外确认）

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "$SCRIPT_DIR/../lib/common.sh"
parse_common_args "$@"
ensure_work_dirs

VERSION="1.1.0"
# 所有删除都基于 MAC_OPT_USER_HOME，避免在 sudo 下误清理 /var/root。
H="$MAC_OPT_USER_HOME"
# 可选：冒号分隔的项目目录列表，仅在显式设置时清理其中的 __pycache__。
PYCACHE_DIRS="${MAC_OPT_PYCACHE_DIRS:-}"
LOG_FILE="$MAC_OPT_LOG_DIR/ai-cleanup-$(date +%Y%m%d-%H%M%S).log"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log() {
    echo -e "${GREEN}[$(date '+%H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

warn() {
    echo -e "${YELLOW}[$(date '+%H:%M:%S')]${NC} ⚠️  $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[$(date '+%H:%M:%S')]${NC} ❌ $1" | tee -a "$LOG_FILE"
}

info() {
    echo -e "${BLUE}[$(date '+%H:%M:%S')]${NC} ℹ️  $1" | tee -a "$LOG_FILE"
}

# 创建日志目录
ensure_work_dirs

# 欢迎信息
clear_screen
cat << "EOF"
╔════════════════════════════════════════╗
║   AI工具缓存清理工具 v1.0              ║
║   清理AI开发工具缓存 释放空间          ║
╚════════════════════════════════════════╝
EOF

echo ""
log "开始清理AI工具缓存..."
echo ""

if [[ "$DRY_RUN" -eq 1 ]]; then
    warn "当前为预览模式，不会删除文件、清数据库或修改缓存。"
    echo ""
    for dir in \
        "$MAC_OPT_USER_HOME/.ollama" \
        "$MAC_OPT_USER_HOME/.n8n" \
        "$MAC_OPT_USER_HOME/.cursor" \
        "$MAC_OPT_USER_HOME/.cherrystudio" \
        "$MAC_OPT_USER_HOME/.gemini" \
        "$MAC_OPT_USER_HOME/.EasyOCR" \
        "$MAC_OPT_USER_HOME/.zai" \
        "$MAC_OPT_USER_HOME/.trae" \
        "$MAC_OPT_USER_HOME/.trae-aicc"; do
        if [ -d "$dir" ]; then
            log "  [预览] $(basename "$dir"): $(du -sh "$dir" 2>/dev/null | cut -f1)"
        fi
    done
    if [ -n "$PYCACHE_DIRS" ]; then
        IFS=':' read -r -a _pyc_dirs <<< "$PYCACHE_DIRS"
        for dir in "${_pyc_dirs[@]}"; do
            [ -d "$dir" ] || continue
            log "  [预览] ${dir} 下 __pycache__ 目录: $(find "$dir" -type d -name "__pycache__" 2>/dev/null | wc -l | tr -d ' ') 个"
        done
    fi
    echo ""
    log "预览结束。确认后可不带 --dry-run 再执行。"
    exit 0
fi

confirm_or_exit "将清理 AI 工具的可再生缓存；执行历史或模型仍会逐项确认，是否继续？"

# 记录开始时间
START_TIME=$(date +%s)
TOTAL_FREED=0

# ============================================
# 1. Ollama 模型清理
# ============================================
log "[1/10] 检查 Ollama 模型..."

if [ -d "$H/.ollama" ]; then
    OLLAMA_SIZE=$(du -sh "$H/.ollama" 2>/dev/null | cut -f1)
    log "  Ollama 目录大小: ${OLLAMA_SIZE}"

    echo ""
    warn "  ⚠️  Ollama 模型占用空间较大"
    echo "  查看已安装的模型:"
    ollama list 2>/dev/null || echo "  (无法列出模型)"

    echo ""
    info "  如需删除模型，请手动执行:"
    echo "    ollama rm <模型名称>"
    echo "  示例: ollama rm llama2"

    read -p "  是否删除 Ollama 顶层 *.cache 文件（不删除模型）? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        find "$H/.ollama" -maxdepth 1 -name "*.cache" -exec rm -rf {} + 2>/dev/null || true
        log "  ✓ Ollama 缓存已清理"
    fi
else
    info "  - Ollama 未安装"
fi

# ============================================
# 2. n8n 数据清理（增强版）
# ============================================
log "[2/10] 检查 n8n 数据..."

# 检查多个可能的 n8n 数据目录
ALL_N8N_DIRS=()
while IFS= read -r _n8n_dir; do
    [ -n "$_n8n_dir" ] && ALL_N8N_DIRS+=("$_n8n_dir")
done < <(find "$H/Documents" -type d \( -name "n8n" -o -name ".n8n" -o -name "n8n-data" \) 2>/dev/null | head -5)
[ -d "$H/.n8n" ] && ALL_N8N_DIRS+=("$H/.n8n")

if [ ${#ALL_N8N_DIRS[@]} -gt 0 ]; then
    for N8N_DIR in "${ALL_N8N_DIRS[@]}"; do
        if [ -d "$N8N_DIR" ]; then
            N8N_SIZE=$(du -sh "$N8N_DIR" 2>/dev/null | cut -f1)
            log "  n8n 目录: ${N8N_DIR}"
            log "  目录大小: ${N8N_SIZE}"

            # 查找数据库文件
            DB_FILE=$(find "$N8N_DIR" -name "database.sqlite" -type f 2>/dev/null | head -1)

            if [ -n "$DB_FILE" ] && [ -f "$DB_FILE" ]; then
                DB_SIZE=$(du -sh "$DB_FILE" 2>/dev/null | cut -f1)
                warn "  ⚠️  数据库大小: ${DB_SIZE}"

                # 检查数据库完整性
                INTEGRITY=$(sqlite3 "$DB_FILE" "PRAGMA integrity_check;" 2>/dev/null | head -1)
                if [ "$INTEGRITY" != "ok" ]; then
                    error "  ❌ 数据库可能已损坏: $INTEGRITY"
                fi

                # 统计执行记录数
                EXEC_COUNT=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM execution_entity;" 2>/dev/null)
                WORKFLOW_COUNT=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM workflow_entity;" 2>/dev/null)

                info "  工作流数量: ${WORKFLOW_COUNT}"
                info "  执行记录数: ${EXEC_COUNT}"

                if [ "$EXEC_COUNT" -gt 100 ] 2>/dev/null; then
                    echo ""
                    warn "  执行记录较多，建议清理"
                    read -p "  是否清理执行历史（保留工作流）? (y/N) " -n 1 -r
                    echo
                    if [[ $REPLY =~ ^[Yy]$ ]]; then
                        # 备份数据库
                        cp "$DB_FILE" "${DB_FILE}.backup.$(date +%Y%m%d%H%M%S)"

                        # 清理执行数据
                        sqlite3 "$DB_FILE" "DELETE FROM execution_data;" 2>/dev/null
                        sqlite3 "$DB_FILE" "DELETE FROM execution_entity;" 2>/dev/null
                        sqlite3 "$DB_FILE" "VACUUM;" 2>/dev/null

                        NEW_DB_SIZE=$(du -sh "$DB_FILE" 2>/dev/null | cut -f1)
                        log "  ✓ 执行历史已清理，数据库大小: ${NEW_DB_SIZE}"
                    fi
                fi
            fi

            # 日志可能用于审计或故障恢复，只报告数量。
            N8N_OLD_LOGS=$(find "$N8N_DIR" -name "*.log" -mtime +30 -type f 2>/dev/null | wc -l | tr -d ' ')
            info "  [仅报告] n8n 30天以上日志: ${N8N_OLD_LOGS} 个"
        fi
    done
else
    info "  - n8n 未安装"
fi

# ============================================
# 3. Cursor AI 编辑器
# ============================================
log "[3/10] 检查 Cursor AI..."

if [ -d "$H/.cursor" ]; then
    CURSOR_SIZE=$(du -sh "$H/.cursor" 2>/dev/null | cut -f1)
    log "  Cursor 目录大小: ${CURSOR_SIZE}"

    # 清理缓存
    rm -rf "$H/.cursor/Cache" 2>/dev/null
    rm -rf "$H/.cursor/Code Cache" 2>/dev/null
    rm -rf "$H/.cursor/GPUCache" 2>/dev/null

    log "  ✓ Cursor 缓存已清理"
else
    info "  - Cursor 未安装"
fi

# ============================================
# 4. Cherry Studio
# ============================================
log "[4/10] 检查 Cherry Studio..."

if [ -d "$H/.cherrystudio" ]; then
    CHERRY_SIZE=$(du -sh "$H/.cherrystudio" 2>/dev/null | cut -f1)
    log "  Cherry Studio 目录大小: ${CHERRY_SIZE}"

    rm -rf "$H/.cherrystudio/Cache" 2>/dev/null
    rm -rf "$H/.cherrystudio/Code Cache" 2>/dev/null

    log "  ✓ Cherry Studio 缓存已清理"
else
    info "  - Cherry Studio 未安装"
fi

# ============================================
# 5. Google Gemini
# ============================================
log "[5/10] 检查 Google Gemini..."

if [ -d "$H/.gemini" ]; then
    GEMINI_SIZE=$(du -sh "$H/.gemini" 2>/dev/null | cut -f1)
    log "  Gemini 目录大小: ${GEMINI_SIZE}"

    rm -rf "$H/.gemini/Cache" 2>/dev/null

    log "  ✓ Gemini 缓存已清理"
else
    info "  - Gemini 未安装"
fi

# ============================================
# 6. EasyOCR 模型缓存
# ============================================
log "[6/10] 检查 EasyOCR 模型..."

if [ -d "$H/.EasyOCR" ]; then
    EASYOCR_SIZE=$(du -sh "$H/.EasyOCR" 2>/dev/null | cut -f1)
    log "  EasyOCR 目录大小: ${EASYOCR_SIZE}"

    info "  EasyOCR 模型缓存，建议保留"
    read -p "  是否删除全部 EasyOCR 模型（之后需重新下载）? (y/N: 仅清理临时文件) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        find "$H/.EasyOCR" -mindepth 1 -maxdepth 1 -exec rm -rf {} + 2>/dev/null || true
        log "  ✓ EasyOCR 模型已删除"
    else
        find "$H/.EasyOCR" -name "*.tmp" -delete 2>/dev/null || true
        log "  ✓ EasyOCR 临时文件已清理"
    fi
else
    info "  - EasyOCR 未安装"
fi

# ============================================
# 7. ZAI 工具
# ============================================
log "[7/10] 检查 ZAI 工具..."

if [ -d "$H/.zai" ]; then
    ZAI_SIZE=$(du -sh "$H/.zai" 2>/dev/null | cut -f1)
    log "  ZAI 目录大小: ${ZAI_SIZE}"

    rm -rf "$H/.zai/cache" 2>/dev/null
    ZAI_LOGS=$(find "$H/.zai/logs" -maxdepth 1 -name "*.log" -type f 2>/dev/null | wc -l | tr -d ' ')

    log "  ✓ ZAI 缓存已清理"
    info "  [仅报告] ZAI 日志: ${ZAI_LOGS} 个"
else
    info "  - ZAI 未安装"
fi

# ============================================
# 8. Trae IDE
# ============================================
log "[8/10] 检查 Trae IDE..."

if [ -d "$H/.trae" ] || [ -d "$H/.trae-aicc" ]; then
    TRAE_SIZE=$(du -sm "$H/.trae" "$H/.trae-aicc" 2>/dev/null | awk '{sum+=$1} END {print sum+0}')
    log "  Trae IDE 目录大小: ${TRAE_SIZE}MB"

    rm -rf "$H/.trae/cache" 2>/dev/null
    rm -rf "$H/.trae-aicc/cache" 2>/dev/null

    log "  ✓ Trae IDE 缓存已清理"
    info "  [仅报告] Trae IDE 日志已保留"
else
    info "  - Trae IDE 未安装"
fi

# ============================================
# 9. 通用 AI 工具缓存
# ============================================
log "[9/10] 清理通用 AI 工具缓存..."

# 清理 pip AI 包缓存
if command -v pip &> /dev/null; then
    pip cache purge &>/dev/null
    log "  ✓ pip AI 包缓存已清理"
fi

# 清理 conda 环境
if command -v conda &> /dev/null; then
    conda clean --yes --all &>/dev/null
    log "  ✓ conda 缓存已清理"
fi

# ============================================
# 10. 清理其他 AI 相关临时文件
# ============================================
log "[10/10] 清理 AI 相关临时文件..."

# 清理 Python __pycache__：仅针对通过 MAC_OPT_PYCACHE_DIRS 显式指定的项目目录。
if [ -n "$PYCACHE_DIRS" ]; then
    IFS=':' read -r -a _pyc_dirs <<< "$PYCACHE_DIRS"
    for dir in "${_pyc_dirs[@]}"; do
        if [ -d "$dir" ]; then
            find "$dir" -type d -name "__pycache__" -prune -exec rm -rf {} + 2>/dev/null || true
            log "  ✓ ${dir} 下的 Python 缓存已清理"
        else
            info "  - ${dir} 不存在，跳过"
        fi
    done
else
    info "  - 未设置 MAC_OPT_PYCACHE_DIRS，跳过项目 __pycache__ 清理"
fi

# 计算耗时
END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))
MINUTES=$((ELAPSED / 60))
SECONDS=$((ELAPSED % 60))

# 完成
echo ""
log "✅ AI工具缓存清理完成！"
echo ""
cat << EOF
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📊 清理摘要
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  耗时: ${MINUTES}分${SECONDS}秒
  清理项目: 10项 AI 工具
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

💡 提示:
  • 部分AI模型建议保留（如Ollama、EasyOCR）
  • 定期清理日志和缓存
  • 大型模型根据需要删除
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📄 详细日志: ${LOG_FILE}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF

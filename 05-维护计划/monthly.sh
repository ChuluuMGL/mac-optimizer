#!/usr/bin/env bash
# Mac月度维护脚本
# 用途: 生成月度检查报告，并复用安全的一键优化流程。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "$SCRIPT_DIR/../lib/common.sh"

VERSION="1.3.0"
parse_common_args "$@"
ensure_work_dirs

LOG_FILE="$MAC_OPT_LOG_DIR/monthly-$(date +%Y%m%d-%H%M%S).log"
REPORT_FILE="$MAC_OPT_LOG_DIR/monthly-report-$(date +%Y%m%d).md"

clear_screen
cat << "EOF"
Mac 月度维护
EOF

echo "时间: $(date)" | tee -a "$LOG_FILE"
echo "版本: $VERSION" | tee -a "$LOG_FILE"
if [[ "$DRY_RUN" -eq 1 ]]; then
  warn "当前为预览模式，不会删除文件或修改设置。"
fi
echo "" | tee -a "$LOG_FILE"

confirm_or_exit "将生成检查报告并执行月度维护流程，是否继续？"

ONE_CLICK_ARGS=(--yes)
if [[ "$DRY_RUN" -eq 1 ]]; then
  ONE_CLICK_ARGS+=(--dry-run)
fi
if [[ "$SAFE_MODE" -eq 1 ]]; then
  ONE_CLICK_ARGS+=(--safe)
fi

log "[1/3] 生成系统检查报告"
bash "$MAC_OPT_ROOT/01-检查脚本/full-check.sh" --yes | tee -a "$LOG_FILE"

log "[2/3] 执行常规维护"
bash "$MAC_OPT_ROOT/04-自动化脚本/one-click-optimization.sh" "${ONE_CLICK_ARGS[@]}" | tee -a "$LOG_FILE"

log "[3/3] 写入月度摘要"
cat > "$REPORT_FILE" << EOF
# Mac 月度维护报告

**日期**: $(date '+%Y年%m月%d日')
**模式**: $([[ "$DRY_RUN" -eq 1 ]] && echo "预览" || echo "执行")

---

## 执行内容

- 已生成系统检查报告
- 已运行常规维护流程
- 数据卷可用空间: $(disk_available)
- 数据卷使用率: $(disk_capacity_percent)

---

## 相关文件

- 日志: $LOG_FILE
- 月度摘要: $REPORT_FILE

---

## 下次建议

- 每周使用 \`bash 04-自动化脚本/quick-optimization.sh --dry-run\` 预览一次。
- 每月使用本脚本复查一次。
- 深度清理前先运行对应脚本并逐项确认。
EOF

log "月度维护流程结束。"
log "报告: $REPORT_FILE"

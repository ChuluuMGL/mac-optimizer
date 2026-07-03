#!/usr/bin/env bash
# 只读验证脚本
# 用途: 检查工具文件、脚本语法、数据卷状态和最近日志。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "$SCRIPT_DIR/../lib/common.sh"

VERSION="1.3.0"
parse_common_args "$@"
ensure_work_dirs
LOG_FILE="$MAC_OPT_LOG_DIR/verify-$(date +%Y%m%d-%H%M%S).log"

log "开始只读验证。"
log "版本: $VERSION"
log "项目目录: $MAC_OPT_ROOT"
log "数据卷: $(data_volume_mount)"
log "数据卷可用空间: $(disk_available)"
log "数据卷使用率: $(disk_capacity_percent)"

REQUIRED_FILES=(
  "lib/common.sh"
  "01-检查脚本/full-check.sh"
  "04-自动化脚本/one-click-optimization.sh"
  "04-自动化脚本/quick-optimization.sh"
  "04-自动化脚本/rollback.sh"
  "05-维护计划/monthly.sh"
  "README.md"
)

for file in "${REQUIRED_FILES[@]}"; do
  if [[ -f "$MAC_OPT_ROOT/$file" ]]; then
    log "文件存在: $file"
  else
    error "缺少文件: $file"
    exit 1
  fi
done

SHELL_FILES=()
while IFS= read -r shell_file; do
  SHELL_FILES+=("$shell_file")
done < <(find "$MAC_OPT_ROOT" -maxdepth 3 -name "*.sh" -print)
bash -n "${SHELL_FILES[@]}"
log "脚本语法检查通过。"

if [[ -d "$MAC_OPT_LOG_DIR" ]]; then
  log "最近日志:"
  find "$MAC_OPT_LOG_DIR" -type f -maxdepth 1 -print 2>/dev/null | sort | tail -5 | tee -a "$LOG_FILE"
fi

log "只读验证结束。"

#!/usr/bin/env bash
# Mac月度维护脚本
# 用途: 编排只读诊断、安全缓存维护和最终验证。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "$SCRIPT_DIR/../lib/common.sh"

VERSION="1.4.0"
parse_common_args "$@"
ensure_work_dirs
LOG_FILE="$MAC_OPT_LOG_DIR/monthly-$(date +%Y%m%d-%H%M%S).log"

clear_screen
log "开始月度维护编排。"
log "版本: $VERSION"

log "[1/3] 生成最新只读诊断报告。"
MAC_OPT_NO_CLEAR=1 bash "$MAC_OPT_ROOT/01-检查脚本/full-check.sh" --yes | tee -a "$LOG_FILE"

log "[2/3] 运行安全维护。"
ARGS=(--safe)
[[ "$DRY_RUN" -eq 1 ]] && ARGS+=(--dry-run)
[[ "$ASSUME_YES" -eq 1 ]] && ARGS+=(--yes)
MAC_OPT_NO_CLEAR=1 bash "$MAC_OPT_ROOT/04-自动化脚本/one-click-optimization.sh" "${ARGS[@]}" | tee -a "$LOG_FILE"

log "[3/3] 只读验证。"
MAC_OPT_NO_CLEAR=1 bash "$MAC_OPT_ROOT/04-自动化脚本/verify.sh" | tee -a "$LOG_FILE"

log "月度维护编排结束。废纸篓、下载文件、广泛日志和高风险开发数据均未自动删除。"

#!/usr/bin/env bash
# Mac快速优化脚本
# 用途: 强制安全模式的日常缓存维护入口。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "$SCRIPT_DIR/../lib/common.sh"

VERSION="1.4.2"
parse_common_args "$@"

ARGS=(--safe)
[[ "$DRY_RUN" -eq 1 ]] && ARGS+=(--dry-run)
[[ "$ASSUME_YES" -eq 1 ]] && ARGS+=(--yes)

info "快速优化固定使用安全模式；不会清空废纸篓、删除下载文件或修改设置。"
exec bash "$SCRIPT_DIR/one-click-optimization.sh" "${ARGS[@]}"

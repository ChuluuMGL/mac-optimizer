#!/usr/bin/env bash
# lib/agent_dirs.sh — 只读：统计 AI Agent / 开发者工具目录体积并按风险分级。
#
# 本文件只做 du/find 统计，绝不删除、移动或读取任何文件内容。
# 兼容 macOS 自带 bash 3.2（不使用关联数组、mapfile 等）。
#
# 分级：
#   safe     安全可清  —— 可由工具/包管理器重建的缓存或日志
#   confirm  需确认    —— 可能含用户数据、未提交改动或需要重新下载的大文件
#   keep     不要动    —— 凭据、记忆、活动数据库、Agent 配置；报告里只列体积，永不建议删除
#
# 可通过环境变量在测试中覆盖：MAC_OPT_USER_HOME、MAC_OPT_TMP_DIR、MAC_OPT_SYSTEM_LIB。

_ad_home() { printf '%s' "${MAC_OPT_USER_HOME:-$HOME}"; }

# 路径展示：默认把 $HOME 换成 ~（--full-paths 时保留）。
_ad_display() {
  local p="$1" home
  home="$(_ad_home)"
  local tilde='~'
  if [[ "${FULL_PATHS:-0}" == "1" ]]; then
    printf '%s' "$p"
  else
    printf '%s' "${p/#$home/$tilde}"
  fi
}

# 成功且数值有效才返回 KB；失败、超时、无输出或无效输出都返回 ?。
# 必须检查退出状态：du 权限错误也可能输出不完整的数值小计。
_ad_size_kb() {
  local output kb
  if output="$(scan_checked du -sk "$1" 2>/dev/null)"; then
    kb="${output%%[[:space:]]*}"
    if [[ "$kb" =~ ^[0-9]+$ ]]; then
      printf '%s' "$kb"
      return 0
    fi
  fi
  printf '?'
}

# 未知大小排在已知大小之前；已知大小降序。完整消费输入，避免 SIGPIPE。
_ad_sort_sizes() {
  awk -F'\t' '{print ($1 ~ /^[0-9]+$/ ? 1 : 0) "\t" $0}' |
    sort -t$'\t' -k1,1n -k2,2nr | cut -f2-
}

# 输出一行：KB 或 ?<TAB>class<TAB>展示路径<TAB>说明。路径不存在则跳过。
_ad_emit() {
  local class="$1" path="$2" note="$3" kb
  [[ -e "$path" ]] || return 0
  kb="$(_ad_size_kb "$path")"
  [[ "$kb" != '?' ]] || note+="；体积未知（扫描失败、超时或结果无效）"
  printf '%s\t%s\t%s\t%s\n' "$kb" "$class" "$(_ad_display "$path")" "$note"
}

# 枚举目录下体积最大的前 N 个子项并按名称分级。
_ad_emit_top_children() {
  local dir="$1" limit="$2" default_class="$3" default_note="$4"
  local line kb path name class note output
  [[ -d "$dir" ]] || return 0
  if [[ ! -r "$dir" || ! -x "$dir" ]]; then
    printf '?\tconfirm\t%s\t%s\n' "$(_ad_display "$dir")" "无法枚举子项（权限不足）；体积未知，列表不完整，需重新检查"
    return 0
  fi
  # 空目录没有待测子项；避免把未展开的 * 传给 du。
  local children=("$dir"/*)
  [[ ${#children[@]} -gt 0 ]] || return 0
  [[ -e "${children[0]}" || -L "${children[0]}" ]] || return 0
  # 批量扫描仍共享一次超时预算。失败时任何小计都可能不完整，
  # 只报告父目录未知且需确认，不把部分子项误列为可清理的完整 Top N。
  if ! output="$(scan_checked du -sk "${children[@]}" 2>/dev/null)" \
    || ! printf '%s\n' "$output" | awk '$1 !~ /^[0-9]+$/ || NF < 2 {invalid=1} END {exit invalid}'; then
    printf '?\tconfirm\t%s\t%s\n' "$(_ad_display "$dir")" "子项扫描失败、超时或结果无效；体积未知，列表不完整，需重新检查"
    return 0
  fi
  printf '%s\n' "$output" | sort -rn | awk -v n="$limit" 'NR <= n' | while IFS= read -r line; do
    kb="${line%%[[:space:]]*}"
    path="${line#*[[:space:]]}"
    path="${path#"${path%%[![:space:]]*}"}"
    [[ "$kb" =~ ^[0-9]+$ && -n "$path" ]] || continue
    name="${path##*/}"
    class="$default_class"
    note="$default_note"
    case "$dir:$name" in
      */.cache:uv)   class="safe"; note="uv 包缓存；可用 \`uv cache clean\` 清理，会按需重新下载" ;;
      */.cache:npm|*/.cache:node-gyp|*/.cache:pip|*/.cache:pnpm|*/.cache:yarn)
                     class="safe"; note="包管理器缓存；可由对应工具重建" ;;
      */.cache:huggingface|*/.cache:torch|*/.cache:whisper|*/.cache:lm-studio)
                     class="confirm"; note="模型权重缓存；清理后需重新下载，先确认不再使用" ;;
      */Library/Caches:com.apple.*)
                     class="confirm"; note="系统组件缓存；通常不必手动处理" ;;
    esac
    printf '%s\t%s\t%s\t%s\n' "$kb" "$class" "$(_ad_display "$path")" "$note"
  done
}

# ~/.codex/worktrees 内的 node_modules：输出前 5 项（未知优先）+ 合计。
_ad_emit_worktree_node_modules() {
  local root="$1/.codex/worktrees" total=0 kb path count=0 lines="" paths incomplete=0
  [[ -d "$root" ]] || return 0
  if ! paths="$(scan_checked find "$root" -maxdepth 6 -name node_modules -type d -prune -print 2>/dev/null)"; then
    incomplete=1
  fi
  while IFS= read -r path; do
    [[ -n "$path" ]] || continue
    kb="$(_ad_size_kb "$path")"
    if [[ "$kb" == '?' ]]; then
      incomplete=1
    else
      total=$((total + kb))
    fi
    count=$((count + 1))
    lines+="$kb"$'\t'"$path"$'\n'
  done <<< "$paths"
  [[ "$count" -gt 0 || "$incomplete" -eq 1 ]] || return 0
  printf '%s' "$lines" | _ad_sort_sizes | awk 'NR <= 5' | while IFS=$'\t' read -r kb path; do
    [[ -n "$path" ]] || continue
    printf '%s\t%s\t%s\t%s\n' "$kb" "safe" "$(_ad_display "$path")" "worktree 依赖目录；可由 lockfile 重建，清理前确认该 worktree 没有正在运行的任务"
  done
  local note="仅为合计行，不重复计入上面的单项"
  if [[ "$incomplete" -eq 1 ]]; then
    total='?'
    note+="；扫描失败、超时或大小未知，列表或合计不完整，需重新检查"
  fi
  printf '%s\t%s\t%s\t%s\n' "$total" "safe" "[合计] ~/.codex/worktrees 下已发现 ${count} 个 node_modules" "$note"
}

# agent_dirs_scan: 输出未排序的明细行 "KB 或 ?<TAB>class<TAB>path<TAB>note"。
# 先列保护项，再做可选的容量排名。
agent_dirs_scan() {
  local home tmp_dir sys_lib f
  home="$(_ad_home)"
  tmp_dir="${MAC_OPT_TMP_DIR:-/private/tmp}"
  sys_lib="${MAC_OPT_SYSTEM_LIB:-/Library}"

  # --- 不要动：凭据、记忆、活动数据库、Agent 配置（只统计体积，不读取内容） ---
  _ad_emit keep "$home/.codex/auth.json"     "Codex 登录凭据；永不删除、不读取内容"
  _ad_emit keep "$home/.codex/memories"      "Codex 记忆；永不删除"
  _ad_emit keep "$home/.codex/secrets"       "密钥目录；永不删除"
  _ad_emit keep "$home/.codex/config.toml"   "Codex 配置"
  for f in "$home"/.codex/*.sqlite "$home"/.codex/*.sqlite-wal "$home"/.codex/*.sqlite-shm; do
    _ad_emit keep "$f" "活动 sqlite（WAL 模式）；应用运行中不要动"
  done
  _ad_emit keep "$home/.gemini/oauth_creds.json"      "Gemini 登录凭据"
  _ad_emit keep "$home/.gemini/google_accounts.json"  "Gemini 账号信息"
  _ad_emit keep "$home/.ollama/id_ed25519"            "Ollama 私钥"
  _ad_emit keep "$home/.hermes"              "Hermes 配置/技能；永不删除"
  _ad_emit keep "$home/.openclaw"            "OpenClaw 配置；永不删除"

  # --- Codex ---
  _ad_emit confirm "$home/.codex/worktrees"  "Codex worktree 检出；可能含未提交/未推送的改动，逐个 git status 确认后再处理"
  _ad_emit confirm "$home/.codex/sessions"   "会话历史；删除后无法 resume/回看，确认不再需要再归档"
  _ad_emit confirm "$home/.codex/artifacts"  "Agent 生成的产物；确认已另存或不再需要"
  _ad_emit_worktree_node_modules "$home"

  # --- 其他 Agent / 开发者目录 ---
  _ad_emit safe    "$home/.pm2/logs"         "pm2 运行日志；可用 \`pm2 flush\` 清空，不要动 ~/.pm2 其余文件（dump.pm2 等）"
  _ad_emit safe    "$home/.npm/_cacache"     "npm 缓存；可用 \`npm cache clean --force\` 重建"
  _ad_emit_top_children "$home/.cache" 8 confirm "未识别的 ~/.cache 子目录；确认所属工具后再处理"
  _ad_emit confirm "$home/.gemini"           "Gemini CLI 数据（含历史/tmp）；其中登录凭据见“不要动”，仅在确认后清理 tmp/history"
  _ad_emit confirm "$home/.ollama"           "Ollama 模型库；可用 \`ollama rm <模型>\` 逐个移除，需重新下载；私钥见“不要动”"

  # --- Xcode / 模拟器 ---
  _ad_emit safe    "$home/Library/Developer/Xcode/DerivedData" "Xcode 构建中间产物；Xcode 会自动重建"
  for f in "$home"/Library/Developer/Xcode/*DeviceSupport; do
    _ad_emit safe  "$f" "设备调试符号；连接设备时会重新生成，旧系统版本可删"
  done
  _ad_emit confirm "$home/Library/Developer/CoreSimulator/Devices" "模拟器设备数据（含应用数据）；先用 \`xcrun simctl delete unavailable\` 预览"
  _ad_emit safe    "$home/Library/Developer/CoreSimulator/Caches" "模拟器缓存；可重建"
  _ad_emit confirm "$sys_lib/Developer/CoreSimulator" "模拟器运行时镜像（runtimes）；用 \`xcrun simctl runtime list\` 查看，用 \`xcrun simctl runtime delete\` 移除，需重新下载"

  # --- 系统缓存/临时 ---
  _ad_emit_top_children "$home/Library/Caches" 8 safe "应用缓存；关闭对应应用后可清，应用会自动重建"
  _ad_emit confirm "$tmp_dir"                "临时目录（默认 /private/tmp）；可能有正在使用的 socket/会话目录，仅处理重启后仍存在的旧文件"
}

_ad_human_kb() {
  [[ "$1" =~ ^[0-9]+$ ]] || { printf '未知'; return 0; }
  awk -v k="$1" 'BEGIN {
    if (k >= 1048576) printf "%.1fG", k/1048576;
    else if (k >= 1024) printf "%.0fM", k/1024;
    else printf "%dK", k
  }'
}

# format_agent_dirs: 读 agent_dirs_scan 的输出，渲染为按分级分组的 Markdown 表。
# 参数：$1 = 明细文本（可选；缺省时现场扫描）
format_agent_dirs() {
  local rows="${1:-}" cls label kb class path note any=0
  [[ -n "$rows" ]] || rows="$(agent_dirs_scan || true)"
  if [[ -z "$rows" ]]; then
    printf '未发现受支持的 Agent / 开发者目录。\n'
    return 0
  fi
  if printf '%s\n' "$rows" | awk -F'\t' '$1 !~ /^[0-9]+$/ {found=1} END {exit !found}'; then
    printf '> 部分目录体积未知（扫描失败、超时或结果不完整），不代表 0K；未知项优先列出，请重新检查后再决定是否清理。\n\n'
  fi
  for cls in safe confirm keep; do
    case "$cls" in
      safe)    label="安全可清" ;;
      confirm) label="需确认" ;;
      keep)    label="不要动" ;;
    esac
    local block
    block="$(printf '%s\n' "$rows" | awk -F'\t' -v c="$cls" '$2 == c' | _ad_sort_sizes || true)"
    [[ -n "$block" ]] || continue
    any=1
    printf '**%s**\n\n| 体积 | 路径 | 说明 |\n|------|------|------|\n' "$label"
    printf '%s\n' "$block" | while IFS=$'\t' read -r kb class path note; do
      printf '| %s | `%s` | %s |\n' "$(_ad_human_kb "$kb")" "$path" "$note"
    done
    printf '\n'
  done
  [[ "$any" -eq 1 ]] || printf '未发现受支持的 Agent / 开发者目录。\n'
}

# agent_dirs_json_summary: 把明细按分级汇总成 JSON 片段（路径数组）。
agent_dirs_json_summary() {
  local rows="${1:-}" cls first
  [[ -n "$rows" ]] || { printf '{"safe_to_clean":[],"needs_confirmation":[],"do_not_touch":[]}'; return 0; }
  printf '{'
  first=1
  for cls in safe:safe_to_clean confirm:needs_confirmation keep:do_not_touch; do
    [[ "$first" -eq 1 ]] || printf ','
    first=0
    printf '"%s":[' "${cls#*:}"
    printf '%s\n' "$rows" | awk -F'\t' -v c="${cls%%:*}" '$2 == c && $3 !~ /^\[合计\]/ {
      p = $3; gsub(/\\/, "\\\\", p); gsub(/"/, "\\\"", p);
      printf "%s\"%s\"", (n++ ? "," : ""), p
    }'
    printf ']'
  done
  printf '}'
}

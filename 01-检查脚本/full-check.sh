#!/usr/bin/env bash
# Mac全系统检查脚本
# 用途: 只读检查系统状态并生成报告。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "$SCRIPT_DIR/../lib/common.sh"

VERSION="1.3.0"
parse_common_args "$@"
ensure_work_dirs

DATE="$(date +%Y-%m-%d)"
REPORT_FILE="$MAC_OPT_LOG_DIR/check-report-$DATE.md"
LOG_FILE="$MAC_OPT_LOG_DIR/check-$DATE.log"
DATA_FILE="$MAC_OPT_DATA_DIR/check-$DATE.json"
LATEST_DATA_FILE="$MAC_OPT_DATA_DIR/check-latest.json"
RECOMMENDATIONS_FILE="$MAC_OPT_DATA_DIR/recommendations-latest.json"
DATA_VOLUME="$(data_volume_mount)"

log "开始 Mac 系统全面检查。"
log "数据卷: $DATA_VOLUME"

DISK_USAGE="$(disk_capacity_number)"
FREE_SPACE_GB="$(df -k "$DATA_VOLUME" | awk 'NR==2 {printf "%.1f", $4/1024/1024}')"
SCORE=100

if [[ "$DISK_USAGE" -gt 90 ]]; then
  SCORE=$((SCORE - 20))
elif [[ "$DISK_USAGE" -gt 80 ]]; then
  SCORE=$((SCORE - 10))
elif [[ "$DISK_USAGE" -gt 70 ]]; then
  SCORE=$((SCORE - 5))
fi

if awk "BEGIN { exit !($FREE_SPACE_GB < 20) }"; then
  SCORE=$((SCORE - 15))
elif awk "BEGIN { exit !($FREE_SPACE_GB < 50) }"; then
  SCORE=$((SCORE - 10))
fi

MEMORY_GB="$(sysctl -n hw.memsize | awk '{printf "%.1f", $1/1024/1024/1024}')"

cat > "$REPORT_FILE" << EOF
# Mac 系统检查报告

**检查时间**: $(date '+%Y年%m月%d日 %H:%M:%S')
**工具版本**: $VERSION
**系统版本**: $(sw_vers -productVersion)
**计算机型号**: $(system_profiler SPHardwareDataType 2>/dev/null | awk -F: '/Model Name/ {print $2; exit}' | xargs)
**数据卷**: $DATA_VOLUME

---

## 1. 系统概况

| 项目 | 规格 |
|------|------|
| CPU | $(cpu_summary) |
| 内存 | ${MEMORY_GB} GB |
| 数据卷总容量 | $(df -h "$DATA_VOLUME" | awk 'NR==2 {print $2}') |
| 数据卷可用 | $(disk_available) |
| 数据卷使用率 | $(disk_capacity_percent) |
| 电池循环 | $(system_profiler SPPowerDataType 2>/dev/null | awk -F: '/Cycle Count/ {print $2; exit}' | xargs || echo "N/A") |
| 电池状态 | $(system_profiler SPPowerDataType 2>/dev/null | awk -F: '/Condition/ {print $2; exit}' | xargs || echo "N/A") |

---

## 2. 磁盘使用分析

### 用户目录占用 Top 10

\`\`\`
$(du -sh "$MAC_OPT_USER_HOME/Documents" "$MAC_OPT_USER_HOME/Downloads" "$MAC_OPT_USER_HOME/Desktop" "$MAC_OPT_USER_HOME/Movies" "$MAC_OPT_USER_HOME/Music" "$MAC_OPT_USER_HOME/Pictures" "$MAC_OPT_USER_HOME/Library" 2>/dev/null | sort -hr | head -10)
\`\`\`

### 大文件 Top 20

\`\`\`
$(find "$MAC_OPT_USER_HOME" -type f -size +1G -not -path "*/Library/*" -not -path "*/.ollama/*" -not -path "*/node_modules/*" -exec ls -lh {} \; 2>/dev/null | awk '{print $5, $9}' | head -20)
\`\`\`

### 项目日志文件 (>100MB)

\`\`\`
$(find "$MAC_OPT_USER_HOME/Documents" -path "*/logs/*.log" -size +100M -exec ls -lh {} \; 2>/dev/null | awk '{print $5, $9}' | head -10)
\`\`\`

### SQLite 数据库文件 (>100MB)

\`\`\`
$(find "$MAC_OPT_USER_HOME" -name "*.sqlite" -size +100M -not -path "*/Library/*" -exec ls -lh {} \; 2>/dev/null | awk '{print $5, $9}' | head -10)
\`\`\`

### node_modules 汇总

\`\`\`
$(find "$MAC_OPT_USER_HOME/Documents" -maxdepth 4 -name "node_modules" -type d 2>/dev/null | xargs -I {} du -sh {} 2>/dev/null | sort -hr | head -10)
\`\`\`

---

## 3. 内存和进程

### 内存概况

\`\`\`
$(vm_stat | perl -ne '/Pages free:\s+(\d+)/ and $free=$1; /Pages inactive:\s+(\d+)/ and $inactive=$1; /Pages active:\s+(\d+)/ and $active=$1; /Pages speculative:\s+(\d+)/ and $spec=$1; /Pages wired:\s+(\d+)/ and $wired=$1; END { $ps=4096; printf "可用: %.2f GB\n非活跃: %.2f GB\n活跃: %.2f GB\nSpeculative: %.2f GB\nWired: %.2f GB", ($free+$spec)*$ps/1024/1024/1024, $inactive*$ps/1024/1024/1024, $active*$ps/1024/1024/1024, $spec*$ps/1024/1024/1024, $wired*$ps/1024/1024/1024 }')
\`\`\`

### 内存使用最高进程 Top 10

\`\`\`
$(ps aux | sort -rk 4 | head -10 | awk '{printf "%-6s %6s %s\n", $3"%", $4"%", $11}')
\`\`\`

### CPU 使用最高进程 Top 10

\`\`\`
$(ps aux | sort -rk 3 | head -10 | awk '{printf "%-6s %6s %s\n", $3"%", $4"%", $11}')
\`\`\`

---

## 4. 缓存和日志

### 应用缓存占用 Top 10

\`\`\`
$(du -sh "$MAC_OPT_USER_HOME/Library/Caches"/* 2>/dev/null | sort -hr | head -10)
\`\`\`

### 大日志文件

\`\`\`
$(find "$MAC_OPT_USER_HOME/Library/Logs" -name "*.log" -size +50M 2>/dev/null | head -10)
\`\`\`

---

## 5. 启动和服务

### 用户 LaunchAgents 数量

\`\`\`
$(launchctl list | grep -v "0x\|com.apple\|pid" | wc -l | xargs)
\`\`\`

### 登录项和服务建议

运行:

\`\`\`bash
"$MAC_OPT_ROOT/03-优化方案/startup-manager.sh"
\`\`\`

---

## 6. Time Machine

### 本地快照

\`\`\`
$(tmutil listlocalsnapshots / 2>/dev/null | head -10)
\`\`\`

---

## 7. 健康评分

| 项目 | 状态 | 说明 |
|------|------|------|
| 数据卷健康 | $([[ "$DISK_USAGE" -lt 80 ]] && echo "良好" || echo "需要清理") | 使用率: $DISK_USAGE% |
| 可用空间 | $(awk "BEGIN { exit !($FREE_SPACE_GB > 50) }" && echo "充足" || echo "偏紧") | ${FREE_SPACE_GB}GB 可用 |
| 内存容量 | ${MEMORY_GB}GB | 按当前硬件读取 |
| 总体评分 | $SCORE/100 | $([[ "$SCORE" -ge 80 ]] && echo "优秀" || ([[ "$SCORE" -ge 60 ]] && echo "良好" || echo "需要优化")) |

---

## 8. 风险分级优化建议

这些建议都是可选项。建议先看本报告，再决定是否执行。高风险项只提示，不会被 \`one-click\` 或 \`quick\` 自动执行。

| 风险 | 建议 | 适用场景 | 推荐动作 | 是否自动执行 |
|------|------|----------|----------|--------------|
| 低风险 | 清理浏览器缓存、旧日志、包管理器缓存 | 常规维护、缓存偏大 | 先运行 \`one-click-optimization.sh --dry-run\` 预览 | 可选执行 |
| 低风险 | 刷新 DNS 缓存 | 网络解析异常、网页打不开 | 通过常规维护脚本执行，管理员权限不足会跳过 | 可选执行 |
| 中风险 | 清理废纸篓和下载目录旧文件 | 确认文件不再需要 | 先检查预览输出，必要时用 \`--safe\` 跳过下载目录 | 需要确认 |
| 中风险 | 调整 Dock 和动画设置 | 想减少界面等待 | 可通过 \`rollback.sh\` 恢复 | 需要确认 |
| 高风险 | 删除 Time Machine 本地快照 | 磁盘极度紧张且已确认备份策略 | 只在深度清理脚本中逐项确认 | 不自动执行 |
| 高风险 | 清理 Docker volumes、模拟器数据、开发环境大缓存 | 开发者存储占用很高 | 先备份或确认项目不依赖这些数据 | 不自动执行 |
| 高风险 | 禁用系统服务或修改电源休眠策略 | 明确知道影响范围 | 单独执行进阶脚本并保留回滚路径 | 不自动执行 |

---

## 9. 建议操作

1. 先预览常规优化:

\`\`\`bash
bash "$MAC_OPT_ROOT/04-自动化脚本/one-click-optimization.sh" --dry-run
\`\`\`

2. 确认后执行:

\`\`\`bash
bash "$MAC_OPT_ROOT/04-自动化脚本/one-click-optimization.sh"
\`\`\`

3. 深度清理前先逐项确认:

\`\`\`bash
bash "$MAC_OPT_ROOT/03-优化方案/deep-storage-cleanup.sh"
\`\`\`

---

## 10. 原始数据

JSON 数据:

\`\`\`
$DATA_FILE
\`\`\`

**报告生成时间**: $(date)
EOF

cat > "$DATA_FILE" << EOF
{
  "date": "$DATE",
  "data_volume": "$DATA_VOLUME",
  "disk_usage_percent": $DISK_USAGE,
  "free_space_gb": "$FREE_SPACE_GB",
  "score": $SCORE,
  "memory_gb": "$MEMORY_GB",
  "cpu_cores": $(sysctl -n hw.ncpu)
}
EOF

cp "$DATA_FILE" "$LATEST_DATA_FILE"

cat > "$RECOMMENDATIONS_FILE" << EOF
{
  "date": "$DATE",
  "policy": "diagnose_first_optional_optimization",
  "low_risk": [
    "browser_cache",
    "old_logs",
    "package_manager_cache",
    "dns_cache"
  ],
  "medium_risk": [
    "trash",
    "old_downloads",
    "dock_animation_preferences"
  ],
  "high_risk_not_automatic": [
    "time_machine_local_snapshots",
    "docker_volumes",
    "simulator_data",
    "system_services",
    "power_sleep_policy"
  ]
}
EOF

log "检查完成。"
log "报告: $REPORT_FILE"
log "数据: $DATA_FILE"
log "建议: $RECOMMENDATIONS_FILE"

echo ""
echo "查看完整报告:"
echo "  open \"$REPORT_FILE\""

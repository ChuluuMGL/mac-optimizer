# Mac Optimizer Skill

> **面向 AI Agent 的 Mac 诊断与优化 Skill**  
> 一个开源 Agent Skill，用于安全地生成 Mac 本地诊断报告、按需检查网络连通性、预览存储清理动作，并按风险等级给出可选优化建议。
>
> 由 **Chuluu** 创建和维护。

中文 | [English](README.md)

[![AI Skill](https://img.shields.io/badge/AI%20Skill-mac--optimizer-0E5E43)](./SKILL.md)
[![Version](https://img.shields.io/badge/version-0.2.0-green)](./skill.json)
[![License: MIT](https://img.shields.io/badge/license-MIT-yellow)](./LICENSE)
[![by Chuluu](https://img.shields.io/badge/by-Chuluu-0E5E43)](https://github.com/ChuluuMGL)
[![Workflow](https://img.shields.io/badge/workflow-diagnosis--first-purple)](./SKILL.md)
[![Safety](https://img.shields.io/badge/safety-dry--run--first-blue)](./references/safety-policy.md)

[GitHub 仓库](https://github.com/ChuluuMGL/mac-optimizer) | [仓库元信息](./.github/repository-metadata.json) | [合成任务输入](./examples/) | [脱敏示例报告](./examples/basic-maintenance/sample-report.md) | [报告审阅清单](./references/report-review-checklist.md) | [发布指南](./references/release-guide.md) | [CHANGELOG.md](./CHANGELOG.md) | [测试矩阵](./TESTING.md) | [License](./LICENSE)

## About

面向 macOS 的诊断优先维护 Agent Skill，用于安全生成诊断报告、预览清理动作，并按风险等级给出可选优化建议。

## 产品定位

Mac Optimizer 不是“直接清理器”，而是一个诊断报告优先的 Mac 维护工具包。它适合做日常缓存清理、日志清理、启动项检查、开发工具缓存检查和月度维护。

核心规则：

- 诊断报告优先。没有诊断数据时，优化脚本会拒绝执行并提示先运行检查。
- 优化建议是可选项，不会因为报告发现问题就自动清理。
- 建议按低风险、中风险、高风险分级。
- 高风险项只提示，不进入 `one-click` 或 `quick` 自动流程。
- 所有正式清理前都建议先跑 `--dry-run`。

## 推荐用法

```bash
git clone https://github.com/ChuluuMGL/mac-optimizer.git
cd mac-optimizer
scripts/install.sh codex
```

先做只读检查：

```bash
bash ./01-检查脚本/full-check.sh
```

网络探测默认关闭，因为它会访问外部站点。需要在报告中加入 DNS、网关、直连 HTTPS 和系统代理的短时只读检查时，显式添加 `--network`：

```bash
bash ./01-检查脚本/full-check.sh --network
```

报告只显示连通结果和耗时，不显示本地 IP、Wi-Fi 名称或代理地址；网络结果不计入磁盘健康分，也不会更改 DNS、代理或网络设置。

0.2.0 起，全面检查还会只读统计 AI Agent 与开发者工具目录（`~/.codex/{worktrees,sessions,artifacts}`、worktree 内的 `node_modules`、`~/.pm2/logs`、`~/.cache`、`~/.npm`、`~/.gemini`、`~/.ollama`、Xcode DeviceSupport/DerivedData、CoreSimulator、`~/Library/Caches` 前几名、`/private/tmp`），并分成三档：

| 分级 | 含义 |
|---|---|
| 安全可清 | 可由工具或包管理器重建的缓存、日志（例如 DerivedData、pm2 日志、worktree 内的 node_modules） |
| 需确认 | 可能含未提交改动、会话历史，或需要重新下载的大文件（例如 worktrees、sessions、`~/.gemini`、`~/.ollama`、模拟器运行时、`/private/tmp`） |
| 不要动 | 凭据、`auth.json`、memories、活动 sqlite、Hermes/OpenClaw 配置；只列体积，永远不建议删除 |

这一部分只做统计，不删除任何内容；结果同时写入 `recommendations-latest.json` 的 `agent_dirs` 字段。

诊断报告会生成风险分级建议。看完报告后，预览一键优化会做什么：

```bash
bash ./04-自动化脚本/one-click-optimization.sh --dry-run
```

确认后执行：

```bash
bash ./04-自动化脚本/one-click-optimization.sh
```

自动确认模式适合已经看过预览后的场景：

```bash
bash ./04-自动化脚本/one-click-optimization.sh --yes
```

保守模式只执行可再生缓存维护，同时保留废纸篓、下载文件、广泛日志及应用/开发数据：

```bash
bash ./04-自动化脚本/one-click-optimization.sh --safe
```

界面设置和 DNS 刷新必须单独显式启用：

```bash
bash ./04-自动化脚本/one-click-optimization.sh --tune-ui
bash ./04-自动化脚本/one-click-optimization.sh --flush-dns
bash ./04-自动化脚本/one-click-optimization.sh --truncate-v2ray-log
```

## 作为 Skill 使用

核心结构遵循开放的 Agent Skills 形态：一个包含 `SKILL.md` 的目录，并可选包含 `references/`、`scripts/` 和本地工具。多数兼容 Agent 只需要把整个目录放到它们会扫描的 skills 目录下。

安装脚本：

```bash
scripts/install.sh codex
scripts/install.sh claude
scripts/install.sh cursor
scripts/install.sh custom "$HOME/.config/agents/skills"
```

打包成可分享 ZIP：

```bash
python3 ./scripts/package_runtime_skill.py
```

输出文件会生成在 `dist/mac-optimizer-skill.zip`。
同时也会生成版本化文件，例如 `dist/mac-optimizer-skill-0.2.0.zip`。

### 安装与兼容性

| Agent/runtime | 建议安装路径 | 状态 |
|---|---|---|
| Codex | `~/.codex/skills/mac-optimizer/` | 维护者已测试 |
| Claude Code | `./.claude/skills/mac-optimizer/` | 预期兼容 |
| Cursor | `./.cursor/skills/mac-optimizer/` | 预期兼容 |
| Trae | `./.trae/skills/mac-optimizer/` | 预期兼容 |
| Antigravity | `./.agent/skills/mac-optimizer/` | 预期兼容 |
| OpenClaw | OpenClaw 文档指定的 workspace 或 user skills root | 预期兼容 |
| Hermes | `~/.hermes/skills/mac-optimizer/` 或已配置的 skills root | 预期兼容 |
| Gemini CLI | `./.gemini/skills/mac-optimizer/` | 预期兼容 |
| Kimi Code CLI | `./.kimi/skills/mac-optimizer/` | 预期兼容 |

`agents/openai.yaml` 是 Codex 专用 UI 元数据；其他 Agent 可以忽略这个文件，直接读取 `SKILL.md`。

### 让 AI Agent 帮你安装

可以直接对支持代码操作的 AI Agent 说：

> 帮我安装 mac-optimizer，仓库地址：https://github.com/ChuluuMGL/mac-optimizer

## 入口脚本

- `01-检查脚本/full-check.sh`: 只读系统检查和报告。
- `lib/agent_dirs.sh`: 由 `full-check.sh` 调用的只读 Agent/开发者目录体积统计与三档分级。
- `lib/network_diagnostics.sh`: 由 `full-check.sh --network` 显式调用的只读网络探测。
- `04-自动化脚本/quick-optimization.sh`: 日常快速维护。
- `04-自动化脚本/one-click-optimization.sh`: 常规维护入口。
- `04-自动化脚本/verify.sh`: 只读验证工具本身是否完整。
- `04-自动化脚本/rollback.sh`: 恢复本工具修改过的系统偏好。
- `05-维护计划/monthly.sh`: 月度检查加维护编排。
- `03-优化方案/`: 进阶脚本，逐项交互确认。`deep-storage-cleanup.sh`、`power-optimization.sh`、`ai-tools-cleanup.sh` 支持 `--dry-run`：只列出将删除的路径和大小、将修改的 `pmset` 设置，不做任何修改。不带 `--dry-run` 时，每个破坏性步骤单独确认（例如 Android 一项会永久删除全部 AVD 模拟器镜像）。项目 `__pycache__` 只清理 `MAC_OPT_PYCACHE_DIRS` 中显式列出的目录。
- `examples/basic-maintenance/sample-report.md`: 脱敏示例诊断报告。
- `references/report-review-checklist.md`: 报告审阅和风险判断清单。
- `references/release-guide.md`: 发版前检查、打 tag 和 Release 上传说明。

## 安全边界

- 默认会在执行前询问。
- 全面检查默认只扫描、只报告；Agent 目录分级（安全可清 / 需确认 / 不要动）不会触发任何删除，清理动作必须显式确认并使用对应参数。
- `--dry-run` 只预览，不删除文件、不修改设置。
- 日志和数据保存在当前项目的 `logs/` 和 `data/`。
- 自动流程只清理可再生缓存和 7 天前的 Crashpad；下载目录、废纸篓、广泛日志、应用容器和开发数据只报告、逐项确认。
- Time Machine 快照、Docker volumes、模拟器数据、系统服务和电源策略属于高风险项，只在报告和进阶脚本中提示。

## License 与发布信息

Mac Optimizer Skill 使用 [MIT License](./LICENSE) 发布。

- Copyright: `Copyright (c) 2026 Chuluu`
- 维护者: [ChuluuMGL](https://github.com/ChuluuMGL)
- 仓库: [https://github.com/ChuluuMGL/mac-optimizer](https://github.com/ChuluuMGL/mac-optimizer)
- 发布说明: [NOTICE](./NOTICE)

# Mac Optimizer Skill

> **面向 AI Agent 的 Mac 诊断与优化 Skill**  
> 一个开源 Agent Skill，用于安全地生成 Mac 本地诊断报告、预览存储清理动作，并按风险等级给出可选优化建议。
>
> 由 **Chuluu** 创建和维护。

中文 | [English](README.md)

[![AI Skill](https://img.shields.io/badge/AI%20Skill-mac--optimizer-0E5E43)](./SKILL.md)
[![Version](https://img.shields.io/badge/version-0.1.3-green)](./skill.json)
[![License: MIT](https://img.shields.io/badge/license-MIT-yellow)](./LICENSE)
[![by Chuluu](https://img.shields.io/badge/by-Chuluu-0E5E43)](https://github.com/ChuluuMGL)
[![Workflow](https://img.shields.io/badge/workflow-diagnosis--first-purple)](./SKILL.md)
[![Safety](https://img.shields.io/badge/safety-dry--run--first-blue)](./references/safety-policy.md)

[GitHub 仓库](https://github.com/ChuluuMGL/mac-optimizer) | [合成任务输入](./examples/) | [脱敏示例报告](./examples/basic-maintenance/sample-report.md) | [报告审阅清单](./references/report-review-checklist.md) | [CHANGELOG.md](./CHANGELOG.md) | [测试矩阵](./TESTING.md) | [License](./LICENSE)

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

保守模式会跳过系统偏好和管理员权限动作：

```bash
bash ./04-自动化脚本/one-click-optimization.sh --safe
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
- `04-自动化脚本/quick-optimization.sh`: 日常快速维护。
- `04-自动化脚本/one-click-optimization.sh`: 常规维护入口。
- `04-自动化脚本/verify.sh`: 只读验证工具本身是否完整。
- `04-自动化脚本/rollback.sh`: 恢复本工具修改过的系统偏好。
- `05-维护计划/monthly.sh`: 月度检查加维护编排。
- `examples/basic-maintenance/sample-report.md`: 脱敏示例诊断报告。
- `references/report-review-checklist.md`: 报告审阅和风险判断清单。

## 安全边界

- 默认会在执行前询问。
- `--dry-run` 只预览，不删除文件、不修改设置。
- 日志和数据保存在当前项目的 `logs/` 和 `data/`。
- 下载目录、废纸篓、Time Machine、本地模拟器和 Docker 清理都应先预览或逐项确认。
- Time Machine 快照、Docker volumes、模拟器数据、系统服务和电源策略属于高风险项，只在报告和进阶脚本中提示。

## License 与发布信息

Mac Optimizer Skill 使用 [MIT License](./LICENSE) 发布。

- Copyright: `Copyright (c) 2026 Chuluu`
- 维护者: [ChuluuMGL](https://github.com/ChuluuMGL)
- 仓库: [https://github.com/ChuluuMGL/mac-optimizer](https://github.com/ChuluuMGL/mac-optimizer)
- 发布说明: [NOTICE](./NOTICE)

# Mac Optimizer Skill

一个面向 macOS 的本地维护 Skill：先诊断，再给建议，最后由用户选择是否优化。

Created and maintained by **Chuluu**.

[English README](README.md) · [测试说明](TESTING.md) · [Skill 入口](SKILL.md)

## 产品定位

Mac Optimizer 不是“直接清理器”，而是一个诊断报告优先的 Mac 维护工具包。它适合做日常缓存清理、日志清理、启动项检查、开发工具缓存检查和月度维护。

核心规则：

- 诊断报告优先。没有诊断数据时，优化脚本会拒绝执行并提示先运行检查。
- 优化建议是可选项，不会因为报告发现问题就自动清理。
- 建议按低风险、中风险、高风险分级。
- 高风险项只提示，不进入 `one-click` 或 `quick` 自动流程。
- 所有正式清理前都建议先跑 `--dry-run`。

## 推荐用法

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

安装到默认本地 Skill 目录：

```bash
bash ./scripts/install.sh
```

打包成可分享 ZIP：

```bash
python3 ./scripts/package_runtime_skill.py
```

输出文件会生成在 `dist/mac-optimizer-skill.zip`。

## 入口脚本

- `01-检查脚本/full-check.sh`: 只读系统检查和报告。
- `04-自动化脚本/quick-optimization.sh`: 日常快速维护。
- `04-自动化脚本/one-click-optimization.sh`: 常规维护入口。
- `04-自动化脚本/verify.sh`: 只读验证工具本身是否完整。
- `04-自动化脚本/rollback.sh`: 恢复本工具修改过的系统偏好。
- `05-维护计划/monthly.sh`: 月度检查加维护编排。

## 安全边界

- 默认会在执行前询问。
- `--dry-run` 只预览，不删除文件、不修改设置。
- 日志和数据保存在当前项目的 `logs/` 和 `data/`。
- 下载目录、废纸篓、Time Machine、本地模拟器和 Docker 清理都应先预览或逐项确认。
- Time Machine 快照、Docker volumes、模拟器数据、系统服务和电源策略属于高风险项，只在报告和进阶脚本中提示。

## iPhone

iPhone 优化是另一套体系。iOS 不允许脚本直接清系统缓存或应用缓存。可做的是备份、照片/文件整理、存储诊断、系统设置建议和连接后的只读信息检查。见 `iPhone-Optimization-Guide.md`。

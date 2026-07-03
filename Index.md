# Mac 优化系统索引

## 立即开始

- [快速开始](00-系统概览/Quick-Start.md)
- [系统概览](00-系统概览/README.md)
- [安装与集成](INSTALL.md)
- [Obsidian 集成](Obsidian-Integration-Guide.md)

## 核心脚本

- `01-检查脚本/full-check.sh`: 只读检查并生成报告。
- `04-自动化脚本/one-click-optimization.sh`: 常规维护入口。
- `04-自动化脚本/quick-optimization.sh`: 快速维护。
- `04-自动化脚本/verify.sh`: 验证工具完整性。
- `04-自动化脚本/rollback.sh`: 恢复系统偏好。
- `05-维护计划/monthly.sh`: 月度维护。

## 进阶脚本

- `03-优化方案/ai-tools-cleanup.sh`: AI 工具缓存检查和清理。
- `03-优化方案/deep-storage-cleanup.sh`: 开发工具和大文件逐项清理。
- `03-优化方案/power-optimization.sh`: 电源设置优化。
- `03-优化方案/startup-manager.sh`: 启动项检查。
- `03-优化方案/system-services-optimization.sh`: 系统服务设置优化。

## 使用建议

第一次先运行诊断:

```bash
bash ./01-检查脚本/full-check.sh
```

报告会给出低/中/高风险建议。看完报告后再预览:

```bash
bash ./04-自动化脚本/one-click-optimization.sh --dry-run
```

确认后再运行:

```bash
bash ./04-自动化脚本/one-click-optimization.sh
```

高风险项只提示，不会被一键脚本自动执行。

iPhone 优化见 [iPhone 优化指南](iPhone-Optimization-Guide.md)。

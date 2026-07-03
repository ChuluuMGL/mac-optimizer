# 系统概览

Mac Optimizer 现在按三段式工作:

1. 诊断: `bash 01-检查脚本/full-check.sh`
2. 建议: 在诊断报告中查看低/中/高风险建议
3. 预览: `bash 04-自动化脚本/one-click-optimization.sh --dry-run`
4. 执行: `bash 04-自动化脚本/one-click-optimization.sh`

## 当前定位

这是本地维护工具，不是系统加速器。它主要释放缓存和旧日志占用，减少部分界面动画等待，并帮助你发现大文件、旧日志、开发工具缓存和启动项。

没有诊断报告时，优化脚本会拒绝执行。高风险建议只提示，不自动运行。

## 推荐流程

```bash
bash ./01-检查脚本/full-check.sh
bash ./04-自动化脚本/one-click-optimization.sh --dry-run
bash ./04-自动化脚本/one-click-optimization.sh
bash ./04-自动化脚本/verify.sh
```

## 模式

- `--dry-run`: 预览，不执行删除或设置修改。
- `--yes`: 跳过确认，适合已经看过预览后的重复维护。
- `--safe`: 跳过系统偏好和管理员权限动作。

## 回滚

如果想恢复 Dock、动画、Siri/Spotlight、诊断和电源相关设置:

```bash
./04-自动化脚本/rollback.sh
```

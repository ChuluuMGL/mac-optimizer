# Mac 优化系统概览

## 当前版本

版本: 1.3.0

## 核心入口

- `README.md`: 总说明。
- `00-系统概览/Quick-Start.md`: 快速开始。
- `01-检查脚本/full-check.sh`: 只读系统检查。
- `04-自动化脚本/one-click-optimization.sh`: 常规维护入口。
- `04-自动化脚本/quick-optimization.sh`: 快速维护。
- `04-自动化脚本/verify.sh`: 只读验证。
- `04-自动化脚本/rollback.sh`: 设置回滚。
- `05-维护计划/monthly.sh`: 月度维护。

## 推荐流程

```bash
bash ./01-检查脚本/full-check.sh
bash ./04-自动化脚本/one-click-optimization.sh --dry-run
bash ./04-自动化脚本/one-click-optimization.sh
bash ./04-自动化脚本/verify.sh
```

## 安全设计

- 默认执行前确认。
- 支持 `--dry-run` 预览。
- 支持 `--safe` 保守模式。
- 日志和数据保存在项目目录的 `logs/` 和 `data/`。
- 有 `rollback.sh` 恢复被修改过的偏好设置。

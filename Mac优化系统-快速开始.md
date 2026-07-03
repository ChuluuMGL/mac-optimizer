# Mac 优化系统快速开始

## 第一次使用

在项目目录运行:

```bash
bash ./01-检查脚本/full-check.sh
bash ./04-自动化脚本/one-click-optimization.sh --dry-run
```

确认预览内容后:

```bash
bash ./04-自动化脚本/one-click-optimization.sh
```

## 日常维护

```bash
bash ./01-检查脚本/full-check.sh
bash ./04-自动化脚本/quick-optimization.sh --dry-run
bash ./04-自动化脚本/quick-optimization.sh
```

优化脚本需要先有诊断报告；诊断报告会列出低/中/高风险建议。

## 月度维护

```bash
bash ./05-维护计划/monthly.sh --dry-run
bash ./05-维护计划/monthly.sh
```

## 保守模式

如果只想清理缓存和日志，不想改系统偏好或触发管理员权限动作:

```bash
bash ./04-自动化脚本/one-click-optimization.sh --safe
```

## 回滚设置

```bash
./04-自动化脚本/rollback.sh
```

## 验证工具完整性

```bash
bash ./04-自动化脚本/verify.sh
```

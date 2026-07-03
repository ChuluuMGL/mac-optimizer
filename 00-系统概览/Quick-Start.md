# Mac 优化快速开始

## 三步走

1. 只读检查:

```bash
bash ./01-检查脚本/full-check.sh
```

2. 预览优化:

```bash
bash ./04-自动化脚本/one-click-optimization.sh --dry-run
```

3. 确认执行:

```bash
bash ./04-自动化脚本/one-click-optimization.sh
```

## 常用命令

快速维护:

```bash
bash ./01-检查脚本/full-check.sh
bash ./04-自动化脚本/quick-optimization.sh
```

月度维护:

```bash
bash ./05-维护计划/monthly.sh
```

`quick` 和 `one-click` 都要求先有诊断报告。第一次或隔了一段时间使用时，先跑 `full-check`。

只读验证:

```bash
bash ./04-自动化脚本/verify.sh
```

恢复设置:

```bash
./04-自动化脚本/rollback.sh
```

## 模式

- `--dry-run`: 只预览，不删除文件、不改设置。
- `--yes`: 跳过确认。
- `--safe`: 跳过系统偏好和管理员权限动作。

## 建议

第一次一定先用 `--dry-run`。看到将清理的内容后，再决定是否执行。

# Obsidian 集成指南

Obsidian 适合承载说明、报告和维护记录；实际清理仍建议在终端执行。

## 推荐结构

```text
你的Vault/
├── Mac优化系统/        # 指向本项目的符号链接
├── Mac优化记录/
└── Mac优化任务/
```

## 创建链接

```bash
cd /path/to/your-obsidian-vault
ln -s /path/to/Mac-Optimizer "Mac优化系统"
```

## 建议工作流

每次维护按这个顺序记录:

1. 执行检查: `bash ./01-检查脚本/full-check.sh`
2. 执行预览: `bash ./04-自动化脚本/one-click-optimization.sh --dry-run`
3. 确认后执行: `bash ./04-自动化脚本/one-click-optimization.sh`
4. 验证工具: `bash ./04-自动化脚本/verify.sh`

## 记录模板

```markdown
# Mac 优化记录

日期:
执行模式: 预览 / 执行 / 安全模式
检查报告:
优化日志:

## 发现的问题

- 

## 本次处理

- 

## 下次关注

- 
```

## 注意

不要在 Obsidian 里直接运行不熟悉的清理命令。先在终端使用 `--dry-run` 看清楚会发生什么。

# 安装与集成

这个工具包可以直接在当前项目目录运行，也可以链接到 Obsidian vault 里阅读。

## 方式 1: 直接使用

进入项目目录后运行:

```bash
bash ./01-检查脚本/full-check.sh
bash ./04-自动化脚本/one-click-optimization.sh --dry-run
```

确认预览内容后再执行:

```bash
bash ./04-自动化脚本/one-click-optimization.sh
```

## 方式 2: 链接到 Obsidian

在你的 vault 中创建符号链接:

```bash
cd /path/to/your-obsidian-vault
ln -s /path/to/Mac-Optimizer "Mac优化系统"
```

之后可以在 Obsidian 中打开 `Mac优化系统/README.md`。

## 方式 3: 复制文档

如果只想在 Obsidian 中看说明，可以复制这些文件:

```bash
mkdir -p /path/to/your-obsidian-vault/Mac优化文档
cp README.md INSTALL.md /path/to/your-obsidian-vault/Mac优化文档/
cp -R 00-系统概览 /path/to/your-obsidian-vault/Mac优化文档/
```

## 验证安装

```bash
bash ./04-自动化脚本/verify.sh
```

## 安全建议

- 第一次使用先运行 `--dry-run`。
- 不确定时使用 `--safe`。
- 自动化定时任务建议先运行一段时间的预览模式。

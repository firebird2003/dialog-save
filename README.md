# dialog-save

OpenClaw 对话自动保存技能，将对话保存为 Markdown 文件，支持 Obsidian 笔记库查看。

## 版本

**v2.6.0** (2026-03-20)

## 快速安装

```bash
bash <(curl -sL https://raw.githubusercontent.com/firebird2003/dialog-save/main/install.sh)
```

## 主要功能

- **自动保存对话**: 自动监控并保存所有 OpenClaw 对话
- **Obsidian 集成**: 保存为 Markdown，支持在 Obsidian 中查看和编辑
- **iCloud 同步**: 支持 iCloud 同步到其他设备
- **多代理支持**: 自动扫描所有代理的会话
- **硬链接支持**: 解决 Obsidian 无法识别软链接的问题

## 目录结构

```
{obsidianRoot}/
├── claw-对话/        # 对话历史
├── claw-配置/        # 代理配置文件（链接）
└── claw-工作区/      # 共享工作区（链接）
```

## 新功能：硬链接支持

v2.6.0 新增硬链接支持：

- **软链接**: 兼容性好，但 Obsidian 可能无法识别
- **硬链接**: Obsidian 可直接识别，文件可在 Obsidian 中编辑

## 使用方法

```bash
# 安装
bash scripts/manage.sh install

# 查看状态
bash scripts/manage.sh status

# 立即保存
bash scripts/manage.sh save-now

# 查看已保存
bash scripts/manage.sh saved
```

## 更新日志

详见 [CHANGELOG.md](CHANGELOG.md)

## License

MIT
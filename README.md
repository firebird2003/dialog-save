# dialog-save

将 OpenClaw 对话自动保存为 Markdown 文件，支持 Obsidian 笔记库查看和 iCloud 同步。

## 一键安装/升级

```bash
bash <(curl -sL https://raw.githubusercontent.com/firebird2003/dialog-save/main/install.sh)
```

## 功能特性

- 📝 **对话保存**：解析 OpenClaw session 文件，保存真实对话内容
- 📁 **目录结构**：claw-对话、claw-配置、claw-工作区 三目录分离
- 🔗 **软链接管理**：在 Obsidian 中直接查看代理配置文件
- 📦 **项目保存**：保存项目成果到独立目录，支持版本化
- 🔄 **自动监控**：定时检测新对话，自动保存
- 🧹 **内容清理**：自动移除工具调用结果

## 目录结构

```
{obsidianRoot}/
├── claw-对话/                    # 对话历史
│   └── 管理者@yejimaca2141/
│       └── 260317/
│           ├── 2603171800+对话主题.md
│           └── 项目-xxx/
│
├── claw-配置/                    # 代理配置文件（软链接）
│   ├── 管理者/ → ~/.openclaw/workspace/
│   └── ...
│
└── claw-工作区/                  # 共享工作区（软链接）
    └── shared/ → ~/agents/shared/
```

## 快速开始

```bash
# 完整初始化（首次使用）
bash scripts/manage.sh init

# 这会创建：
# - ~/agents/ 目录结构
# - claw-对话、claw-配置、claw-工作区 目录
# - 代理配置软链接
```

## 命令行

```bash
# 初始化与链接
bash scripts/manage.sh init         # 完整初始化
bash scripts/manage.sh links        # 创建软链接
bash scripts/manage.sh links-status # 查看链接状态
bash scripts/manage.sh link-agent <名> <路径>  # 添加代理链接

# 对话保存
bash scripts/manage.sh save-now     # 立即保存
bash scripts/manage.sh saved        # 查看已保存

# 项目保存
bash scripts/manage.sh project-save <项目> <主题> [版本]
bash scripts/manage.sh project-list
```

## 在 Obsidian 中查看代理配置

1. 打开 `claw-配置/` 目录
2. 点击代理名称
3. 查看 SOUL.md、JOB.md 等配置文件

## 更新日志

### v2.4.0 (2026-03-17)
- 新增软链接管理功能
- 新增目录初始化
- 新增迁移命令
- 支持 claw-对话、claw-配置、claw-工作区 三目录结构

### v2.3.0 (2026-03-17)
- 新增项目文件夹功能
- 新增版本化保存

## GitHub

https://github.com/firebird2003/dialog-save
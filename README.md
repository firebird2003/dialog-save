# dialog-save

将 OpenClaw 对话自动保存为 Markdown 文件，支持 Obsidian 笔记库查看和 iCloud 同步。

## 一键安装/升级

```bash
bash <(curl -sL https://raw.githubusercontent.com/firebird2003/dialog-save/main/install.sh)
```

- **未安装**：自动克隆并进入配置菜单
- **已安装**：询问是更新还是重新安装
- 不会因目录已存在、缺少依赖等问题中断

## 交互菜单

运行安装命令后，进入交互菜单：

```
╔════════════════════════════════════════╗
║  dialog-save v2.2.0                    ║
║  OpenClaw 对话保存技能                 ║
╚════════════════════════════════════════╝

请选择操作：

  1) 安装/重新安装    - 安装依赖、配置、激活
  2) 修改配置        - 更改设置
  3) 启动服务        - 启动 WebDAV + 自动监控
  4) 停止服务        - 停止所有服务
  5) 查看状态        - 查看配置和服务状态
  6) 立即保存        - 保存当前对话
  7) 查看已保存      - 查看已保存的对话列表
  8) 检查更新        - 检查并更新到最新版本
  9) 更新日志        - 查看版本更新记录
  0) 卸载            - 移除技能和数据
  q) 退出
```

## 功能特性

- 📝 **实际对话保存**：解析 OpenClaw session 文件，保存真实对话内容
- 🔄 **自动监控**：定时检测新对话，自动保存
- 📊 **增量保存**：追踪已处理的对话，避免重复
- 🎯 **智能话题检测**：自动从对话中提取主题作为文件名
- 🧹 **Metadata 清理**：自动移除 Sender/Conversation info 等元数据
- 🗂️ **iCloud 兼容**：目录结构兼容 iCloud/Obsidian 同步

## 目录结构

```
Obsidian笔记库/
├── 管理者@yejimaca2141/    # 代理名@主机名
│   └── 260317/             # YYMMDD
│       ├── 2603171457+测试新建会话_abc12345.md
│       └── 2603171500+对话保存技能配置_def67890.md
└── 其他笔记.md
```

## 保存机制

### 自动模式（推荐）
- 自动监控并保存所有对话
- 增量保存，避免重复
- 无需用户提示

### 手动模式
- 需要说"存入本地目录"或"保存对话"
- 适合选择性保存

## 命令行快捷方式

```bash
# 进入菜单
bash ~/.openclaw/workspace/skills/dialog-save/scripts/manage.sh

# 常用命令
bash scripts/manage.sh install      # 安装/重新安装
bash scripts/manage.sh config       # 修改配置
bash scripts/manage.sh start        # 启动服务
bash scripts/manage.sh stop         # 停止服务
bash scripts/manage.sh status       # 查看状态
bash scripts/manage.sh save-now     # 立即保存
bash scripts/manage.sh saved        # 查看已保存
bash scripts/manage.sh update       # 检查更新
bash scripts/manage.sh uninstall    # 卸载
```

## 示例输出

```markdown
---
date: 2026-03-17
time: 14:57
agent: 管理者
host: yejimaca2141
topic: 测试新建会话
project: null
tags: ["对话"]
created: 2026-03-17T14:57:45+08:00
updated: 2026-03-17T14:57:45+08:00
---

# 测试新建会话

## 2026-03-17 14:57

**用户：**
测试新建会话

**代理：**
你好！我看到你在测试新会话。
```

## 更新日志

### v2.2.0 (2026-03-17)
- 改进安装体验：单行命令支持安装/升级
- 智能处理目录已存在的情况
- 依赖问题不会中断流程，仅警告

### v2.0.0 (2026-03-17)
- 新增实际对话保存功能：解析 OpenClaw session 文件
- 自动保存模式：定时监控并保存新对话
- 增量保存：追踪已处理的对话，避免重复
- 智能话题检测：自动从对话中提取主题

### v1.3.0 (2026-03-16)
- 目录名格式改为 `代理名@主机名`
- 新增保存机制选项

## GitHub

https://github.com/firebird2003/dialog-save
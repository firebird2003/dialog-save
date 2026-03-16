# dialog-save 技能

将用户与代理的对话自动保存为 Markdown 文件，支持 Obsidian 笔记库查看和多主机 WebDAV 同步。

## 目录结构

```
Obsidian笔记库/                      # 主目录
├── 管理者@yejimaca2141/             # 代理名@主机名（兼容iCloud同步）
│   └── 260316/                      # YYMMDD
│       ├── 2603162058+对话保存.md
│       └── 项目名/                   # 项目目录
│           └── 2603162100+招聘.md
└── 其他笔记.md
```

**目录名格式**：`代理名@主机名`（使用 `@` 符号分隔，兼容 iCloud/Obsidian 同步）

## 保存机制

### 自动模式（saveMode: auto）
- 自动保存所有对话
- 无需用户提示
- 适合需要完整记录的场景

### 手动模式（saveMode: manual）
- 需要用户说"存入本地目录"或"保存对话"才保存
- 支持智能话题识别
- 适合选择性保存的场景

## 触发条件

### 强制保存（手动模式）
- "存入本地目录"
- "保存对话"
- "存档"

### 自动询问（手动模式）
- 话题切换检测
- 会话跨自然日
- 长时间无响应（>2小时）

## 保存流程

1. 识别主题（5-10字）
2. 创建目录：`主目录/代理名@主机名/YYMMDD/`
3. 生成文件：`YYMMDDhhmm+主题.md`
4. 写入 frontmatter + 内容

## 文件格式

```markdown
---
date: 2026-03-16
time: 21:00
agent: 管理者
host: yejimaca2141
topic: 对话保存技能配置
project: null
tags: [对话, 技能配置]
created: 2026-03-16T21:00:00+08:00
updated: 2026-03-16T21:00:00+08:00
---

# 对话保存技能配置

## 2026-03-16 21:00

**用户：**
消息内容...

**代理：**
回复内容...
```

## 时间处理

- 永远使用上海时间（GMT+8）
- 不使用 UTC

## 配置文件

```json
{
  "version": "1.3.0",
  "obsidianRoot": "/path/to/obsidian/vault",
  "webdav": {
    "enabled": true,
    "port": 8080
  },
  "agent": {
    "name": "管理者",
    "host": "yejimaca2141"
  },
  "saveMode": "manual",
  "mode": "local",
  "autoStart": true
}
```

## iCloud 兼容说明

- 目录名使用 `@` 符号分隔（如 `管理者@yejimaca2141`）
- 避免使用中间子目录
- 与现有 iCloud 同步结构兼容
- 防止同步冲突导致目录消失
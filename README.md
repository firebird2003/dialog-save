# dialog-save

将 OpenClaw 对话自动保存为 Markdown 文件，支持 Obsidian 笔记库查看和 iCloud 同步。

## 一键安装/升级

```bash
bash <(curl -sL https://raw.githubusercontent.com/firebird2003/dialog-save/main/install.sh)
```

## 功能特性

- 📝 **对话保存**：解析 OpenClaw session 文件，保存真实对话内容
- 🔄 **自动监控**：定时检测新对话，自动保存
- 📁 **项目文件夹**：保存项目成果到独立目录，支持版本化
- 🔢 **版本化保存**：文件名包含版本号，保留历史版本
- 🧹 **内容清理**：自动移除工具调用结果，只保留文字对话
- 🗂️ **iCloud 兼容**：目录结构兼容 iCloud/Obsidian 同步

## 目录结构

```
Obsidian笔记库/
├── 管理者@yejimaca2141/
│   └── 260317/                      # YYMMDD
│       ├── 2603171800+对话主题.md    # 对话保存
│       └── 项目-新建代理/            # 项目文件夹
│           ├── 问题1-代理配置-v1.md  # 项目成果（版本化）
│           └── 问题1-代理配置-v2.md  # 新版本保留旧版本
└── 其他笔记.md
```

## 两种保存类型

### 1. 对话保存（自动）
- 自动监控并保存所有对话
- 格式：`YYMMDDHHMM+话题.md`
- 增量保存，避免重复

### 2. 项目成果保存（手动）
- 保存项目方案、阶段性成果
- 保存到项目文件夹，带版本号
- 格式：`{主题}-v{版本号}.md`

## 命令行

```bash
# 进入菜单
bash scripts/manage.sh

# 对话保存
bash scripts/manage.sh save-now        # 立即保存对话
bash scripts/manage.sh saved           # 查看已保存的对话

# 项目保存
bash scripts/manage.sh project-save <项目名> <主题> [版本]
echo "内容..." | bash scripts/manage.sh project-save 项目名 主题

# 示例
echo "# 分析报告..." | bash scripts/manage.sh project-save 新建代理 问题1-代理配置
bash scripts/manage.sh project-save 新建代理 问题1-代理配置 v1

# 项目列表
bash scripts/manage.sh project-list
bash scripts/manage.sh project-versions 新建代理

# 其他命令
bash scripts/manage.sh status          # 查看状态
bash scripts/manage.sh config          # 修改配置
bash scripts/manage.sh update          # 检查更新
```

## 使用场景

### 保存项目成果
当你与代理讨论一个复杂项目，生成方案或分析报告时：

```bash
# 方式1：通过管道
echo "# 问题1分析

分析内容..." | bash scripts/manage.sh project-save 新建代理 问题1-代理配置

# 方式2：从文件读取
cat report.md | bash scripts/manage.sh project-save 新建代理 分析报告
```

### 保留版本历史
每次保存同一主题时，版本号自动递增：
```
问题1-代理配置-v1.md
问题1-代理配置-v2.md  # 更新后保留v1
```

## 文件格式

### 对话保存
```markdown
---
date: 2026-03-17
time: 18:12
agent: 管理者
host: yejimaca2141
topic: 现在对话保存技能
tags: ["对话"]
---

# 现在对话保存技能

## 2026-03-17 18:12

**用户：**
现在对话保存技能是否已经开启自动保存状态？

**代理：**
是的，对话保存技能已开启自动保存状态。
```

### 项目成果
```markdown
---
date: 2026-03-17
time: 18:21
agent: 管理者
host: yejimaca2141
project: 新建代理
topic: 问题1-代理配置
version: v1
tags: ["项目成果", "新建代理"]
type: project
---

# 问题1-代理配置 (v1)

内容...
```

## 更新日志

### v2.3.0 (2026-03-17)
- 新增项目文件夹功能：保存项目成果到独立目录
- 新增版本化保存：文件名包含版本号，保留历史版本
- 区分两种保存类型：对话保存（自动）vs 项目成果（手动）
- 新增命令：project-save, project-list, project-versions

### v2.2.0 (2026-03-17)
- 改进话题提取：智能提取关键词
- 文件名简化：移除 session_id 后缀
- 内容清理：移除工具调用和结果

### v2.1.0 (2026-03-17)
- 改进安装体验：单行命令支持安装/升级

## GitHub

https://github.com/firebird2003/dialog-save
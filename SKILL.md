# dialog-save 技能

将 OpenClaw 对话自动保存为 Markdown 文件，支持 Obsidian 笔记库查看和 iCloud 同步。

## 一键安装/升级

```bash
bash <(curl -sL https://raw.githubusercontent.com/firebird2003/dialog-save/main/install.sh)
```

## 功能特点

- **对话保存**：解析 OpenClaw session 文件，保存真实对话内容
- **自动监控**：定时检测新对话，自动保存
- **项目文件夹**：保存项目成果到独立目录
- **版本化保存**：文件名包含版本号，保留历史版本
- **内容清理**：自动移除工具调用结果
- **iCloud 兼容**：目录结构兼容 iCloud/Obsidian 同步

## 目录结构

```
Obsidian笔记库/
├── 管理者@yejimaca2141/             # 代理名@主机名
│   └── 260317/                      # YYMMDD
│       ├── 2603171800+对话主题.md    # 对话保存
│       └── 项目-新建代理/            # 项目文件夹
│           ├── 问题1-v1.md          # 版本化
│           └── 问题1-v2.md
└── 其他笔记.md
```

## 两种保存类型

### 对话保存（自动）
- 格式：`YYMMDDHHMM+话题.md`
- 自动监控，增量保存
- 只保留文字对话，移除工具调用

### 项目成果保存（手动）
- 格式：`{主题}-v{版本号}.md`
- 保存到项目文件夹：`项目-{项目名}/`
- 版本号自动递增，保留历史版本

## 命令行

```bash
# 对话保存
bash scripts/manage.sh save-now
bash scripts/manage.sh saved

# 项目保存
bash scripts/manage.sh project-save <项目名> <主题> [版本]
bash scripts/manage.sh project-list
bash scripts/manage.sh project-versions <项目名>

# 其他
bash scripts/manage.sh status
bash scripts/manage.sh config
bash scripts/manage.sh update
```

## 使用示例

### 保存项目成果
```bash
echo "# 分析报告" | bash scripts/manage.sh project-save 新建代理 问题1
```

### 版本递增
```
问题1-v1.md  # 第一次保存
问题1-v2.md  # 第二次保存同一主题，版本号自动递增
```

## 更新日志

### v2.3.0 (2026-03-17)
- 新增项目文件夹功能
- 新增版本化保存
- 区分两种保存类型

### v2.2.0 (2026-03-17)
- 改进话题提取
- 文件名简化
- 内容清理
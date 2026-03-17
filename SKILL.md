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

## 触发方式

### 对话保存（自动）
- **触发**：自动监控，无需用户操作
- **格式**：`YYMMDDHHMM+话题.md`
- 只保留文字对话，移除工具调用

### 项目成果保存（手动触发）

**用户说以下关键词时，应使用项目保存：**
- "保存报告"、"存报告"
- "保存方案"、"存方案"
- "保存到项目"、"存到项目文件夹"
- "/project-save" 命令

**保存方式：**
```bash
echo "内容" | bash ~/.openclaw/workspace/skills/dialog-save/scripts/manage.sh project-save <项目名> <主题>
```

## 使用示例

### 用户说"保存报告"时
1. 识别当前讨论的项目名和主题
2. 提取对话中的关键成果内容
3. 执行项目保存命令

示例：
```
用户：把这个分析保存成报告

代理应执行：
echo "分析内容..." | bash scripts/manage.sh project-save 项目名 分析报告
```

### 用户指定项目名
```
用户：保存到新建代理项目，问题1的分析报告

代理应执行：
echo "内容..." | bash scripts/manage.sh project-save 新建代理 问题1分析报告
```

## 命令行参考

```bash
# 项目保存
bash scripts/manage.sh project-save <项目名> <主题> [版本]
bash scripts/manage.sh project-list
bash scripts/manage.sh project-versions <项目名>

# 对话保存
bash scripts/manage.sh save-now
bash scripts/manage.sh saved

# 其他
bash scripts/manage.sh status
bash scripts/manage.sh config
bash scripts/manage.sh update
```

## 项目识别规则

当用户提到以下内容时，识别为项目保存需求：
- "项目" + "保存"/"存"/"报告"/"方案"/"成果"
- "报告"/"方案"/"成果" + "保存"
- 具体项目名称（如"新建代理"、"对话保存技能"等）

## 版本化保存

- 同一主题多次保存，版本号自动递增
- 历史版本保留，不会覆盖
- 文件名：`主题-v1.md`、`主题-v2.md`...

## 更新日志

### v2.3.0 (2026-03-17)
- 新增项目文件夹功能
- 新增版本化保存
- 区分两种保存类型
- 添加触发关键词识别
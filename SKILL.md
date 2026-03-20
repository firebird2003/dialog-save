# dialog-save 技能

将 OpenClaw 对话自动保存为 Markdown 文件，支持 Obsidian 笔记库查看和 iCloud 同步。

## 版本信息

- **当前版本**: v2.6.0
- **发布日期**: 2026-03-20

## 一键安装/升级

```bash
bash <(curl -sL https://raw.githubusercontent.com/firebird2003/dialog-save/main/install.sh)
```

## 目录结构

```
{obsidianRoot}/
├── claw-对话/                    # 对话历史
│   └── 管理者@yejimaca2141/
│       └── 260317/
│           ├── 2603171800+对话主题.md
│           └── 项目-xxx/
│
├── claw-配置/                    # 代理配置文件（链接）
│   ├── 管理者/ → ~/.openclaw/workspace/
│   ├── 人事主管/ → ~/agents/hr-manager/
│   └── ...
│
└── claw-工作区/                  # 共享工作区（链接）
    └── shared/ → ~/agents/shared/
        ├── projects/
        ├── SOP/
        └── reports/
```

### claw- 前缀说明

`claw-` 前缀表示 OpenClaw 相关目录，便于在 Obsidian 中识别和管理。

### 三个目录的功能

| 目录 | 功能 | 内容 |
|------|------|------|
| `claw-对话/` | 对话历史 | 自动保存的对话、项目成果 |
| `claw-配置/` | 代理配置 | 各代理的 SOUL.md、JOB.md 等配置文件 |
| `claw-工作区/` | 共享工作区 | 项目成果、SOP、团队报告 |

## 新功能：硬链接支持

v2.6.0 新增硬链接支持，解决 Obsidian 无法识别软链接的问题：

- **软链接 (Symbolic Link)**: 兼容性好，但 Obsidian 可能无法识别
- **硬链接 (Hard Link)**: Obsidian 可直接识别，文件可在 Obsidian 中编辑

### 配置时选择链接类型

```
【第六步】链接设置
链接类型：
  1) 软链接 (symbolic link) - 兼容性更好
  2) 硬链接 (hard link) - Obsidian 可直接识别
```

### 手动切换链接类型

```bash
# 查看当前链接状态
bash scripts/manage.sh links-status

# 重新创建链接（修改配置后）
bash scripts/manage.sh links
```

## 快速开始

```bash
# 完整初始化（首次使用推荐）
bash scripts/manage.sh init

# 这会：
# 1. 创建 ~/agents/ 目录结构
# 2. 创建 claw-对话、claw-配置、claw-工作区 目录
# 3. 创建链接（软链接或硬链接）
# 4. 迁移旧目录（如果存在）
```

## 命令行

### 基础命令
```bash
bash scripts/manage.sh install      # 安装/重新安装
bash scripts/manage.sh config       # 修改配置
bash scripts/manage.sh status       # 查看状态
bash scripts/manage.sh save-now     # 立即保存对话
bash scripts/manage.sh saved        # 查看已保存的对话
```

### 链接与初始化
```bash
bash scripts/manage.sh init         # 完整初始化
bash scripts/manage.sh links        # 创建/更新链接
bash scripts/manage.sh links-status # 查看链接状态
bash scripts/manage.sh migrate      # 迁移旧目录结构
bash scripts/manage.sh init-agents  # 初始化代理目录结构
```

### 添加代理配置链接
```bash
# 添加新代理的配置链接
bash scripts/manage.sh link-agent <代理名> <目标路径>

# 示例
bash scripts/manage.sh link-agent 人事主管 ~/agents/hr-manager
```

### 项目保存
```bash
bash scripts/manage.sh project-save <项目名> <主题> [版本]
bash scripts/manage.sh project-list
bash scripts/manage.sh project-versions <项目名>
```

## 两种保存类型

### 对话保存（自动）
- 自动监控并保存所有对话
- 格式：`YYMMDDHHMM+话题.md`
- 只保留文字对话，移除工具调用

### 项目成果保存（手动触发）
当用户说"保存报告"、"存方案"时：

```bash
echo "内容" | bash scripts/manage.sh project-save <项目名> <主题>
```

## 在 Obsidian 中查看代理配置

1. 打开 `claw-配置/` 目录
2. 点击代理名称（如 `管理者/`）
3. 查看该代理的 SOUL.md、JOB.md 等配置文件

## 配置文件

```json
{
  "version": "2.6.0",
  "obsidianRoot": "/path/to/obsidian",
  "structure": {
    "dialogDir": "claw-对话",
    "configDir": "claw-配置",
    "workspaceDir": "claw-工作区"
  },
  "links": {
    "enabled": true,
    "useHardlink": false,
    "manager": {
      "name": "管理者",
      "target": "~/.openclaw/workspace"
    },
    "shared": {
      "name": "shared",
      "target": "~/agents/shared"
    }
  },
  "agents": {
    "rootDir": "~/agents",
    "autoInit": true
  }
}
```

### 配置项说明

| 配置项 | 说明 |
|--------|------|
| `links.useHardlink` | `true` 使用硬链接，`false` 使用软链接 |

## 代理目录结构

首次运行 `init` 后，会创建：

```
~/agents/
├── shared/
│   ├── projects/    # 共享项目成果
│   ├── SOP/         # 标准操作流程
│   └── reports/     # 团队报告
└── .templates/      # 代理配置模板
    ├── SOUL.md.template
    └── JOB.md.template
```

## 多代理支持

dialog-save 自动扫描所有代理的会话目录：

```
~/.openclaw/agents/
├── main/sessions/        # 主代理会话
├── hr-003/sessions/      # 人事代理会话
└── .../sessions/         # 其他代理会话
```

每个代理可以有独立的配置文件：

```
~/.openclaw/agents/<agent-id>/
└── dialog-save-config.json   # 代理级配置
```

## 更新日志

### v2.6.0 (2026-03-20)
- 新增硬链接支持
- 完善多代理支持
- 监控服务增强
- 问题修复

详见 [CHANGELOG.md](CHANGELOG.md)
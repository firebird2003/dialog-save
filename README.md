# dialog-save

将你与 AI 代理的对话自动保存为 Markdown 文件，支持 Obsidian 笔记库查看，多主机通过 WebDAV 同步。

## 功能特性

- 📝 自动或手动保存对话为 Markdown 格式
- 🗂️ 智能话题识别，自动分割不同主题的对话
- 📁 兼容 iCloud/Obsidian 同步的目录结构
- 🔍 frontmatter 元数据支持，方便检索
- 🌐 WebDAV 服务，多主机同步
- 💾 离线缓存，网络恢复后自动同步
- 🔄 自动检测版本更新

## 快速开始

```bash
cd ~/.openclaw/workspace/skills && [ -d dialog-save ] && (cd dialog-save && git pull origin main) || git clone https://github.com/firebird2003/dialog-save.git && cd dialog-save && bash scripts/manage.sh
```

**说明**：
- 目录已存在 → 自动拉取最新版本
- 目录不存在 → 克隆仓库
- 然后进入交互菜单

## 交互菜单

```
╔════════════════════════════════════════╗
║  dialog-save v1.3.2                    ║
║  OpenClaw 对话保存技能                 ║
╚════════════════════════════════════════╝

请选择操作：

  1) 安装/重新安装    - 安装依赖、配置、激活
  2) 修改配置        - 更改设置
  3) 启动服务        - 启动 WebDAV 服务
  4) 停止服务        - 停止 WebDAV 服务
  5) 查看状态        - 查看配置和服务状态
  6) 检查更新        - 检查并更新到最新版本
  7) 更新日志        - 查看版本更新记录
  8) 卸载            - 移除技能和数据
  0) 退出
```

## 目录结构

```
Obsidian笔记库/
├── 管理者@yejimaca2141/    # 代理名@主机名（兼容iCloud）
│   └── 260316/
│       └── 2603162100+对话主题.md
└── 其他笔记.md
```

## 保存机制

### 自动模式
- 自动保存所有对话
- 无需用户提示
- 适合完整记录

### 手动模式
- 需要说"存入本地目录"或"保存对话"
- 智能话题识别
- 适合选择性保存

## 版本更新

```bash
# 方法1：运行安装命令（自动检测更新）
cd ~/.openclaw/workspace/skills/dialog-save && bash scripts/manage.sh

# 方法2：手动更新
cd ~/.openclaw/workspace/skills/dialog-save && git pull origin main

# 方法3：菜单选择
bash scripts/manage.sh
# 选择 "6) 检查更新"
```

## 配置项

| 配置 | 说明 | 选项 |
|------|------|------|
| Obsidian 路径 | 笔记库根目录 | 路径 |
| WebDAV 端口 | 服务端口 | 默认 8080 |
| 代理名称 | 对话来源标识 | 自定义 |
| 主机名称 | 对话来源标识 | 自动检测 |
| 保存机制 | 自动/手动 | auto/manual |
| 运行模式 | 本地/远程 | local/remote |
| 开机自启 | 服务自启动 | true/false |

## iCloud 兼容说明

- 目录名使用 `@` 符号：`代理名@主机名`
- 与现有 iCloud 同步结构保持一致
- 避免中间子目录

## GitHub

https://github.com/firebird2003/dialog-save

## 更新日志

### v1.3.2 (2026-03-16)
- 新版本覆盖安装：目录已存在时自动 git pull 更新
- 版本检测：显示当前版本和远程最新版本

### v1.3.1 (2026-03-16)
- 优化安装体验

### v1.3.0 (2026-03-16)
- 目录名格式改为 `代理名@主机名`
- 新增保存机制选项

### v1.0.0 (2026-03-16)
- 初始版本
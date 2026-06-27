# 🛠️ Guoda 环境配置指南

> **当前环境快照**：Windows 11 + WSL2 (Ubuntu 22.04) + C/G 双盘配置  
> **创建日期**：2026-06-27  
> **维护人**：guoda

---

## 📖 项目简介

这个项目记录了 **2026-06-27 一次完整的环境治理过程**，包括：

- 🧹 C 盘深度瘦身（**释放 82 GB**，7.56 GB → 90 GB）
- 🚚 WSL2 数据迁移到 G 盘（**节省 56 GB** C 盘空间）
- 🏥 WSL 健康检查与问题修复
- 🚀 WSL 性能优化与开发工具链配置

**所有步骤可重复执行**，新机器上按照文档走一遍即可恢复整套环境。

---

## 📚 文档导航

| 文档 | 内容 | 推荐场景 |
|---|---|---|
| [01-c-drive-cleanup.md](docs/01-c-drive-cleanup.md) | C 盘分析与瘦身 | C 盘空间紧张 |
| [02-wsl-migration.md](docs/02-wsl-migration.md) | WSL2 迁移到其他盘 | C 盘被 vhdx 占满 |
| [03-wsl-health-check.md](docs/03-wsl-health-check.md) | WSL 健康检查清单 | 定期体检 |
| [04-optimization.md](docs/04-optimization.md) | 性能优化与工具链 | 新装 WSL 必看 |
| [cheatsheet.md](docs/cheatsheet.md) | 工具速查表 | 日常查阅 |
| [troubleshooting.md](docs/troubleshooting.md) | 故障排查 FAQ | 遇到问题先看这里 |

---

## 📂 项目结构

```
env-setup/
├── README.md                  # 当前文件
├── docs/                      # 详细文档
│   ├── 01-c-drive-cleanup.md
│   ├── 02-wsl-migration.md
│   ├── 03-wsl-health-check.md
│   ├── 04-optimization.md
│   ├── cheatsheet.md
│   └── troubleshooting.md
├── scripts/                   # 可直接执行的脚本
│   ├── restore.sh             # ⭐ 一键还原整个环境（新机器必备）
│   ├── clean_c.ps1            # C 盘清理（PowerShell）
│   ├── migrate_wsl.ps1        # WSL 迁移（PowerShell）
│   ├── wsl_health.sh          # WSL 健康检查（Bash）
│   ├── install_tools.sh       # 工具链安装（Bash）
│   ├── wslconfig.template     # .wslconfig 模板
│   └── bashrc.snippet.sh      # .bashrc 优化片段
└── backups/                   # 个人备份目录（按需使用）
```

---

## ⚡ 快速命令

```bash
# 🚀 新机器一键还原（推荐）
bash scripts/restore.sh

# 一键体检
bash scripts/wsl_health.sh

# 一键安装工具链（restore.sh 的子集，不含系统更新和 apt 源切换）
bash scripts/install_tools.sh

# 查看常用命令速查
cat docs/cheatsheet.md
```

---

## 🆕 新机器恢复流程

```bash
# 1. 在新机器装好 WSL Ubuntu 22.04 后，把这个项目复制进 WSL
git clone <你的仓库地址> ~/projects/personal/env-setup
# 或者直接 scp 整个项目过去

# 2. 一键还原
cd ~/projects/personal/env-setup
bash scripts/restore.sh

# 3. 配置 Windows 端 .wslconfig
# 在 Windows PowerShell 中：
Copy-Item scripts\wslconfig.template $env:USERPROFILE\.wslconfig
wsl --shutdown

# 4. 重新打开 WSL，享受完整环境
```

---

## 🔑 关键信息（机器特定，迁移到新机器时需要更新）

| 项 | 当前值 |
|---|---|
| Windows 用户 | `14393`（路径：`C:\Users\14393\`） |
| WSL 用户 | `guoda`（家目录：`/home/guoda/`） |
| WSL 发行版 | `Ubuntu-22.04` |
| WSL vhdx 位置 | `G:\WSL\Ubuntu-22.04\ext4.vhdx` |
| WSL 备份位置 | `G:\WSL\Ubuntu-22.04.tar` |
| apt 源 | 清华镜像 |
| npm 源 | 淘宝镜像 |
| 时区 | `Asia/Shanghai` |

---

## 📝 维护建议

- **新增工具/配置时**：更新 `docs/cheatsheet.md` 和 `scripts/install_tools.sh`
- **遇到新问题**：记录到 `docs/troubleshooting.md`
- **环境变更时**：在底部「变更日志」追加一行
- **重要操作前**：把关键文件备份到 `backups/`

---

## 📅 变更日志

| 日期 | 操作 | 备注 |
|---|---|---|
| 2026-06-27 | 初始化 | C 盘瘦身 + WSL 迁移 + 工具链配置 |

# 04 - WSL 优化方案

> **目标**：性能调优 + 开发工具链 + 工作效率提升

---

## ⚙️ 一、`.wslconfig` 配置（Windows 端）

**位置**：`C:\Users\<USER>\.wslconfig`

**模板**：见 [`scripts/wslconfig.template`](../scripts/wslconfig.template)

```ini
[wsl2]
networkingMode=mirrored       # 镜像网络（推荐，与 Windows 共享网络栈）
autoProxy=true                # 自动继承 Windows 代理设置
appendWindowsPath=true        # 在 WSL 中可调用 Windows 程序（如 explorer.exe）
sparseVhd=true                # 自动稀疏化 vhdx，防止虚胖

[experimental]
autoMemoryReclaim=gradual     # 闲置时自动归还内存给 Windows
```

### 关键配置说明

| 选项 | 说明 | 推荐值 |
|---|---|---|
| `networkingMode` | `mirrored`（共享 Windows 网络）或 `nat`（独立网络） | `mirrored` |
| `sparseVhd` | 让 vhdx 自动收缩 | `true` |
| `autoMemoryReclaim` | `gradual`（缓慢回收）或 `dropcache`（激进回收） | `gradual` |
| `memory` | 限制 WSL 可用内存上限（如 `16GB`） | 按需 |
| `processors` | 限制 WSL 可用 CPU 核数 | 按需 |

### 修改后必须重启 WSL
```powershell
wsl --shutdown
# 下次启动 WSL 时新配置生效
```

---

## ⚙️ 二、`/etc/wsl.conf` 配置（WSL 端）

**位置**：`/etc/wsl.conf`（需要 sudo）

**当前内容**：
```ini
[boot]
systemd=true

[user]
default=guoda
```

### 可选增强项

```ini
[boot]
systemd=true

[user]
default=guoda

[interop]
enabled=true           # 启用 Windows ↔ WSL 互操作（默认就是 true）
appendWindowsPath=false # 不在 WSL PATH 中追加 Windows 路径（避免命令污染）

[automount]
enabled=true           # 自动挂载 Windows 盘符到 /mnt/
options="metadata,umask=22,fmask=11"  # 允许 WSL 修改 /mnt/c 下文件权限

[network]
generateResolvConf=true # 自动生成 /etc/resolv.conf
```

> ⚠️ 如果设置 `appendWindowsPath=false`，将无法在 WSL 中直接调用 `code`、`explorer.exe` 等命令，需要在 `.bashrc` 中加 alias。

---

## 🛠️ 三、开发工具链

### 通过 apt 安装
```bash
sudo apt update
sudo apt install -y \
    htop tree bash-completion \
    ripgrep fd-find bat \
    tldr ca-certificates \
    unzip zip p7zip-full
```

### Ubuntu 22.04 的命令名差异

部分工具在 Ubuntu 22.04 中因为名字冲突，命令名不同：

| 工具 | 包名 | Ubuntu 22.04 命令 | 推荐 symlink |
|---|---|---|---|
| ripgrep | `ripgrep` | `rg` | 已是 `rg` |
| fd | `fd-find` | `fdfind` | `ln -sf $(which fdfind) /usr/local/bin/fd` |
| bat | `bat` | `batcat` | `ln -sf $(which batcat) /usr/local/bin/bat` |

### 通过二进制安装（现代工具）
```bash
# 见 scripts/install_tools.sh 完整脚本，安装以下工具到 ~/.local/bin/：
# - zoxide    智能跳转目录
# - starship  美化提示符
# - eza       带图标的 ls
# - fzf       模糊搜索
```

### Node.js 通过 nvm 安装
```bash
# 克隆 nvm（gitee 镜像）
git clone https://gitee.com/mirrors/nvm.git ~/.nvm
cd ~/.nvm && git checkout $(git describe --abbrev=0 --tags)

# 配置 .bashrc
cat >> ~/.bashrc <<'EOF'
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
export NVM_NODEJS_ORG_MIRROR=https://npmmirror.com/mirrors/node
EOF

# 加载并安装
source ~/.bashrc
nvm install --lts
npm config set registry https://registry.npmmirror.com
```

---

## 🎨 四、`.bashrc` 优化

**位置**：`~/.bashrc`

**优化片段**：见 [`scripts/bashrc.snippet.sh`](../scripts/bashrc.snippet.sh)

包含：
- ✅ PATH 配置（含 `~/.local/bin`、`~/.fzf/bin`）
- ✅ zoxide / starship / fzf 自动加载
- ✅ 30+ 别名（ls/cat/find/grep/git/systemctl/apt/...）
- ✅ 实用函数（extract / mkcd / port / myip / logs）

### 安装方式

```bash
# 备份
cp ~/.bashrc ~/.bashrc.bak.$(date +%s)

# 追加配置（脚本会自动避免重复）
bash scripts/install_tools.sh
```

---

## 🎮 五、关键快捷键

| 快捷键 | 功能 |
|---|---|
| `Ctrl+R` | 模糊搜索历史命令 |
| `Ctrl+T` | 当前目录模糊查找文件 |
| `Alt+C` | 子目录模糊跳转 |
| `z <关键词>` | 跨目录智能跳转 |
| `Ctrl+A` / `Ctrl+E` | 行首 / 行尾 |
| `Ctrl+W` | 删除前一个单词 |
| `Ctrl+U` | 删除到行首 |

---

## 📈 六、性能建议

### 文件系统性能

| 操作 | 速度 |
|---|---|
| WSL 内访问 `/home/...`（ext4） | ⚡ 最快 |
| WSL 内访问 `/mnt/c/...`（NTFS） | 🐢 慢 5-10 倍 |

**建议**：项目代码放 WSL 文件系统（如 `~/projects/`），通过 VS Code Remote-WSL 访问。

### VS Code 集成

- 安装 VS Code 扩展：`ms-vscode-remote.remote-wsl`
- 在 WSL 中进入项目目录后执行 `code .`，会自动用 Remote-WSL 模式打开

### Windows Terminal 配置

添加 WSL 标签页：
```jsonc
{
    "guid": "{07b52e3e-de2c-5db4-bd2d-ba308ed70529}",
    "name": "Ubuntu",
    "source": "Windows.Terminal.Wsl",
    "colorScheme": "One Half Dark",
    "font": {
        "face": "Cascadia Code PL",
        "size": 11
    },
    "startingDirectory": "//wsl.localhost/Ubuntu-22.04/home/guoda"
}
```

---

## 💡 七、Git 配置建议

```bash
# 全局配置
git config --global user.name "Your Name"
git config --global user.email "you@example.com"
git config --global init.defaultBranch main
git config --global pull.rebase true
git config --global push.autoSetupRemote true

# 常用别名（也可加到 .gitconfig）
git config --global alias.s "status -sb"
git config --global alias.l "log --oneline --graph --decorate -20"
git config --global alias.ll "log --oneline --stat -10"
git config --global alias.d "diff"
git config --global alias.ds "diff --staged"
git config --global alias.co "checkout"
git config --global alias.br "branch"
git config --global alias.ci "commit"
git config --global alias.ca "commit --amend"
```

---

## 🔄 后续可选优化

| 优化项 | 收益 | 难度 |
|---|---|---|
| 安装 oh-my-zsh | 更丰富的 shell 体验 | 简单 |
| 配置 tmux | 多窗口/分屏 | 简单 |
| Docker + WSL2 集成 | 容器化开发 | 简单 |
| 配置 SSH key | 免密 git/ssh | 简单 |
| 安装 GPU 驱动 | CUDA 加速 | 中等 |

---

⏮️ [← 03 健康检查](03-wsl-health-check.md) | [返回主页](../README.md) | 下一篇：[05 一键还原 →](05-restore.md)

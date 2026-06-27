# 05 - 一键还原脚本

> **目标**：在新机器或重装系统后，**一键恢复完整 WSL 开发环境**
>
> **脚本位置**：[`scripts/restore.sh`](../scripts/restore.sh)

---

## 🎯 这个脚本解决什么问题

每次重装系统、换电脑、或者新建一个 WSL 实例，都要重复这些操作：

1. 切换 apt 源（清华镜像）
2. 系统更新 + 安装基础工具（htop/ripgrep/fd/bat/...）
3. 下载安装现代工具（zoxide/starship/fzf/eza）
4. 装 nvm + Node.js + npm 镜像
5. 配置 ~/.bashrc（30+ 别名 + 函数）
6. 配置 /etc/wsl.conf
7. 修复 systemd 用户服务
8. 验证所有工具就绪

**手动做完至少 30-60 分钟，容易漏步骤。** `restore.sh` 把这些封装成 **一条命令**，10-15 分钟跑完。

---

## ✨ 核心特性

| 特性                 | 说明                               |
| -------------------- | ---------------------------------- |
| 🔄**幂等**     | 重复运行安全，已装的工具自动跳过   |
| 🧩**模块化**   | 9 个步骤，每步独立，失败不影响其他 |
| 🚀**非交互**   | 默认全自动，无需守着回答           |
| 🎛️**可跳过** | `--skip-xxx` 选项精细控制        |
| 🤖**自动检测** | Windows 用户名、WSL 用户名自动识别 |
| 🌐**网络容错** | github 不通自动切换 ghproxy 代理   |
| 📊**进度可视** | 每步显示状态，最后汇总错误         |

---

## 🚀 快速开始

### 最简单的用法（一键全自动）

```bash
cd ~/projects/personal/env-setup
bash scripts/restore.sh
```

然后等 10-15 分钟，所有工具、配置、别名都会就绪。

---

## 📋 适用场景

### 场景 1：新机器恢复环境（最常用）

```bash
# Windows 端：装好 WSL Ubuntu 22.04 后进入 WSL
# 把这个项目复制进来（git clone 或 scp）
git clone <你的仓库地址> ~/projects/personal/env-setup

# 一键还原
cd ~/projects/personal/env-setup
bash scripts/restore.sh
```

### 场景 2：现有 WSL 环境补全工具

如果你已经有 WSL 环境，但某些工具没装齐，直接跑：

```bash
bash scripts/restore.sh
# 已安装的工具会自动跳过，只补缺失的
```

### 场景 3：自定义选择性安装

```bash
# 只装 Node.js（其他都跳过）
bash scripts/restore.sh \
    --skip-apt-mirror \
    --skip-system-update \
    --skip-wsl-conf \
    --skip-bashrc

# 跳过 Node.js（已有或不需要）
bash scripts/restore.sh --skip-node

# 公司网络限制不能换源
bash scripts/restore.sh --skip-apt-mirror --skip-system-update
```

### 场景 4：测试新工具影响

```bash
# 用 wsl --import 创建一个测试实例
wsl --import test-ubuntu "G:\WSL\test" "G:\WSL\Ubuntu-22.04.tar"
wsl -d test-ubuntu

# 在测试实例中跑 restore.sh
bash /mnt/c/Users/<USER>/.../env-setup/scripts/restore.sh

# 验证完成后清理
exit
wsl --unregister test-ubuntu
```

---

## 📖 9 个步骤详解

### 步骤 0：环境检查 ✅

- 确认在 WSL 中运行（不在原生 Linux）
- 检查当前用户（不能是 root）
- 验证 sudo 可用

### 步骤 1：apt 清华源 🌐

- 检测当前 apt 源
- 如果不是清华源，备份后切换
- 后续 `apt install` 速度从几 KB/s → 几 MB/s
- **可跳过**：`--skip-apt-mirror`

### 步骤 2：系统更新 + 基础工具 📦

- `apt update && apt upgrade -y`（修复安全更新）
- 安装基础工具：
  - `htop` `tree` `bash-completion`
  - `ripgrep` `fd-find` `bat`
  - `tldr` `ca-certificates`
  - `unzip` `zip` `p7zip-full`
  - `build-essential`（gcc/g++/make）
- 创建兼容 symlink：`fd` → `fdfind`，`bat` → `batcat`
- **可跳过**：`--skip-system-update`（仅跳过 update/upgrade）

### 步骤 3：现代工具 ⚡

安装到 `~/.local/bin/`，不需要 sudo：

| 工具               | 来源                       | 用途        |
| ------------------ | -------------------------- | ----------- |
| **zoxide**   | github release（代理备份） | 智能 cd     |
| **starship** | starship.rs 官方脚本       | 提示符美化  |
| **fzf**      | gitee 镜像                 | 模糊搜索    |
| **eza**      | github release（代理备份） | 带图标的 ls |

网络策略：先直连 github，失败自动切换 `ghproxy.com` / `gh-proxy.com` / `mirror.ghproxy.com` 代理。

### 步骤 4：Node.js（通过 nvm）🟢

- 从 gitee 镜像克隆 nvm（最新版本）
- 通过 `NVM_NODEJS_ORG_MIRROR` 用 npmmirror 加速下载 node 二进制
- 安装最新 LTS 版本（当前 v24）
- 配置 npm 淘宝镜像
- **可跳过**：`--skip-node`

### 步骤 5：~/.bashrc 配置 🎨

- 备份当前 `.bashrc`（带时间戳）
- 移除已有的优化配置块（如有）
- 追加 [`scripts/bashrc.snippet.sh`](../scripts/bashrc.snippet.sh) 的内容
- 自动检测 Windows 用户名，替换 `winhome` 别名中的 `/mnt/c/Users/14393`
- **可跳过**：`--skip-bashrc`

### 步骤 6：/etc/wsl.conf ⚙️

- 设置默认用户为当前用户
- 启用 systemd
- **可跳过**：`--skip-wsl-conf`

```ini
[boot]
systemd=true

[user]
default=<你的用户名>
```

### 步骤 7：systemd 用户服务修复 🔧

- `sudo loginctl enable-linger $USER`
- 修复 `user@1000.service failed` 问题
- 让用户级 systemd 服务可以正常运行

### 步骤 8：最终验证 ✅

- 检查所有工具是否就绪
- 输出表格化报告：

```
  工具         版本                 状态
  ----         ----                 ----
  htop         htop 3.0.5           ✓
  tree         tree v2.0.2          ✓
  rg           ripgrep 13.0.0       ✓
  ...
  node         v24.14.1             ✓
  npm          11.11.0              ✓
```

---

## 🎛️ 命令行选项

| 选项                     | 作用                    | 适用场景                |
| ------------------------ | ----------------------- | ----------------------- |
| `--skip-apt-mirror`    | 跳过 apt 源切换         | 公司网络限制 / 已配置过 |
| `--skip-system-update` | 跳过 apt update/upgrade | 离线环境 / 已更新过     |
| `--skip-node`          | 跳过 Node.js / nvm      | 已有 Node / 不用 Node   |
| `--skip-wsl-conf`      | 跳过 /etc/wsl.conf 配置 | 已配置过 / 不是 root    |
| `--skip-bashrc`        | 跳过 ~/.bashrc 配置     | 已配置过 / 自定义配置   |
| `-y`, `--yes`        | 默认对交互回答 yes      | （默认就是非交互）      |
| `-h`, `--help`       | 显示帮助                | 查看用法                |

### 组合示例

```bash
# 最完整执行（默认）
bash scripts/restore.sh

# 最小执行（只装工具，不碰配置）
bash scripts/restore.sh --skip-bashrc --skip-wsl-conf

# 离线/局域网环境
bash scripts/restore.sh --skip-apt-mirror

# 已有 Node 环境
bash scripts/restore.sh --skip-node

# 只想跑体检 + 装基础工具
bash scripts/restore.sh --skip-bashrc --skip-wsl-conf --skip-node
```

---

## 🔧 自定义：添加自己的步骤

### 1. 在脚本末尾添加新函数

打开 [`scripts/restore.sh`](../scripts/restore.sh)，找到 `main()` 函数前，添加：

```bash
# === 步骤 X: 安装 Python 工具 ===
install_python_tools() {
    log_step "安装 Python 工具"
    sudo apt install -y python3-pip python3-venv
    pip3 install --user pipx
    pipx ensurepath
    pipx install poetry ruff mypy
    log_info "Python 工具安装完成"
}
```

### 2. 在 `main()` 中调用

```bash
main() {
    parse_args "$@"
    check_env
    setup_apt_mirror
    install_apt_packages
    install_modern_tools
    install_node
    install_python_tools     # ← 新增这一行
    setup_bashrc
    setup_wsl_conf
    fix_systemd
    verify
    summary
}
```

### 3. 提交到 git

```bash
gaa
gc -m "feat: restore.sh 添加 Python 工具安装"
gP
```

---

## 📊 输出示例

成功时：

```
=== 步骤 0/8: 环境检查 ===
  ✓ 环境: Ubuntu 22.04.5 LTS
  ✓ 用户: guoda
  ✓ 家目录: /home/guoda

=== 步骤 1/8: 配置 apt 清华源 ===
  ℹ apt 源已切换到清华镜像

=== 步骤 2/8: 系统更新 + 基础工具 ===
  ℹ 执行 apt update...
  ℹ 执行 apt upgrade...
  ℹ 安装基础工具...
  ✓ 基础工具就绪

...

=== 步骤 8/8: 最终验证 ===

  工具         版本                 状态
  ----         ----                 ----
  htop         htop 3.0.5           ✓
  tree         tree v2.0.2          ✓
  ...
  node         v24.14.1             ✓
  npm          11.11.0              ✓

=== 执行汇总 ===

==========================================
  🎉 全部步骤成功完成！
==========================================

📌 下一步操作：
  ...
```

失败时（部分步骤）：

```
=== 步骤 3/8: 现代工具（zoxide/starship/fzf/eza） ===
  ℹ github 直连不通，将使用代理
  ℹ 安装 zoxide...
  ✓ zoxide 安装完成
  ℹ 安装 starship...
  ✗ starship 安装失败（网络）

...

=== 执行汇总 ===

==========================================
  ⚠️  有 1 个错误：
==========================================
  - starship 安装失败（网络）

📌 下一步操作：
  ...
```

即使部分步骤失败，其他步骤也会继续执行。

---

## 🐛 故障排查

### 问题 1：脚本中断在 apt update

**症状**：`GPG error: NO_PUBKEY` 或网络错误

**解决**：

```bash
# 1. 手动修复 key
sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys <KEY_ID>

# 2. 或者跳过 apt 源切换
bash scripts/restore.sh --skip-apt-mirror
```

### 问题 2：现代工具下载失败

**症状**：`✗ zoxide 安装失败（网络）`

**原因**：github 完全不可达，代理也连不通

**解决**：

```bash
# 1. 手动下载二进制（在能访问 github 的机器上）
# 2. scp 到 WSL 的 ~/.local/bin/
# 3. 重新运行 restore.sh，已下载的会自动跳过
```

### 问题 3：sudo 一直要求密码

**症状**：脚本卡在密码输入

**解决**：

```bash
# 配置当前用户免密 sudo（谨慎使用）
echo "$USER ALL=(ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/$USER
```

### 问题 4：脚本完成后，新开终端还是老样子

**症状**：`ls` 没有图标，`z` 不存在

**原因**：当前终端没加载新配置

**解决**：

```bash
# 当前终端立即生效
source ~/.bashrc

# 或者直接开新终端窗口
```

### 问题 5：提示 `/etc/wsl.conf` 写入失败

**症状**：`tee: /etc/wsl.conf: Permission denied`

**原因**：sudo 出问题

**解决**：

```bash
# 手动执行
sudo nano /etc/wsl.conf
# 写入：
# [boot]
# systemd=true
# [user]
# default=<你的用户名>
```

### 问题 6：winhome 别名指向错误的 Windows 用户

**症状**：`winhome` 进入了错误的目录

**原因**：`/mnt/c/Users/` 下有多个用户目录，自动检测选错了

**解决**：

```bash
# 查看实际 Windows 用户名
ls /mnt/c/Users/

# 手动修改 .bashrc 中的 winhome 别名
sed -i "s|/mnt/c/Users/[^ ]*|/mnt/c/Users/<正确的用户名>|g" ~/.bashrc

# 重新加载
source ~/.bashrc
```

---

## 💡 最佳实践

### 1. 把项目推送到远程仓库

`restore.sh` 的真正价值在于**新机器恢复**，所以项目本身要能从云端拉取：

```bash
# 在 GitHub / Gitee 创建仓库
cd ~/projects/personal/env-setup
gh repo create env-setup --private --source=. --push
# 或
git remote add origin git@gitee.com:<你>/env-setup.git
git push -u origin main
```

### 2. 定期更新脚本

每当你：

- 装了新工具（比如 docker、conda）
- 修改了 .bashrc（新别名 / 函数）
- 调整了 /etc/wsl.conf

**记得同步到这个项目**：

```bash
# 修改 .bashrc 后
cp ~/.bashrc scripts/bashrc.snippet.sh
# （注意只保留优化片段部分）

# 然后提交
cd ~/projects/personal/env-setup
gaa
gc -m "update: 同步最新 .bashrc 配置"
gP
```

### 3. 配合定期备份

```bash
# 定期备份 WSL（每月一次）
wsl --shutdown
wsl --export Ubuntu-22.04 "G:\WSL\backups\Ubuntu-22.04-$(date +%Y%m%d).tar"

# 这样即使 WSL 完全坏了：
# 1. wsl --unregister Ubuntu-22.04
# 2. wsl --import Ubuntu-22.04 G:\WSL\Ubuntu-22.04 <备份tar>
# 3. 不用跑 restore.sh（数据全部恢复）
```

### 4. 不要随便修改 restore.sh

如果需要自定义，建议：

- 创建 `scripts/restore.local.sh`（不进 git）
- 在最后调用 `restore.sh` 后追加自定义步骤
- 这样不会和主仓库冲突

---

## 📝 restore.sh vs install_tools.sh 的区别

| 项目                         | `restore.sh`         | `install_tools.sh`   |
| ---------------------------- | ---------------------- | ---------------------- |
| **目标**               | 全环境还原（新机器）   | 工具链补充（已有环境） |
| **包含 apt 源切换**    | ✅                     | ❌                     |
| **包含系统更新**       | ✅                     | ✅                     |
| **包含 .bashrc 配置**  | ✅                     | ✅                     |
| **包含 /etc/wsl.conf** | ✅                     | ❌                     |
| **包含 Node.js**       | ✅                     | ❌                     |
| **幂等**               | ✅                     | ⚠️ 部分              |
| **可跳过步骤**         | ✅ 多种 `--skip-xxx` | ❌                     |
| **错误隔离**           | ✅                     | ❌                     |

**简单总结**：

- 🆕 **新机器 / 重装** → `restore.sh`
- 🔧 **现有环境补工具** → `install_tools.sh`

---

⏮️ [← 04 优化方案](04-optimization.md) | [返回主页](../README.md) | 下一篇：[速查表 →](cheatsheet.md)

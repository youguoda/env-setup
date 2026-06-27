# 故障排查 FAQ

> 遇到问题先看这里！按症状查找解决方案

---

## 🚨 紧急自救

### WSL 完全起不来了
```powershell
# 1. 查看 WSL 服务状态
Get-Service LxssManager, WslService

# 2. 重启 WSL 相关服务
Restart-Service LxssManager

# 3. 完全关闭后再启动
wsl --shutdown
wsl

# 4. 实在不行，检查 Windows 系统文件
sfc /scannow  # 以管理员身份运行 PowerShell
```

### 误删了重要文件
- WSL 数据丢失：从 `G:\WSL\Ubuntu-22.04.tar` 恢复（见 [02-wsl-migration.md](02-wsl-migration.md)）
- Windows 文件丢失：从回收站 / 文件历史 / 备份恢复
- `.bashrc` 误改：恢复 `~/.bashrc.bak.<时间戳>` 或重新执行 `scripts/install_tools.sh`

---

## 🟡 常见问题

### Q1：`wsl --shutdown` 后再启动很慢

**原因**：WSL2 启动需要冷启动 Linux 内核 + systemd  
**解决**：正常现象，等 5-30 秒。可在 `.wslconfig` 加 `vmIdleTimeout=-1` 让 WSL 闲置时不自动关闭

---

### Q2：`z <关键词>` 找不到目录

**原因**：zoxide 需要先"学习"你访问过的目录  
**解决**：
```bash
# 先正常 cd 几次该目录，让 zoxide 记住
cd ~/projects/myapp
# 之后 z myapp 就能用了

# 查看已学习的目录
zoxide query -ls

# 交互式选择
zi
```

---

### Q3：在 WSL 里访问 `/mnt/c` 很慢

**原因**：跨文件系统（Linux ext4 ↔ Windows NTFS）有性能损失，正常现象  
**解决**：
- **项目代码放 WSL 文件系统**（`~/projects/`），用 VS Code Remote-WSL 编辑
- 不要在 `/mnt/c` 下做高频 IO（npm install / python 包安装等）
- 大文件读写也建议放 WSL 文件系统

---

### Q4：`code .` 打开的不是 Remote-WSL 模式

**原因**：可能 PATH 中没找到 VS Code，或没装 Remote-WSL 扩展  
**解决**：
```bash
# 1. 在 Windows 端 VS Code 中安装扩展：
#    ms-vscode-remote.remote-wsl

# 2. 在 WSL 中执行
which code
# 应该输出 /mnt/c/Users/.../AppData/Local/Programs/Microsoft VS Code/bin/code

# 3. 如果找不到，手动添加到 PATH
echo 'export PATH=$PATH:/mnt/c/Users/<USER>/AppData/Local/Programs/"Microsoft VS Code"/bin' >> ~/.bashrc
```

---

### Q5：`Ctrl+R` 不工作

**原因**：fzf 没正确加载到 shell  
**解决**：
```bash
# 检查 fzf 是否安装
ls ~/.fzf/bin/fzf

# 检查 .bashrc 是否 source 了配置
grep "fzf.bash" ~/.bashrc
# 应该有: [ -f ~/.fzf.bash ] && source ~/.fzf.bash

# 当前会话手动加载测试
source ~/.fzf.bash
```

---

### Q6：starship 提示符不显示

**原因**：starship 没在 PATH 中或未初始化  
**解决**：
```bash
# 检查 starship 是否安装
ls ~/.local/bin/starship

# 检查 PATH
echo $PATH | tr ':' '\n' | grep local/bin

# 测试初始化
eval "$(starship init bash)"
```

---

### Q7：apt update 很慢

**原因**：使用了国外默认源  
**解决**：换清华源
```bash
sudo cp /etc/apt/sources.list /etc/apt/sources.list.bak
sudo sed -i 's|http://archive.ubuntu.com|https://mirrors.tuna.tsinghua.edu.cn|g' /etc/apt/sources.list
sudo sed -i 's|http://security.ubuntu.com|https://mirrors.tuna.tsinghua.edu.cn|g' /etc/apt/sources.list
sudo apt update
```

---

### Q8：npm install 很慢 / 失败

**原因**：默认从 npmjs.org 下载，国内访问慢  
**解决**：
```bash
# 设置淘宝镜像
npm config set registry https://registry.npmmirror.com

# 验证
npm config get registry

# 如果还是慢，可能是 nvm 下载 node 二进制慢
# 在 ~/.bashrc 中加：export NVM_NODEJS_ORG_MIRROR=https://npmmirror.com/mirrors/node
```

---

### Q9：pip install 很慢

**解决**：
```bash
pip config set global.index-url https://pypi.tuna.tsinghua.edu.cn/simple
# 或
pip install -i https://pypi.tuna.tsinghua.edu.cn/simple <package>
```

---

### Q10：访问 GitHub 超时

**原因**：国内网络环境  
**解决**：
```bash
# 1. 配置 git 走代理（如果你有代理）
git config --global http.proxy http://127.0.0.1:7890
git config --global https.proxy http://127.0.0.1:7890

# 2. 使用 ghproxy 代理下载 release
curl -L https://ghproxy.com/https://github.com/xxx/release.tar.gz -o file.tar.gz

# 3. 用 gitee 镜像 clone
git clone https://gitee.com/mirrors/<repo>.git
```

---

### Q11：docker 命令找不到

**原因**：WSL 内没装 docker  
**解决**：两个方案

**方案 A**：用 Docker Desktop 集成（推荐）
1. Windows 端安装 Docker Desktop
2. 设置 → Resources → WSL Integration → 勾选 Ubuntu-22.04
3. WSL 中即可使用 docker 命令

**方案 B**：WSL 内独立安装
```bash
sudo apt install docker.io
sudo usermod -aG docker $USER
# 重新登录后生效
```

---

### Q12：systemctl 报错 `System has not been booted with systemd`

**原因**：`/etc/wsl.conf` 中没启用 systemd  
**解决**：
```bash
sudo tee /etc/wsl.conf > /dev/null <<'EOF'
[boot]
systemd=true
EOF

# 在 Windows 端重启 WSL
wsl --shutdown
wsl
```

---

### Q13：内存占用过高

**原因**：WSL 默认可以占用 Windows 50% 内存  
**解决**：
```ini
# 在 C:\Users\<USER>\.wslconfig 中加：
[wsl2]
memory=16GB    # 限制最大内存
swap=4GB       # 限制 swap

[experimental]
autoMemoryReclaim=gradual  # 自动归还内存
```

然后 `wsl --shutdown` 重启。

---

### Q14：vhdx 文件越来越大

**原因**：vhdx 是动态扩展，删除文件后空间不会自动归还  
**解决**：
```ini
# .wslconfig 开启 sparseVhd
[wsl2]
sparseVhd=true
```

或在 `wsl --shutdown` 后用 diskpart 手动压缩：
```powershell
diskpart
# select vdisk file="G:\WSL\Ubuntu-22.04\ext4.vhdx"
# attach vdisk readonly
# compact vdisk
# detach vdisk
# exit
```

---

### Q15：时间不对

**原因**：WSL 时区未设置或 NTP 未同步  
**解决**：
```bash
sudo timedatectl set-timezone Asia/Shanghai
sudo timedatectl set-ntp true
timedatectl
```

---

## 🐛 报错对应表

| 报错信息 | 原因 | 解决 |
|---|---|---|
| `dxg ioctl failed -2` | WSL GPU 驱动问题 | 更新 Windows 端 GPU 驱动（用不到 CUDA 可忽略） |
| `user@1000.service failed` | 用户级 systemd 未启动 | `sudo loginctl enable-linger $USER` |
| `Cannot bind parameter` (PowerShell) | bash `$` 被 PowerShell 解析 | 把脚本写到文件再 `wsl bash file.sh` |
| `bash: bad interpreter` | 文件 CRLF 换行符 | `sed -i 's/\r$//' file.sh` |
| `npm ERR! EACCES` | npm 全局安装权限问题 | 用 nvm 装的 node 不需要 sudo，直接 `npm i -g xxx` |
| `fatal: not in a git repo` | 当前目录不是 git 仓库 | 检查路径，或 `git init` |
| `command not found: z` | zoxide 未加载 | `source ~/.bashrc` 或 `eval "$(zoxide init bash)"` |

---

## 🆘 还是不行？

1. 看 WSL 日志：`journalctl -p err -b`
2. 看 Windows 事件日志：事件查看器 → Windows 日志 → 应用程序 → 来源：WSL
3. 收集信息：
   - `wsl --version`
   - `wsl --status`
   - `wsl -d Ubuntu-22.04 -e uname -a`
   - `cat /etc/wsl.conf`
   - `cat C:\Users\<USER>\.wslconfig`
4. 微软官方文档：https://learn.microsoft.com/zh-cn/windows/wsl/

---

⏮️ [← 速查表](cheatsheet.md) | [返回主页](../README.md)

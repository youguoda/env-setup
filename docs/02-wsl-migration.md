# 02 - WSL2 迁移到其他盘

> **战果**：WSL2 vhdx 从 C 盘搬到 G 盘，**C 盘释放 56 GB**，数据 100% 完整

---

## 🎯 适用场景

- C 盘空间紧张，WSL vhdx 占了几十 GB
- 想把"重型"应用整体迁出 C 盘
- 准备重装系统前备份 WSL

---

## 📐 原理

WSL2 的所有数据都存在一个 `ext4.vhdx` 虚拟磁盘文件中。迁移 = **导出 tar 包 → 注销原位置 → 在新位置重新导入**。

```
原: C:\Users\<USER>\AppData\Local\Packages\CanonicalGroupLimited.Ubuntu22.04LTS_*\LocalState\ext4.vhdx
新: G:\WSL\Ubuntu-22.04\ext4.vhdx
```

**所有 WSL 内的文件、配置、安装的软件完全保留**，只是物理位置换了。

---

## 📋 前置检查

### 1. 确认 WSL 状态
```powershell
wsl --list --verbose
# 应该看到 Ubuntu-22.04 状态
```

### 2. 查询默认用户名（迁移后需要恢复）
```powershell
# 列出 WSL 中 UID >= 1000 的用户
wsl -d Ubuntu-22.04 -e cat /etc/passwd | findstr ":x:1"
# 输出: guoda:x:1000:1001:...
# 默认用户名是 guoda
```

### 3. 检查当前 wsl.conf
```powershell
wsl -d Ubuntu-22.04 -e cat /etc/wsl.conf
```

### 4. 确认目标盘空间
```powershell
Get-PSDrive G | Select-Object Free
# 至少要有 120 GB 可用空间（导出 + 导入 + 缓冲）
```

---

## 🚚 迁移步骤（4 步走）

### 步骤 1：关闭 WSL 并创建目标目录
```powershell
wsl --shutdown
Start-Sleep -Seconds 3

New-Item -Path "G:\WSL" -ItemType Directory -Force
```

### 步骤 2：导出 WSL 到 tar 包（5-15 分钟）
```powershell
wsl --export Ubuntu-22.04 "G:\WSL\Ubuntu-22.04.tar"
```
> 💡 tar 包通常比原 vhdx **小 10-15%**（vhdx 是动态扩展，有"虚胖"）

### 步骤 3：注销原 WSL（释放 C 盘空间）
```powershell
wsl --unregister Ubuntu-22.04
# 这一步会删除 C 盘的 ext4.vhdx
# ⚠️ 但因为 tar 包已生成，可以放心执行
```

### 步骤 4：从 G 盘重新导入（5-15 分钟）
```powershell
wsl --import Ubuntu-22.04 "G:\WSL\Ubuntu-22.04" "G:\WSL\Ubuntu-22.04.tar"
```

---

## 🔧 迁移后配置

### 问题：默认用户变 root 了

`wsl --import` 后默认登录用户会变成 `root`，需要恢复原用户。

**解决方法**：在 `/etc/wsl.conf` 中指定默认用户

```bash
# 在 WSL 中以 root 身份执行
sudo tee /etc/wsl.conf > /dev/null <<'EOF'
[boot]
systemd=true

[user]
default=guoda
EOF

# 重启 WSL 让配置生效
# 在 Windows PowerShell 中：
wsl --shutdown
```

### 验证

```powershell
# 默认用户应该是 guoda（不是 root）
wsl -d Ubuntu-22.04 -e whoami

# systemd 应该是 running
wsl -d Ubuntu-22.04 -e systemctl is-system-running
```

---

## 🗑️ 清理 tar 包

确认 WSL 工作正常 1-2 周后，可以删除 tar 包释放空间：

```powershell
Remove-Item "G:\WSL\Ubuntu-22.04.tar"
```

> 💡 **强烈建议保留 tar 包作为冷备份**。G 盘空间充裕的情况下不必急着删。

---

## 🔄 一键迁移脚本

完整脚本见 [`scripts/migrate_wsl.ps1`](../scripts/migrate_wsl.ps1)，封装了上述所有步骤。

---

## 📊 空间变化预期

| 阶段 | C 盘 | G 盘 |
|---|---|---|
| 迁移前 | 用 56 GB | 空 |
| 导出 tar 包后 | 用 56 GB | -50 GB（tar） |
| 注销原 WSL 后 | **释放 56 GB** | -50 GB（tar） |
| 导入新位置后 | 释放 56 GB | -100 GB（tar+vhdx） |
| 删除 tar 包后 | 释放 56 GB | -50 GB（只 vhdx） |

---

## ⚠️ 注意事项

1. **导出过程必须完整**，不要中断
2. **unregister 之前**，确认 tar 文件大小合理（应接近原 vhdx）
3. **mirrored 网络模式下**，`ip addr` 看不到 eth0 IP，是正常现象
4. **WSL 启动时报 GPU 错误**（dxg ioctl failed）通常不影响 CPU 工作，但会影响 CUDA
5. **`/mnt/c` 访问**仍然可用，Windows ↔ WSL 互访不受影响

---

## 💡 进阶：定期备份

迁移完成后，建议定期备份 WSL（tar 包）：

```powershell
# 每月备份（在 PowerShell 中执行）
wsl --shutdown
$stamp = Get-Date -Format "yyyyMMdd"
wsl --export Ubuntu-22.04 "G:\WSL\backups\Ubuntu-22.04-$stamp.tar"
```

可以加入 Windows 任务计划程序自动执行。

---

⏮️ [← 01 C 盘瘦身](01-c-drive-cleanup.md) | [返回主页](../README.md) | 下一篇：[03 - 健康检查 →](03-wsl-health-check.md)

# 03 - WSL 健康检查

> **目标**：定期给 WSL "体检"，发现潜在问题

---

## 🩺 健康检查清单

完整脚本见 [`scripts/wsl_health.sh`](../scripts/wsl_health.sh)，覆盖 12 个维度：

| # | 检查项 | 健康标准 |
|---|---|---|
| 1 | 基本信息收集 | 用户/主机/系统版本 |
| 2 | systemd 整体状态 | `running` |
| 3 | 失败的服务 | 无 |
| 4 | 内存使用 | < 70% |
| 5 | Swap 使用 | < 50% |
| 6 | 磁盘使用 | < 85% |
| 7 | WSL 配置 (`/etc/wsl.conf`) | 包含 systemd / user 配置 |
| 8 | 网络 | DNS 配置正常 |
| 9 | 时区 + NTP | `Asia/Shanghai` + NTP active |
| 10 | Locale | `LANG` 已设置，无警告 |
| 11 | 系统错误日志 | 无近期错误 |
| 12 | 安全更新 | 可升级包数 = 0 |

---

## 🚀 一键体检

```bash
bash scripts/wsl_health.sh
```

---

## 🟢 已知"看似异常但实际正常"的现象

| 现象 | 原因 | 是否需要处理 |
|---|---|---|
| `ip addr` 看不到 eth0 的 IP | 网络模式为 `mirrored`（Windows 共享网络） | ❌ 不用处理 |
| `whoami` 返回 `root` 而不是普通用户 | `wsl --import` 后未设置默认用户 | ✅ 需要在 `/etc/wsl.conf` 加 `[user] default=xxx` |
| GPU 错误日志（dxg ioctl failed） | Windows GPU 驱动版本与 WSL 不匹配 | ⚠️ 仅影响 GPU 计算 |
| `user@1000.service` failed | 用户级 systemd 服务未启动 | ✅ `sudo loginctl enable-linger $USER` |
| `cloud-init` 相关服务 inactive | WSL 用不到 cloud-init | ❌ 可忽略 |
| 启动后 `df` 显示 1TB 总空间 | WSL2 vhdx 默认是动态扩展，最大 1TB | ❌ 正常 |

---

## 🔧 常见问题修复

### 问题 1：systemd 状态不是 `running`

```bash
# 检查是否启用了 systemd
cat /etc/wsl.conf
# 应包含 [boot] systemd=true

# 重启 WSL（Windows 端）
wsl --shutdown
wsl
```

### 问题 2：失败的服务列表里有内容

```bash
# 查看失败的服务
systemctl --failed

# 查看具体错误
journalctl -u <service-name> -n 50

# 重启该服务
sudo systemctl restart <service-name>

# 如果不需要，可以禁用
sudo systemctl disable <service-name>
```

### 问题 3：Locale 警告

```bash
# 生成 locale
sudo locale-gen en_US.UTF-8 zh_CN.UTF-8

# 设置默认
sudo update-locale LANG=en_US.UTF-8
```

### 问题 4：时区不对

```bash
# 设置时区
sudo timedatectl set-timezone Asia/Shanghai

# 验证
timedatectl
```

### 问题 5：NTP 未同步

```bash
sudo timedatectl set-ntp true
timedatectl
```

---

## 📋 本次体检结果（2026-06-27）

```
✅ systemd: running
✅ 内存: 23 GB（11% 使用）
✅ Swap: 6 GB
✅ 磁盘: 6% 使用率
✅ 时区: Asia/Shanghai
✅ Locale: C.UTF-8
✅ NTP: 已同步

⚠️ GPU 驱动报错（dxg ioctl failed -2）→ 仅影响 CUDA
⚠️ user@1000.service failed → 已通过 enable-linger 修复
⚠️ 2 个安全更新未升级 → 已通过 apt upgrade 修复
```

---

## 🔄 建议的体检频率

| 频率 | 操作 |
|---|---|
| 每周一次 | `bash scripts/wsl_health.sh` |
| 每月一次 | `sudo apt update && sudo apt upgrade -y` |
| 每季度一次 | `wsl --export` 备份 vhdx |
| 半年一次 | 压缩 vhdx（迁移文档有说明） |

---

⏮️ [← 02 WSL 迁移](02-wsl-migration.md) | [返回主页](../README.md) | 下一篇：[04 - 优化方案 →](04-optimization.md)

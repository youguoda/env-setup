# 01 - C 盘深度瘦身

> **战果**：C 盘可用空间 **7.56 GB → 90.26 GB**（释放 82.7 GB）

---

## 🎯 总体策略

C 盘瘦身按 **风险/收益** 分 5 档进行：

| 档位 | 内容 | 风险 | 释放 |
|---|---|---|---|
| 第 1 档 | 系统垃圾（临时文件、缓存、日志） | 🟢 零风险 | ~4 GB |
| 第 2 档 | 开发工具缓存（IDE、构建工具） | 🟢 自动重建 | ~12 GB |
| 第 3 档 | AI 编辑器目录（如不用） | 🟡 按需 | ~3 GB |
| 第 4 档 | 大文件（休眠、页面、WSL） | 🔴 影响功能 | 50+ GB |
| 第 5 档 | 应用数据（聊天/网盘缓存） | 🟡 含个人数据 | ~25 GB |

---

## 🔍 分析工具

### 扫描 C 盘根目录各文件夹大小
```powershell
Get-ChildItem C:\ -Force -Directory -ErrorAction SilentlyContinue | ForEach-Object {
    $size = (Get-ChildItem $_.FullName -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
    [PSCustomObject]@{ Folder = $_.FullName; SizeGB = [math]::Round($size/1GB,2) }
} | Sort-Object SizeGB -Descending | Select-Object -First 15 | Format-Table -AutoSize
```

### 扫描 AppData 下的空间大户
```powershell
Get-ChildItem C:\Users\<USER>\AppData -Force -Directory | ForEach-Object {
    Get-ChildItem $_.FullName -Force -Directory | ForEach-Object {
        $size = (Get-ChildItem $_.FullName -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
        [PSCustomObject]@{ Path = $_.FullName; SizeGB = [math]::Round($size/1GB,2) }
    }
} | Sort-Object SizeGB -Descending | Select-Object -First 25 | Format-Table -AutoSize
```

---

## 🧹 清理脚本

完整脚本见 [`scripts/clean_c.ps1`](../scripts/clean_c.ps1)，主要包括：

### 第 1 档（系统垃圾）
```powershell
# Windows Update 下载缓存
Remove-Item "C:\Windows\SoftwareDistribution\Download\*" -Recurse -Force -ErrorAction SilentlyContinue

# 用户临时文件（注意排除 claude 等工具占用目录）
Get-ChildItem "C:\Users\<USER>\AppData\Local\Temp" -Force |
    Where-Object { $_.Name -ne "claude" } |
    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue

# 缩略图缓存（删除后 Windows 会自动重建）
Get-ChildItem "C:\Users\<USER>\AppData\Local\Microsoft\Windows\Explorer" -Filter "thumbcache_*.db" -Force |
    Remove-Item -Force -ErrorAction SilentlyContinue

# 浏览器缓存（Chrome / Edge）
Remove-Item "C:\Users\<USER>\AppData\Local\Google\Chrome\User Data\Default\Cache\*" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item "C:\Users\<USER>\AppData\Local\Microsoft\Edge\User Data\Profile 1\Cache\*" -Recurse -Force -ErrorAction SilentlyContinue
```

### 第 2 档（开发工具缓存）
```powershell
# JetBrains 旧版本（保留当前使用的版本）
$jbVersions = @("PyCharm2025.1","PyCharm2025.2","PyCharm2025.3","CLion2025.1","CLion2025.2","CLion2025.3")
foreach ($v in $jbVersions) {
    Remove-Item "C:\Users\<USER>\AppData\Roaming\JetBrains\$v" -Recurse -Force -ErrorAction SilentlyContinue
}

# VS Code 缓存（workspaceStorage 含工作区状态，删除后丢失断点等）
"Cache","CachedData","GPUCache","Code Cache","User\workspaceStorage" | ForEach-Object {
    Remove-Item "C:\Users\<USER>\AppData\Roaming\Code\$_\*" -Recurse -Force -ErrorAction SilentlyContinue
}

# Gradle 构建缓存
Remove-Item "C:\Users\<USER>\.gradle\caches\*" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item "C:\Users\<USER>\.gradle\wrapper\dists\*" -Recurse -Force -ErrorAction SilentlyContinue
```

### 第 4 档（关键大文件）

#### 关闭休眠（释放 ~19 GB）
```powershell
# 需要管理员权限
powercfg /h off
# 文件 C:\hiberfil.sys 会自动删除
```

#### 压缩 WSL2 vhdx（释放 15-30 GB）
```powershell
wsl --shutdown
# 使用 diskpart
diskpart
# 在 diskpart 提示符下：
#   select vdisk file="C:\Users\<USER>\AppData\Local\Packages\CanonicalGroupLimited.Ubuntu22.04LTS_79rhkp1fndgsc\LocalState\ext4.vhdx"
#   attach vdisk readonly
#   compact vdisk
#   detach vdisk
#   exit
```

或者更彻底的方案：**迁移 WSL 到其他盘**（见 [02-wsl-migration.md](02-wsl-migration.md)）。

---

## ⚠️ 注意事项

1. **Chrome / Edge / VS Code 运行时**，部分缓存文件被锁会被跳过 —— 不影响清理效果
2. **`workspaceStorage` 删除会丢失**：每个工作区的 undo 历史、断点、最近文件列表。代码不受影响
3. **`Windows\Installer` 不要乱删**：会导致以后无法卸载/修复软件
4. **休眠文件 `hiberfil.sys` 删除**：电源菜单的"休眠"选项会消失，但**不影响"睡眠"功能**
5. **WSL vhdx 压缩前必须** `wsl --shutdown`，否则文件被占用

---

## 🔁 复盘：本次清理释放空间

| 操作 | 释放空间 | C 盘可用 |
|---|---|---|
| 初始状态 | - | 7.56 GB |
| 第 1+2 档清理 | +18 GB | 25.83 GB |
| 关闭休眠 | +15 GB | 40.84 GB |
| WSL 迁移到 G 盘 | +49 GB | 90.26 GB |

---

⏮️ [返回主页](../README.md) | 下一篇：[02 - WSL 迁移 →](02-wsl-migration.md)

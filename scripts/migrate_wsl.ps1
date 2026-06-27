<#
.SYNOPSIS
    WSL2 迁移到其他盘（完整流程）
.DESCRIPTION
    将 WSL 发行版从 C 盘迁移到指定盘符（默认 G 盘）
    完整流程：关闭 WSL → 导出 → 注销 → 导入 → 修复默认用户
.PARAMETER Distro
    WSL 发行版名称（默认 Ubuntu-22.04）
.PARAMETER TargetDrive
    目标盘符（默认 G:）
.PARAMETER WslUser
    WSL 中的默认用户名（迁移后需要恢复）
.EXAMPLE
    .\migrate_wsl.ps1
    .\migrate_wsl.ps1 -Distro Ubuntu-22.04 -TargetDrive "G:" -WslUser "guoda"
#>
param(
    [string]$Distro = "Ubuntu-22.04",
    [string]$TargetDrive = "G:",
    [string]$WslUser = "guoda"
)

$ErrorActionPreference = 'Stop'

$TargetDir = "${TargetDrive}\WSL\$Distro"
$TarFile = "${TargetDrive}\WSL\$Distro.tar"

Write-Host "=========================================="
Write-Host "  WSL2 迁移"
Write-Host "=========================================="
Write-Host "  发行版:        $Distro"
Write-Host "  目标位置:      $TargetDir"
Write-Host "  备份 tar:      $TarFile"
Write-Host "  WSL 用户名:    $WslUser"
Write-Host "=========================================="

# 检查目标盘空间
$targetFree = (Get-PSDrive -Name $TargetDrive.Substring(0,1)).Free
Write-Host ("`n目标盘可用空间: {0:N2} GB (建议至少 120 GB)" -f ($targetFree/1GB))
if ($targetFree -lt 120GB) {
    Write-Host "⚠️ 目标盘空间不足 120 GB，建议先清理"
    $confirm = Read-Host "继续吗？(y/N)"
    if ($confirm -ne 'y') { exit 1 }
}

# 步骤 1：关闭 WSL
Write-Host "`n=== 步骤 1: 关闭 WSL ==="
wsl --shutdown
Start-Sleep -Seconds 3
Write-Host "✓ 已关闭"

# 创建目标目录
New-Item -Path "${TargetDrive}\WSL" -ItemType Directory -Force | Out-Null

# 步骤 2：导出
Write-Host "`n=== 步骤 2: 导出 WSL 到 tar 包（5-15 分钟）==="
$exportStart = Get-Date
wsl --export $Distro $TarFile
$exportEnd = Get-Date
if (Test-Path $TarFile) {
    $tarSize = (Get-Item $TarFile).Length
    Write-Host ("✓ 导出成功 ({0:N2} GB, 耗时 {1:N1} 分钟)" -f ($tarSize/1GB), (($exportEnd-$exportStart).TotalMinutes))
} else {
    Write-Host "❌ 导出失败"
    exit 1
}

# 步骤 3：注销
Write-Host "`n=== 步骤 3: 注销原 WSL（释放 C 盘空间）==="
$cBefore = (Get-PSDrive C).Free
wsl --unregister $Distro
Start-Sleep -Seconds 2
$cAfter = (Get-PSDrive C).Free
Write-Host ("✓ 已注销，C 盘释放 {0:N2} GB" -f (($cAfter-$cBefore)/1GB))

# 步骤 4：导入到新位置
Write-Host "`n=== 步骤 4: 从 $TargetDrive 导入（5-15 分钟）==="
$importStart = Get-Date
wsl --import $Distro $TargetDir $TarFile
$importEnd = Get-Date
Write-Host ("✓ 导入完成，耗时 {0:N1} 分钟" -f (($importEnd-$importStart).TotalMinutes))

# 步骤 5：修复默认用户
Write-Host "`n=== 步骤 5: 修复默认用户（$WslUser）==="
wsl -d $Distro -u root bash -c "printf '[boot]\nsystemd=true\n\n[user]\ndefault=$WslUser\n' > /etc/wsl.conf"
Write-Host "✓ /etc/wsl.conf 已配置"

# 重启 WSL 让配置生效
Write-Host "`n=== 重启 WSL 让配置生效 ==="
wsl --shutdown
Start-Sleep -Seconds 3
wsl -d $Distro -e whoami | Out-Null

# 验证
Write-Host "`n=== 验证 ==="
$user = wsl -d $Distro -e whoami
$running = wsl -d $Distro -e systemctl is-system-running
Write-Host "  默认用户: $user (期望: $WslUser)"
Write-Host "  systemd 状态: $running"

if ($user -eq $WslUser -and $running -eq "running") {
    Write-Host "`n=========================================="
    Write-Host "  🎉 迁移成功！"
    Write-Host "=========================================="
} else {
    Write-Host "`n⚠️ 验证未通过，请手动检查"
}

Write-Host "`n📌 注意事项："
Write-Host "  1. tar 包保留在 $TarFile，1-2 周后可手动删除"
Write-Host "  2. 新的 vhdx 在 $TargetDir\ext4.vhdx"
Write-Host "  3. .wslconfig 中已开启 sparseVhd=true，vhdx 会自动瘦身"

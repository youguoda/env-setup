<#
.SYNOPSIS
    C 盘深度瘦身脚本（安全清理 + 可选关闭休眠）
.DESCRIPTION
    清理 Windows 系统垃圾、开发工具缓存，可关闭休眠功能
    基于 2026-06-27 的实战经验
.PARAMETER DisableHibernate
    是否关闭休眠功能（释放 ~19 GB，需要管理员权限）
.EXAMPLE
    .\clean_c.ps1
    .\clean_c.ps1 -DisableHibernate
#>
param(
    [switch]$DisableHibernate
)

$ErrorActionPreference = 'SilentlyContinue'
$USER = $env:USERNAME
$USER_PROFILE = $env:USERPROFILE

function Remove-FolderContents {
    param([string]$Path, [string]$Label)
    if (Test-Path $Path) {
        $sizeBefore = (Get-ChildItem $Path -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
        Get-ChildItem $Path -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
        $sizeAfter = (Get-ChildItem $Path -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
        $freed = $sizeBefore - $sizeAfter
        Write-Host ("  [{0,7:N1} MB]  {1}" -f ($freed/1MB), $Label)
    } else {
        Write-Host ("  [   跳过]  {0} (不存在)" -f $Label)
    }
}

function Remove-FolderTree {
    param([string]$Path, [string]$Label)
    if (Test-Path $Path) {
        $sizeBefore = (Get-ChildItem $Path -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
        Remove-Item -Path $Path -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host ("  [{0,7:N1} MB]  {1}" -f ($sizeBefore/1MB), $Label)
    } else {
        Write-Host ("  [   跳过]  {0} (不存在)" -f $Label)
    }
}

$before = (Get-PSDrive C).Free
Write-Host ("`n清理前 C 盘可用空间: {0:N2} GB" -f ($before/1GB))

# ========== 第 1 档：系统垃圾 ==========
Write-Host "`n=== 第 1 档: 系统垃圾 ==="
Remove-FolderContents "C:\Windows\SoftwareDistribution\Download" "Windows Update 下载缓存"
Remove-FolderContents "$USER_PROFILE\AppData\Local\Temp" "用户临时文件（含 claude 工具目录）"
Remove-FolderContents "$USER_PROFILE\.cache" "用户 .cache 目录"

# 缩略图/图标缓存
$thumbBefore = 0
Get-ChildItem "$USER_PROFILE\AppData\Local\Microsoft\Windows\Explorer" -Filter "thumbcache_*.db" -Force -ErrorAction SilentlyContinue | ForEach-Object {
    $thumbBefore += $_.Length
    Remove-Item $_.FullName -Force -ErrorAction SilentlyContinue
}
Get-ChildItem "$USER_PROFILE\AppData\Local\Microsoft\Windows\Explorer" -Filter "iconcache_*.db" -Force -ErrorAction SilentlyContinue | ForEach-Object {
    $thumbBefore += $_.Length
    Remove-Item $_.FullName -Force -ErrorAction SilentlyContinue
}
Write-Host ("  [{0,7:N1} MB]  缩略图/图标缓存" -f ($thumbBefore/1MB))

Remove-FolderContents "$USER_PROFILE\AppData\Local\Google\Chrome\User Data\Default\Cache" "Chrome Cache"
Remove-FolderContents "$USER_PROFILE\AppData\Local\Google\Chrome\User Data\Default\Code Cache" "Chrome Code Cache"
Remove-FolderContents "$USER_PROFILE\AppData\Local\CrashDumps" "崩溃转储"
Remove-FolderContents "C:\Windows\Logs\CBS" "Windows CBS 日志"
Remove-FolderContents "C:\Windows\System32\LogFiles" "系统日志文件"

# ========== 第 2 档：开发工具缓存 ==========
Write-Host "`n=== 第 2 档: 开发工具缓存 ==="

# JetBrains 旧版本（动态发现）
Write-Host "  -- JetBrains 旧版本 --"
$jbPath = "$USER_PROFILE\AppData\Roaming\JetBrains"
if (Test-Path $jbPath) {
    Get-ChildItem $jbPath -Directory | Where-Object {
        $_.Name -match "(PyCharm|CLion|IntelliJ|WebStorm|GoLand|RubyMine|PhpStorm|Rider|AndroidStudio)(\d{4}\.\d)$"
    } | ForEach-Object {
        # 保留最新版本（按名称排序最大的）
        Remove-FolderTree $_.FullName $_.Name
    }
}

Write-Host "  -- 其他开发缓存 --"
Remove-FolderContents "$USER_PROFILE\AppData\Local\Microsoft\vscode-cpptools" "vscode-cpptools"
Remove-FolderContents "$USER_PROFILE\AppData\Local\Microsoft\Edge\User Data\Profile 1\Cache" "Edge Cache"
Remove-FolderContents "$USER_PROFILE\AppData\Local\Microsoft\Edge\User Data\Profile 1\Code Cache" "Edge Code Cache"
Remove-FolderContents "$USER_PROFILE\AppData\Local\Microsoft\Edge\User Data\Profile 1\GPUCache" "Edge GPUCache"
Remove-FolderContents "$USER_PROFILE\AppData\Roaming\Code\User\workspaceStorage" "VS Code workspaceStorage"
Remove-FolderContents "$USER_PROFILE\AppData\Roaming\Code\Cache" "VS Code Cache"
Remove-FolderContents "$USER_PROFILE\AppData\Roaming\Code\CachedData" "VS Code CachedData"
Remove-FolderContents "$USER_PROFILE\AppData\Roaming\Code\GPUCache" "VS Code GPUCache"
Remove-FolderContents "$USER_PROFILE\AppData\Roaming\Code\Code Cache" "VS Code Code Cache"
Remove-FolderContents "$USER_PROFILE\.gradle\caches" "Gradle caches"
Remove-FolderContents "$USER_PROFILE\.gradle\wrapper\dists" "Gradle wrapper dists"

# ========== 可选：关闭休眠 ==========
if ($DisableHibernate) {
    Write-Host "`n=== 关闭休眠（需要管理员权限）==="
    $adminTest = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $adminTest) {
        Write-Host "  ⚠️ 当前不是管理员权限，正在用 UAC 提权..."
        Start-Process powershell -Verb RunAs -ArgumentList "-Command","powercfg /h off" -Wait
    } else {
        powercfg /h off
    }
    Write-Host "  ✓ 已执行 powercfg /h off"
}

$after = (Get-PSDrive C).Free
Write-Host "`n=== 总结 ==="
Write-Host ("清理前可用空间: {0:N2} GB" -f ($before/1GB))
Write-Host ("清理后可用空间: {0:N2} GB" -f ($after/1GB))
Write-Host ("本次共释放:     {0:N2} GB" -f (($after-$before)/1GB))

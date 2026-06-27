#!/bin/bash
# WSL 健康检查脚本
# 用法：bash wsl_health.sh

echo "=========================================="
echo "       WSL 健康检查报告"
echo "=========================================="

echo ""
echo "=== 1. 基本信息 ==="
echo "  用户:   $(whoami)"
echo "  主机:   $(hostname)"
echo "  系统:   $(lsb_release -ds 2>/dev/null)"
echo "  内核:   $(uname -r)"
echo "  时间:   $(date)"
echo "  运行:   $(uptime -p)"

echo ""
echo "=== 2. systemd 整体状态 ==="
echo "  状态: $(systemctl is-system-running 2>&1)"
echo ""
echo "  失败的服务:"
FAILED=$(systemctl --failed --type=service --no-legend --no-pager 2>/dev/null | awk '{print $1, $4}')
if [ -z "$FAILED" ]; then
    echo "    ✓ 无失败服务"
else
    echo "$FAILED" | sed 's/^/    ⚠️ /'
fi

echo ""
echo "=== 3. 资源使用 ==="
echo "  内存:"
free -h | awk 'NR==2 {printf "    物理:  已用 %s / 总 %s (%.0f%%)\n", $3, $2, $3/$2*100}'
free -h | awk 'NR==3 {printf "    Swap:  已用 %s / 总 %s\n", $3, $2}'
echo ""
echo "  磁盘:"
df -h / 2>/dev/null | awk 'NR==1 {printf "    %-8s %8s %8s %8s %s\n", "Filesystem", "Size", "Used", "Avail", "Use%"} NR>1 {printf "    %-8s %8s %8s %8s %8s\n", $1, $2, $3, $4, $5}'
echo ""
echo "  CPU 负载: $(cat /proc/loadavg | awk '{print $1", "$2", "$3" (1/5/15分钟)"}')"

echo ""
echo "=== 4. WSL 配置 (/etc/wsl.conf) ==="
if [ -f /etc/wsl.conf ]; then
    cat /etc/wsl.conf | sed 's/^/    /'
else
    echo "    (无配置文件)"
fi

echo ""
echo "=== 5. 网络配置 ==="
IP=$(ip -4 addr show eth0 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
echo "  IP: ${IP:-未找到（mirrored 模式下正常）}"
echo "  DNS:"
cat /etc/resolv.conf 2>/dev/null | grep nameserver | head -3 | sed 's/^/    /'

echo ""
echo "=== 6. 时区 ==="
timedatectl 2>/dev/null | grep -E "Time zone|NTP service|System clock" | sed 's/^[[:space:]]*/    /'

echo ""
echo "=== 7. Locale ==="
LOCALE_OUT=$(locale 2>&1)
echo "$LOCALE_OUT" | grep -E "^LANG|^LC_" | head -3 | sed 's/^/    /'
LOCALE_WARNINGS=$(echo "$LOCALE_OUT" | grep -iE "warning|cannot")
if [ -n "$LOCALE_WARNINGS" ]; then
    echo "  ⚠️ Locale 警告:"
    echo "$LOCALE_WARNINGS" | head -3 | sed 's/^/    /'
else
    echo "  ✓ Locale 正常"
fi

echo ""
echo "=== 8. 最近系统错误日志（最多 8 条）==="
ERRORS=$(journalctl -p err -b --no-pager 2>/dev/null | tail -8)
if [ -n "$ERRORS" ]; then
    echo "$ERRORS" | sed 's/^/    /'
else
    echo "    ✓ 无错误日志"
fi

echo ""
echo "=== 9. 关键目录占用 ==="
du -sh /var/log /tmp /home 2>/dev/null | sed 's/^/    /'

echo ""
echo "=== 10. 包管理 ==="
UPDATABLE=$(apt list --upgradable 2>/dev/null | grep -c "/" )
echo "  可升级包数: $UPDATABLE"
SECURITY=$(apt list --upgradable 2>/dev/null | grep -ci "security")
if [ "$SECURITY" -gt 0 ]; then
    echo "  ⚠️ 其中含 $SECURITY 个安全更新"
fi

echo ""
echo "=== 11. 已装的关键开发工具 ==="
for cmd in python3 git vim tmux htop tree jq rg fd bat fzf zoxide starship eza node npm; do
    if command -v $cmd > /dev/null 2>&1; then
        printf "  ✓ %-10s" "$cmd"
    else
        printf "  - %-10s" "$cmd"
    fi
done
echo ""

echo ""
echo "=== 12. Shell 配置 ==="
echo "  当前 shell: $SHELL"
if [ -f ~/.bashrc ]; then
    ALIASES=$(grep -c "^alias" ~/.bashrc 2>/dev/null)
    echo "  .bashrc 中 alias 数: $ALIASES"
fi

echo ""
echo "=========================================="
echo "       检查完成"
echo "=========================================="

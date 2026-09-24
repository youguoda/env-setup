# shellcheck shell=bash
# guoda-blerc.sh - ble.sh 输入提示设置
# 路径: ~/.guoda/blerc,由 ~/.guoda/bashrc.sh 在 ble.sh --noattach 之后加载
#
# ble.sh 提供三类输入提示:
#   1. 灰色自动建议(按 → 或 Ctrl+F 接受,来自历史 + 补全源)
#   2. 语法高亮(命令存在绿色 / 不存在红色)
#   3. 菜单式 Tab 补全(方向键选择)

# ble.sh 没能加载时(TERM=dumb、非交互、加载失败)直接返回,避免刷 command not found
[[ ${BLE_VERSION-} ]] || return 0

# === 自动建议 ===
bleopt complete_auto_delay=120      # 停止输入多少毫秒后给建议(默认 1ms,容器里调大更稳)
bleopt complete_auto_history=1      # 从命令历史生成建议
bleopt complete_auto_wordbreaks=    # 不在路径分隔符处打断建议

# === 菜单补全 ===
bleopt complete_menu_style=align-nowrap
bleopt complete_menu_maxlines=10

# === 配色(灰色建议,终端不支持 256 色时会自动降级)===
ble-face -s auto_complete 'fg=242'
ble-face -s syntax_error  'fg=red'

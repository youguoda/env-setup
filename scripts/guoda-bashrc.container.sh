# shellcheck shell=bash
# guoda-bashrc.container.sh - 容器 myenv 子 shell 配置
# 路径: ~/.guoda/bashrc.sh
# 不包含宿主机 Docker/GPU/HF/conda 封装。

# === 0. 环境变量必须在 ble.sh 之前 ===
# USER/locale 自愈、BLESH_PATH 都在 env.sh;docker exec 场景下不先设,ble.sh 会警告
[ -f ~/.guoda/env.sh ] && source ~/.guoda/env.sh

# === 1. ble.sh(--noattach 延迟 attach)===
# 输入提示:灰色自动建议(→ / Ctrl+F 接受)、语法高亮、菜单式 Tab 补全
if [[ $- == *i* ]]; then
    _blesh="${BLESH_PATH:-}"
    if [ -z "$_blesh" ]; then
        _guoda_prefix="${GUODA_PREFIX:-}"
        if [ -z "$_guoda_prefix" ] && [ -f ~/.guoda/prefix ]; then
            _guoda_prefix="$(head -1 ~/.guoda/prefix)"
        fi
        _blesh="${_guoda_prefix:-$HOME/.local}/share/blesh/ble.sh"
    fi
    if [ -f "$_blesh" ]; then
        source "$_blesh" --noattach
        [ -f ~/.guoda/blerc ] && source ~/.guoda/blerc
    fi
    unset _blesh _guoda_prefix
fi

# === 2. 系统默认 + 用户 ~/.bashrc(容器默认行为先保留)===
[ -f /etc/bash.bashrc ] && source /etc/bash.bashrc
[ -f ~/.bashrc ] && source ~/.bashrc

# === 3. 再加载一次环境变量(覆盖 bashrc 对 PATH 的改动)===
[ -f ~/.guoda/env.sh ] && source ~/.guoda/env.sh

# === 4. 现代工具初始化 ===
command -v zoxide > /dev/null 2>&1 && eval "$(zoxide init bash)"
if command -v starship > /dev/null 2>&1; then
    export STARSHIP_CONFIG="${STARSHIP_CONFIG:-$HOME/.guoda/starship.toml}"
    eval "$(starship init bash)"
fi

if [ -n "${FZF_DIR:-}" ] && [ -f "$FZF_DIR/shell/key-bindings.bash" ]; then
    # shellcheck disable=SC1091
    source "$FZF_DIR/shell/key-bindings.bash"
    [ -f "$FZF_DIR/shell/completion.bash" ] && source "$FZF_DIR/shell/completion.bash"
elif [ -f ~/.fzf.bash ]; then
    # shellcheck disable=SC1090
    source ~/.fzf.bash
fi

# === 5. 公共别名/函数 ===
[ -f ~/.guoda/aliases.sh ] && source ~/.guoda/aliases.sh

# === 6. Yazi:退出时 cd 到浏览目录 ===
function y() {
    local tmp cwd
    tmp="$(mktemp -t "yazi-cwd.XXXXXX")"
    yazi "$@" --cwd-file="$tmp"
    if cwd="$(command cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
        builtin cd -- "$cwd" || return
    fi
    rm -f -- "$tmp"
}

# === 7. 启动提示 ===
echo -e "\033[0;36m[myenv]\033[0m 容器效率工具已加载(zoxide/eza/fzf/bat/yazi/uv/tldr)"
echo -e "  退出: \033[1;33mexit\033[0m | 文件管理器: \033[1;33my\033[0m | Python 包: \033[1;33muv\033[0m"

# === 8. ble.sh attach ===
[[ ${BLE_VERSION-} ]] && ble-attach

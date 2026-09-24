# shellcheck shell=bash
# guoda-env.container.sh - 容器效率工具环境变量(由 myenv 子 shell 加载)
# 安装后复制为 ~/.guoda/env.sh,__GUODA_PREFIX__ 会被安装脚本替换。
# 不改 ~/.bashrc / /etc/profile,也不设置 HF/conda/GPU。

# === 工具安装前缀(二进制 / ble.sh / fzf)===
export GUODA_PREFIX="__GUODA_PREFIX__"
export GUODA_CONTAINER=1
export BLESH_PATH="$GUODA_PREFIX/share/blesh/ble.sh"
export FZF_DIR="$GUODA_PREFIX/opt/fzf"
export YAZI_CONFIG_HOME="$HOME/.guoda/yazi"

# === PATH ===
export PATH="$GUODA_PREFIX/bin:$FZF_DIR/bin:$PATH"

# === 提示符标识 ===
export GUODA_ENV=1
export MYENV_ACTIVE=1

# === 命令历史(写到 ~/.guoda,不污染容器默认 history)===
export HISTFILE="$HOME/.guoda/bash_history"
export HISTSIZE=10000
export HISTFILESIZE=20000
export HISTCONTROL=ignoreboth

# === 编辑器 / Pager ===
export EDITOR="${EDITOR:-vim}"
export VISUAL="${VISUAL:-vim}"
if command -v batcat > /dev/null 2>&1; then
    export MANPAGER="sh -c 'col -bx | batcat -l man -p'"
elif command -v bat > /dev/null 2>&1; then
    export MANPAGER="sh -c 'col -bx | bat -l man -p'"
fi
export BAT_THEME="${BAT_THEME:-Monokai Extended}"
export LESS="-FRSXMI"

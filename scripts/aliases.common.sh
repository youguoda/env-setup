# shellcheck shell=bash
# aliases.common.sh - WSL 与服务器共用的别名/函数(单一真相源)
#
# 部署:由安装脚本拷贝到 home,再被各自的 bashrc source —— 与仓库解耦
#   WSL    → ~/.config/guoda/aliases.sh  (restore.sh / install_tools.sh 部署)
#   服务器 → ~/.guoda/aliases.sh         (setup-myenv.sh 部署)
#
# 改这一个文件 = 两端同时生效。机器专属的别名各自放在自己的 bashrc 里。

# === ls → eza ===
if command -v eza > /dev/null 2>&1; then
    alias ls='eza --icons --group-directories-first'
    alias ll='eza -la --icons --group-directories-first --git'
    alias la='eza -a --icons --group-directories-first'
    alias lt='eza --tree --icons --level=2'
    alias ltl='eza --tree --icons --level=3'
fi

# === cat → bat ===
if command -v batcat > /dev/null 2>&1; then
    alias cat='batcat -pp'
    alias bat='batcat'
elif command -v bat > /dev/null 2>&1; then
    alias cat='bat -pp'
fi

# === find → fd / grep → rg ===
# 注意:fd/rg 与 find/grep 的命令行接口并不兼容,这里覆盖原命令是刻意取舍
command -v fd > /dev/null 2>&1 && alias find='fd'
command -v rg > /dev/null 2>&1 && alias grep='rg'

# === 导航 ===
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias cls='clear'
alias h='history'
alias df='df -h'
alias du='du -h'
alias free='free -h'

# === systemctl ===
alias sc='systemctl'
alias scs='systemctl status'
alias scr='systemctl restart'
alias sce='systemctl enable --now'
alias scd='systemctl disable --now'
alias jctl='journalctl -u'

# === apt(root 直接执行,普通用户自动加 sudo;运行时按 id 判断)===
_apt() { if [ "$(id -u)" -eq 0 ]; then command apt "$@"; else sudo apt "$@"; fi; }
alias ai='_apt install'
alias au='_apt update && _apt upgrade -y'
alias aq='apt search'
alias as='apt show'
alias ar='_apt remove'

# === git ===
alias g='git'
alias gs='git status'
alias gd='git diff'
alias gl='git log --oneline -20'
alias gp='git pull'
alias gP='git push'
alias gaa='git add --all'
alias gc='git commit'
alias gco='git checkout'

# === docker compose ===
alias dc='docker compose'

# === 杂项 ===
alias howto='tldr'
alias hg='history | grep'
alias venv='source .venv/bin/activate 2>/dev/null || source venv/bin/activate 2>/dev/null || echo "未找到虚拟环境"'

# === 函数 ===
# 解压(自动识别类型)
extract() {
    if [ -f "$1" ]; then
        case "$1" in
            *.tar.bz2|*.tbz2) tar xjf "$1" ;;
            *.tar.gz|*.tgz)   tar xzf "$1" ;;
            *.tar.xz)         tar xJf "$1" ;;
            *.tar)            tar xf  "$1" ;;
            *.bz2)            bunzip2 "$1" ;;
            *.rar)            unrar x "$1" ;;
            *.gz)             gunzip  "$1" ;;
            *.zip)            unzip   "$1" ;;
            *.7z)             7z x    "$1" ;;
            *) echo "不认识的后缀: $1" ;;
        esac
    else
        echo "文件不存在: $1"
    fi
}

# 创建并进入目录
mkcd() { mkdir -p "$1" && cd "$1" || return; }

# 查端口占用
who-listen() { sudo lsof -i :"$1" 2>/dev/null || ss -tlnp | grep ":$1 "; }
alias port='who-listen'

# 显示外部 IP
myip() { curl -s ifconfig.me; echo; }

# systemctl 日志
logs() { journalctl -u "$1" -n 100 --no-pager; }

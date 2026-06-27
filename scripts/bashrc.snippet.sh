# .bashrc 优化片段
# 通过 install_tools.sh 自动追加到 ~/.bashrc
# 也可手动 cat bashrc.snippet.sh >> ~/.bashrc

# >>> guoda optimization begin >>>
# === PATH ===
export PATH="$HOME/.local/bin:$HOME/.fzf/bin:$PATH"

# === 现代工具初始化 ===
# zoxide (智能 cd): 用 z 而不是 cd
eval "$(zoxide init bash)"
# starship 提示符
eval "$(starship init bash)"
# fzf 集成（Ctrl+R 历史搜索, Ctrl+T 文件查找, Alt+C 进入目录）
[ -f ~/.fzf.bash ] && source ~/.fzf.bash
# bat 主题（适配深色终端）
export BAT_THEME="Monokai Extended"
export MANPAGER="sh -c 'col -bx | batcat -l man -p'"

# === 别名：让常用命令更顺手 ===
# ls 替换为 eza（彩色、图标、git 状态）
alias ls='eza --icons --group-directories-first'
alias ll='eza -la --icons --group-directories-first --git'
alias la='eza -a --icons --group-directories-first'
alias lt='eza --tree --icons --level=2'
alias ltl='eza --tree --icons --level=3'

# cat 替换为 bat（带语法高亮）
alias cat='batcat -pp'
alias bat='batcat'

# find 替换为 fd
alias find='fd'

# grep 替换为 ripgrep
alias grep='rg'

# 常用快捷
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias cls='clear'
alias h='history'
alias df='df -h'
alias du='du -h'
alias free='free -h'

# systemctl 简写
alias sc='systemctl'
alias scs='systemctl status'
alias scr='systemctl restart'
alias sce='systemctl enable --now'
alias scd='systemctl disable --now'
alias jctl='journalctl -u'

# apt 简写
alias ai='sudo apt install'
alias au='sudo apt update && sudo apt upgrade -y'
alias aq='apt search'
alias as='apt show'
alias ar='sudo apt remove'

# git 简写
alias g='git'
alias gs='git status'
alias gd='git diff'
alias gl='git log --oneline -20'
alias gp='git pull'
alias gP='git push'
alias gaa='git add --all'
alias gc='git commit'

# WSL ↔ Windows 互访（注意：14393 是 Windows 用户名，迁移到新机器时需要修改）
alias winhome='cd /mnt/c/Users/14393'
alias explorer='explorer.exe'
alias open='explorer.exe'
alias code='code.exe'

# 快速进入项目目录
alias proj='cd ~/projects 2>/dev/null || cd ~ && echo "提示：用 z <关键词> 智能跳转"'

# tldr 用法
alias howto='tldr'

# Docker compose（如安装了 docker）
alias dc='docker compose'

# Python venv 快速激活
alias venv='source .venv/bin/activate 2>/dev/null || source venv/bin/activate 2>/dev/null || echo "未找到虚拟环境"'

# === 实用函数 ===
# 提取压缩包（自动识别类型）
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
mkcd() { mkdir -p "$1" && cd "$1"; }

# 快速端口查找
who-listen() { sudo lsof -i :"$1" 2>/dev/null || ss -tlnp | grep ":$1 "; }
alias port='who-listen'

# 显示外部 IP
myip() { curl -s ifconfig.me; echo; }

# 简化 systemctl 日志查看
logs() { journalctl -u "$1" -n 100 --no-pager; }

# 历史命令搜索增强
alias hg='history | grep'

# 让 less 更友好
export LESS="-FRSXMI"

# 默认编辑器
export EDITOR=vim
export VISUAL=vim

# <<< guoda optimization end <<<

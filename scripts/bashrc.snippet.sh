# shellcheck shell=bash
# .bashrc 优化片段
# 通过 restore.sh / install_tools.sh 自动追加到 ~/.bashrc
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

# === 公共别名/函数（单一真相源: scripts/aliases.common.sh）===
[ -f ~/.config/guoda/aliases.sh ] && source ~/.config/guoda/aliases.sh

# === WSL 专属 ===
# WSL ↔ Windows 互访（14393 是 Windows 用户名，由 restore.sh 自动替换为实际用户名）
alias winhome='cd /mnt/c/Users/14393'
alias explorer='explorer.exe'
alias open='explorer.exe'
alias code='code.exe'

# 快速进入项目目录
alias proj='cd ~/projects 2>/dev/null || cd ~ && echo "提示：用 z <关键词> 智能跳转"'

# === less / 编辑器 ===
export LESS="-FRSXMI"
export EDITOR=vim
export VISUAL=vim
# <<< guoda optimization end <<<

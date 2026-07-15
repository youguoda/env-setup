#!/bin/bash
# ====================================================================
# uninstall.sh - 一键卸载/还原到初始状态
#
# 把 restore.sh / install_tools.sh / setup-myenv.sh 装的东西清掉:
#   - ~/.bashrc 里的 guoda 配置块
#   - ~/.config/guoda/、~/.guoda/(配置)
#   - ~/.local/bin 下的 zoxide/starship/eza/yazi、~/.local/share/blesh
#   - ~/.fzf、~/.nvm、~/miniconda3(及 ~/.condarc/~/.conda)
#   - /usr/local/bin/myenv、myenv-clean、fd、bat(需 sudo)
#   - pip --user 装的 nvitop/gpustat/hf_transfer/huggingface_hub
#
# 默认【绝不】动的东西(避免误删)：
#   - 你的数据: ~/models ~/projects ~/data ~/logs   → 用 --purge-data 才删
#   - apt 系统包(htop/ripgrep/... )                → 用 --remove-apt 才删
#   - apt 源(/etc/apt/sources.list)               → 用 --restore-apt 才还原
#   - 各种 .bak 备份文件                            → 一律保留
#   - /etc/wsl.conf(restore.sh 无备份,不敢乱动)   → 只提示
#
# 用法:
#   bash uninstall.sh --dry-run     # 先预览会删什么(强烈建议先跑这个)
#   bash uninstall.sh               # 交互式卸载(默认保守)
#   bash uninstall.sh -y            # 不确认,直接卸载
#   bash uninstall.sh --purge-data  # 连数据目录一起删(危险!)
#   bash uninstall.sh --help
# ====================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib.sh
source "$SCRIPT_DIR/lib.sh"

# === 选项 ===
DRY_RUN=false
ASSUME_YES=false
PURGE_DATA=false
REMOVE_APT=false
RESTORE_APT=false
KEEP_TOOLS=false

CURRENT_USER="$(whoami)"

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dry-run)     DRY_RUN=true ;;
            -y|--yes)      ASSUME_YES=true ;;
            --purge-data)  PURGE_DATA=true ;;
            --remove-apt)  REMOVE_APT=true ;;
            --restore-apt) RESTORE_APT=true ;;
            --keep-tools)  KEEP_TOOLS=true ;;
            -h|--help)
                cat <<'EOF'
uninstall.sh - 卸载/还原到初始状态

用法: bash uninstall.sh [选项]

选项:
  --dry-run        只打印会做什么,不真正删除(建议先跑一遍)
  -y, --yes        跳过所有确认
  --keep-tools     保留 ~/.local/bin 工具、conda、nvm、fzf(只清配置)
  --purge-data     ⚠ 连数据目录一起删: ~/models ~/projects ~/data ~/logs
  --remove-apt     apt remove 掉本项目装的系统包(htop/ripgrep/...)
  --restore-apt    从最近的 .bak 还原 /etc/apt/sources.list
  -h, --help       显示帮助

默认(不加危险参数)只清理本项目装的配置与工具,不动你的数据、
apt 系统包、apt 源和各种 .bak 备份。
EOF
                exit 0
                ;;
            *) log_warn "未知参数: $1(忽略)" ;;
        esac
        shift
    done
}

# === 工具函数 ===

# 删除文件/目录(存在才删,dry-run 只打印,可选 sudo)
rm_path() {
    local desc="$1" path="$2" use_sudo="${3:-}"
    if [ ! -e "$path" ] && [ ! -L "$path" ]; then
        return 0
    fi
    if [ "$DRY_RUN" = true ]; then
        log_note "[dry-run] 删除 $desc → $path"
        return 0
    fi
    if [ "$use_sudo" = sudo ]; then
        sudo rm -rf -- "$path" && log_info "已删除 $desc" || log_warn "删除失败: $path"
    else
        rm -rf -- "$path" && log_info "已删除 $desc" || log_warn "删除失败: $path"
    fi
}

confirm() {
    [ "$ASSUME_YES" = true ] && return 0
    [ "$DRY_RUN" = true ] && return 0
    local prompt="$1"
    if [ ! -t 0 ]; then
        log_warn "非交互环境,默认跳过: $prompt"
        return 1
    fi
    echo -ne "${YELLOW}  $prompt [y/N]${NC} "
    local a
    read -r a
    [ "$a" = y ] || [ "$a" = Y ]
}

# === 1. ~/.bashrc 里的 guoda 配置块 ===
clean_bashrc() {
    log_step "清理 ~/.bashrc 配置块"
    local rc="$HOME/.bashrc"
    if [ ! -f "$rc" ]; then
        log_note "没有 $rc,跳过"
        return
    fi
    if ! grep -q "# >>> guoda optimization begin >>>" "$rc"; then
        log_note "$rc 里没有 guoda 配置块,跳过"
        return
    fi
    if [ "$DRY_RUN" = true ]; then
        log_note "[dry-run] 从 $rc 移除 guoda 配置块(begin..end)"
        return
    fi
    cp "$rc" "$rc.pre-uninstall.$(date +%s)"
    sed -i '/# >>> guoda optimization begin >>>/,/# <<< guoda optimization end <<</d' "$rc"
    log_info "已移除 guoda 配置块(原文件已另存 .pre-uninstall.*)"
}

# === 2. 配置目录 ===
clean_configs() {
    log_step "清理配置目录"
    rm_path "WSL 公共别名 (~/.config/guoda)" "$HOME/.config/guoda"
    rm_path "服务器配置 (~/.guoda)"           "$HOME/.guoda"
}

# === 3. 工具链 ===
clean_tools() {
    log_step "清理工具链"
    if [ "$KEEP_TOOLS" = true ]; then
        log_note "--keep-tools:保留工具链,跳过"
        return
    fi

    # ~/.local/bin 下本项目装的二进制
    for b in zoxide starship eza yazi nvitop gpustat; do
        rm_path ".local/bin/$b" "$HOME/.local/bin/$b"
    done
    rm_path "ble.sh (.local/share/blesh)" "$HOME/.local/share/blesh"

    # fzf / nvm / miniconda
    rm_path "fzf (.fzf)"        "$HOME/.fzf"
    rm_path ".fzf.bash"         "$HOME/.fzf.bash"
    rm_path "nvm (.nvm)"        "$HOME/.nvm"
    rm_path "Miniconda (miniconda3)" "$HOME/miniconda3"
    rm_path ".condarc"          "$HOME/.condarc"
    rm_path ".conda"            "$HOME/.conda"

    # pip --user 装的包(best-effort)
    local pip_bin=""
    if command -v pip3 > /dev/null 2>&1; then pip_bin="pip3"
    elif command -v pip > /dev/null 2>&1; then pip_bin="pip"; fi
    if [ -n "$pip_bin" ]; then
        if [ "$DRY_RUN" = true ]; then
            log_note "[dry-run] $pip_bin uninstall -y nvitop gpustat hf_transfer huggingface_hub"
        else
            $pip_bin uninstall -y nvitop gpustat hf_transfer huggingface_hub > /dev/null 2>&1 \
                && log_info "已 pip uninstall GPU/HF 工具" \
                || log_note "pip uninstall 跳过(可能本就没装)"
        fi
    fi
}

# === 4. /usr/local/bin 下的命令与 symlink(需 sudo) ===
clean_launchers() {
    log_step "清理 /usr/local/bin 命令与 symlink(需 sudo)"
    rm_path "myenv 命令"       "/usr/local/bin/myenv"       sudo
    rm_path "myenv-clean 命令" "/usr/local/bin/myenv-clean" sudo
    # fd/bat 是指向 fdfind/batcat 的兼容 symlink,只在确认是 symlink 时删
    for l in fd bat; do
        if [ -L "/usr/local/bin/$l" ]; then
            rm_path "symlink /usr/local/bin/$l" "/usr/local/bin/$l" sudo
        fi
    done
}

# === 5. apt 系统包(仅 --remove-apt) ===
remove_apt_packages() {
    [ "$REMOVE_APT" = true ] || return 0
    log_step "移除 apt 系统包(--remove-apt)"
    local pkgs="htop tree ripgrep fd-find bat tldr p7zip-full"
    log_warn "将 apt remove: $pkgs"
    log_warn "(保留 build-essential/ca-certificates/unzip/zip 等常用基础包)"
    if ! confirm "确认移除这些 apt 包?"; then
        log_note "跳过 apt 包移除"
        return
    fi
    if [ "$DRY_RUN" = true ]; then
        log_note "[dry-run] sudo apt remove -y $pkgs"
        return
    fi
    # shellcheck disable=SC2086
    sudo DEBIAN_FRONTEND=noninteractive apt remove -y $pkgs 2>&1 | tail -3 \
        && log_info "apt 包已移除"
}

# === 6. 还原 apt 源(仅 --restore-apt) ===
restore_apt_sources() {
    [ "$RESTORE_APT" = true ] || return 0
    log_step "还原 apt 源(--restore-apt)"
    local newest
    newest=$(ls -t /etc/apt/sources.list.bak.* 2>/dev/null | head -1)
    if [ -z "$newest" ]; then
        log_note "没找到 /etc/apt/sources.list.bak.*,跳过"
        return
    fi
    if [ "$DRY_RUN" = true ]; then
        log_note "[dry-run] 用 $newest 覆盖 /etc/apt/sources.list"
        return
    fi
    sudo cp "$newest" /etc/apt/sources.list && log_info "已从 $newest 还原 apt 源"
}

# === 7. 数据目录(仅 --purge-data,危险) ===
purge_data() {
    [ "$PURGE_DATA" = true ] || return 0
    log_step "删除数据目录(--purge-data)"
    log_warn "⚠ 这会删除下列目录及其【全部内容】(模型/代码/结果/日志):"
    for d in "$HOME/models" "$HOME/projects" "$HOME/data" "$HOME/logs"; do
        [ -e "$d" ] && echo "    - $d  ($(du -sh "$d" 2>/dev/null | cut -f1))"
    done
    if ! confirm "真的要删掉以上数据吗?此操作不可恢复!"; then
        log_note "已取消数据删除(明智)"
        return
    fi
    for d in "$HOME/models" "$HOME/projects" "$HOME/data" "$HOME/logs"; do
        rm_path "数据目录 $d" "$d"
    done
}

# === 8. 系统开关 ===
system_tweaks() {
    log_step "系统开关"
    if confirm "关闭 enable-linger(restore.sh 曾开启)?"; then
        if [ "$DRY_RUN" = true ]; then
            log_note "[dry-run] sudo loginctl disable-linger $CURRENT_USER"
        else
            sudo loginctl disable-linger "$CURRENT_USER" 2>/dev/null \
                && log_info "已关闭 enable-linger" \
                || log_note "disable-linger 跳过"
        fi
    else
        log_note "保留 enable-linger"
    fi
    if [ -f /etc/wsl.conf ]; then
        log_warn "/etc/wsl.conf 存在但没有备份(restore.sh 是直接覆盖写的),未自动改动"
        log_note "如需还原,请手动检查 /etc/wsl.conf"
    fi
}

# === 汇总 ===
summary() {
    log_step "完成"
    if [ "$DRY_RUN" = true ]; then
        echo -e "${CYAN}  以上为 dry-run 预览,未做任何改动。去掉 --dry-run 才会真正执行。${NC}"
    else
        echo -e "${GREEN}  ✓ 卸载完成。${NC}"
    fi
    cat <<EOF

📌 默认保留(如需清理见对应参数):
  - 数据目录 ~/models ~/projects ~/data ~/logs   → --purge-data
  - apt 系统包(htop/ripgrep/...)                → --remove-apt
  - apt 源 /etc/apt/sources.list                 → --restore-apt
  - 各种 .bak / .pre-uninstall.* 备份            → 一律保留(可自行删)

🔄 让当前终端回到干净状态:重开一个终端,或 exec bash
EOF
}

main() {
    parse_args "$@"
    : "${HOME:?HOME 未设置,拒绝执行}"

    log_step "卸载 guoda 环境配置"
    log_info "用户: $CURRENT_USER   家目录: $HOME"
    if [ "$DRY_RUN" = true ]; then
        log_note "DRY-RUN 模式:只预览不改动"
    else
        log_warn "将清理本项目装的配置与工具(默认不动数据/apt 包/备份)"
        if ! confirm "继续?"; then
            log_note "已取消"
            exit 0
        fi
    fi

    clean_bashrc
    clean_configs
    clean_tools
    clean_launchers
    remove_apt_packages
    restore_apt_sources
    purge_data
    system_tweaks
    summary
}

main "$@"

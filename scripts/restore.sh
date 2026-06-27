#!/bin/bash
# ====================================================================
# WSL 环境一键还原脚本
#
# 用途：在新装 WSL 或新机器上，一键恢复完整开发环境
#
# 包含：
#   1. apt 清华源（可选）
#   2. 系统更新 + 基础工具（htop/tree/ripgrep/fd/bat/tldr...）
#   3. 现代工具（zoxide/starship/fzf/eza）
#   4. Node.js（通过 nvm，gitee 镜像）
#   5. ~/.bashrc 配置（30+ 别名 + 函数）
#   6. /etc/wsl.conf 配置
#   7. systemd 用户服务修复
#   8. 自动检测 Windows 用户名
#
# 用法：
#   bash restore.sh                 # 全自动执行所有步骤
#   bash restore.sh --skip-node     # 跳过 Node.js 安装
#   bash restore.sh --help          # 查看所有选项
#
# 幂等性：重复执行安全，已安装的工具会自动跳过
# ====================================================================

set -uo pipefail

# === 颜色 ===
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info()  { echo -e "${GREEN}  ✓${NC} $1"; }
log_warn()  { echo -e "${YELLOW}  ⚠${NC} $1"; }
log_error() { echo -e "${RED}  ✗${NC} $1"; }
log_step()  { echo -e "\n${BLUE}${BOLD}=== $1 ===${NC}"; }
log_note()  { echo -e "${CYAN}  ℹ${NC} $1"; }

# === 错误追踪 ===
ERRORS=()
SKIP_APT_MIRROR=false
SKIP_SYSTEM_UPDATE=false
SKIP_NODE=false
SKIP_WSL_CONF=false
SKIP_BASHRC=false

track_error() {
    ERRORS+=("$1")
    log_error "$1"
}

# === 解析参数 ===
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --skip-apt-mirror)     SKIP_APT_MIRROR=true ;;
            --skip-system-update)  SKIP_SYSTEM_UPDATE=true ;;
            --skip-node)           SKIP_NODE=true ;;
            --skip-wsl-conf)       SKIP_WSL_CONF=true ;;
            --skip-bashrc)         SKIP_BASHRC=true ;;
            -h|--help)
                cat <<EOF
WSL 环境一键还原脚本

用法: bash restore.sh [选项]

选项:
  --skip-apt-mirror      跳过 apt 清华源切换
  --skip-system-update   跳过 apt update/upgrade
  --skip-node            跳过 Node.js / nvm 安装
  --skip-wsl-conf        跳过 /etc/wsl.conf 配置
  --skip-bashrc          跳过 ~/.bashrc 配置
  -y, --yes              所有交互都回答 yes（默认行为）
  -h, --help             显示此帮助信息

示例:
  bash restore.sh                          # 全自动执行
  bash restore.sh --skip-node --skip-bashrc  # 跳过 Node 和 .bashrc
EOF
                exit 0
                ;;
            *)
                log_warn "未知参数: $1（忽略）"
                ;;
        esac
        shift
    done
}

# === 步骤 0: 环境检查 ===
check_env() {
    log_step "步骤 0/8: 环境检查"

    # 必须在 WSL 中
    if ! grep -qi WSL /proc/version 2>/dev/null; then
        track_error "当前不在 WSL 环境中，脚本仅支持 WSL"
        exit 1
    fi

    # 当前用户（不能用 root）
    CURRENT_USER=$(whoami)
    if [ "$CURRENT_USER" = "root" ]; then
        log_warn "当前是 root，建议以普通用户运行（脚本会用 sudo 提权）"
        log_warn "继续？(Ctrl+C 取消，回车继续)"
        read
    fi

    log_info "环境: $(lsb_release -ds 2>/dev/null || cat /etc/os-release | grep PRETTY_NAME | cut -d= -f2)"
    log_info "用户: $CURRENT_USER"
    log_info "家目录: $HOME"

    # 检查 sudo 可用
    if ! sudo -n true 2>/dev/null; then
        log_warn "需要 sudo 权限，运行过程中可能提示输入密码"
    fi

    # 获取脚本所在目录
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    log_note "脚本目录: $SCRIPT_DIR"
}

# === 步骤 1: apt 清华源 ===
setup_apt_mirror() {
    log_step "步骤 1/8: 配置 apt 清华源"

    if [ "$SKIP_APT_MIRROR" = true ]; then
        log_note "已跳过（--skip-apt-mirror）"
        return
    fi

    if grep -q "mirrors.tuna.tsinghua.edu.cn" /etc/apt/sources.list 2>/dev/null; then
        log_info "apt 已是清华源，跳过"
        return
    fi

    sudo cp /etc/apt/sources.list /etc/apt/sources.list.bak.$(date +%s) 2>/dev/null
    sudo sed -i 's|http://archive.ubuntu.com|https://mirrors.tuna.tsinghua.edu.cn|g' /etc/apt/sources.list
    sudo sed -i 's|http://security.ubuntu.com|https://mirrors.tuna.tsinghua.edu.cn|g' /etc/apt/sources.list
    sudo sed -i 's|http://[a-z]*.archive.ubuntu.com|https://mirrors.tuna.tsinghua.edu.cn|g' /etc/apt/sources.list
    log_info "apt 源已切换到清华镜像"
}

# === 步骤 2: 系统更新 + 基础工具 ===
install_apt_packages() {
    log_step "步骤 2/8: 系统更新 + 基础工具"

    if [ "$SKIP_SYSTEM_UPDATE" = false ]; then
        log_note "执行 apt update..."
        sudo apt update || track_error "apt update 失败"

        log_note "执行 apt upgrade..."
        sudo DEBIAN_FRONTEND=noninteractive apt upgrade -y || track_error "apt upgrade 失败"
    else
        log_note "已跳过系统更新（--skip-system-update）"
    fi

    log_note "安装基础工具..."
    sudo DEBIAN_FRONTEND=noninteractive apt install -y \
        htop tree bash-completion \
        ripgrep fd-find bat \
        tldr ca-certificates \
        unzip zip p7zip-full \
        build-essential \
        2>&1 | tail -3 || track_error "基础工具安装失败"

    # 兼容 symlink
    [ ! -L /usr/local/bin/fd ] && sudo ln -sf "$(which fdfind)" /usr/local/bin/fd
    [ ! -L /usr/local/bin/bat ] && sudo ln -sf "$(which batcat)" /usr/local/bin/bat
    log_info "基础工具就绪（htop/tree/rg/fd/bat/tldr/...）"
}

# === 步骤 3: 现代工具 ===
install_modern_tools() {
    log_step "步骤 3/8: 现代工具（zoxide/starship/fzf/eza）"

    mkdir -p ~/.local/bin

    # 检测 github 连通性
    test_github() {
        curl -sI --max-time 5 https://github.com > /dev/null 2>&1 && return 0 || return 1
    }

    # 通过代理下载
    proxy_fetch() {
        local url=$1 output=$2
        if test_github; then
            curl -fL --max-time 60 "$url" -o "$output" 2>/dev/null && return 0
        fi
        for proxy in "https://ghproxy.com/" "https://gh-proxy.com/" "https://mirror.ghproxy.com/"; do
            if curl -fL --max-time 60 "${proxy}${url}" -o "$output" 2>/dev/null; then
                return 0
            fi
        done
        return 1
    }

    test_github && log_note "github 直连可用" || log_note "github 直连不通，将使用代理"

    # --- zoxide ---
    if [ -f ~/.local/bin/zoxide ]; then
        log_info "zoxide 已存在"
    else
        log_note "安装 zoxide..."
        if proxy_fetch "https://github.com/ajeetdsouza/zoxide/releases/latest/download/zoxide-x86_64-unknown-linux-musl" ~/.local/bin/zoxide; then
            chmod +x ~/.local/bin/zoxide
            log_info "zoxide 安装完成"
        else
            track_error "zoxide 安装失败（网络）"
        fi
    fi

    # --- starship ---
    if [ -f ~/.local/bin/starship ]; then
        log_info "starship 已存在"
    else
        log_note "安装 starship..."
        if curl -sS --max-time 30 https://starship.rs/install.sh | sh -s -- -y -b ~/.local/bin -f > /dev/null 2>&1; then
            log_info "starship 安装完成"
        else
            URL="https://github.com/starship/starship/releases/latest/download/starship-x86_64-unknown-linux-musl.tar.gz"
            if proxy_fetch "$URL" /tmp/starship.tar.gz; then
                tar xzf /tmp/starship.tar.gz -C ~/.local/bin/ && rm /tmp/starship.tar.gz
                log_info "starship 安装完成（github）"
            else
                track_error "starship 安装失败"
            fi
        fi
    fi

    # --- fzf ---
    if [ -d ~/.fzf ]; then
        log_info "fzf 已存在"
    else
        log_note "安装 fzf..."
        if git clone --depth 1 https://gitee.com/mirrors/fzf.git ~/.fzf 2>/dev/null; then
            yes | ~/.fzf/install --all --no-update-rc --no-bash --no-zsh --no-fish > /dev/null 2>&1
            log_info "fzf 安装完成"
        else
            track_error "fzf 安装失败"
        fi
    fi

    # --- eza ---
    if [ -f ~/.local/bin/eza ]; then
        log_info "eza 已存在"
    else
        log_note "安装 eza..."
        API_URL="https://api.github.com/repos/eza-community/eza/releases/latest"
        EZA_VERSION=""
        test_github && EZA_VERSION=$(curl -sL --max-time 15 "$API_URL" | grep -oP '"tag_name":\s*"\Kv[^"]+' | head -1)
        if [ -z "$EZA_VERSION" ]; then
            for proxy in "https://ghproxy.com/" "https://gh-proxy.com/"; do
                EZA_VERSION=$(curl -sL --max-time 15 "${proxy}${API_URL}" 2>/dev/null | grep -oP '"tag_name":\s*"\Kv[^"]+' | head -1)
                [ -n "$EZA_VERSION" ] && break
            done
        fi
        if [ -n "$EZA_VERSION" ]; then
            URL="https://github.com/eza-community/eza/releases/download/${EZA_VERSION}/eza_x86_64-unknown-linux-gnu.tar.gz"
            if proxy_fetch "$URL" /tmp/eza.tar.gz; then
                tar xzf /tmp/eza.tar.gz -C ~/.local/bin/ && rm /tmp/eza.tar.gz
                [ -f ~/.local/bin/eza_x86_64-unknown-linux-gnu/eza ] && mv ~/.local/bin/eza_x86_64-unknown-linux-gnu/eza ~/.local/bin/eza
                log_info "eza 安装完成 ($EZA_VERSION)"
            else
                track_error "eza 安装失败（下载）"
            fi
        else
            track_error "eza 版本号获取失败"
        fi
    fi
}

# === 步骤 4: Node.js（nvm） ===
install_node() {
    log_step "步骤 4/8: Node.js（通过 nvm）"

    if [ "$SKIP_NODE" = true ]; then
        log_note "已跳过（--skip-node）"
        return
    fi

    # 安装 nvm
    if [ -d ~/.nvm ]; then
        log_info "nvm 已存在，更新..."
        cd ~/.nvm && git pull -q 2>/dev/null && cd ~
    else
        log_note "克隆 nvm（gitee 镜像）..."
        if git clone https://gitee.com/mirrors/nvm.git ~/.nvm 2>/dev/null; then
            log_info "nvm 克隆完成"
        else
            track_error "nvm 克隆失败"
            return
        fi
    fi

    # 切换到最新 tag
    cd ~/.nvm
    LATEST_TAG=$(git describe --abbrev=0 --tags --match "v[0-9]*" 2>/dev/null)
    [ -n "$LATEST_TAG" ] && git checkout "$LATEST_TAG" -q 2>/dev/null
    cd ~

    # 加载 nvm
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

    # 检查 nvm 加载
    if ! command -v nvm > /dev/null 2>&1; then
        track_error "nvm 加载失败"
        return
    fi
    log_info "nvm 就绪（版本 $LATEST_TAG）"

    # 安装 Node.js LTS
    if command -v node > /dev/null 2>&1; then
        log_info "Node.js 已存在: $(node --version)"
    else
        log_note "安装 Node.js LTS（npmmirror 加速）..."
        if NVM_NODEJS_ORG_MIRROR=https://npmmirror.com/mirrors/node nvm install --lts > /dev/null 2>&1; then
            log_info "Node.js 安装完成: $(node --version)"
        else
            track_error "Node.js 安装失败"
            return
        fi
    fi

    # npm 国内镜像
    if command -v npm > /dev/null 2>&1; then
        npm config set registry https://registry.npmmirror.com
        log_info "npm 镜像设置为淘宝"
    fi
}

# === 步骤 5: 配置 .bashrc ===
setup_bashrc() {
    log_step "步骤 5/8: 配置 ~/.bashrc"

    if [ "$SKIP_BASHRC" = true ]; then
        log_note "已跳过（--skip-bashrc）"
        return
    fi

    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    SNIPPET="$SCRIPT_DIR/bashrc.snippet.sh"

    if [ ! -f "$SNIPPET" ]; then
        track_error "找不到配置片段: $SNIPPET"
        return
    fi

    # 自动检测 Windows 用户名，替换 snippet 中的占位符
    WIN_USER=$(ls /mnt/c/Users 2>/dev/null | grep -v -iE '^(Public|Default|All Users|Default User|desktop.ini|WDAGUtilityAccount)$' | head -1)

    # 临时 snippet（替换 Windows 用户名）
    TMP_SNIPPET="/tmp/bashrc.snippet.$$.sh"
    if [ -n "$WIN_USER" ]; then
        sed "s|/mnt/c/Users/14393|/mnt/c/Users/$WIN_USER|g" "$SNIPPET" > "$TMP_SNIPPET"
        log_note "检测到 Windows 用户名: $WIN_USER"
    else
        cp "$SNIPPET" "$TMP_SNIPPET"
        log_warn "无法自动检测 Windows 用户名，winhome 别名可能需要手动修改"
    fi

    # 备份
    BAK_NAME=~/.bashrc.bak.$(date +%s)
    cp ~/.bashrc "$BAK_NAME"
    log_note "已备份 .bashrc 到 $BAK_NAME"

    # 移除旧配置块（如有）
    MARKER_BEGIN="# >>> guoda optimization begin >>>"
    MARKER_END="# <<< guoda optimization end <<<"
    if grep -q "$MARKER_BEGIN" ~/.bashrc; then
        sed -i "/$MARKER_BEGIN/,/$MARKER_END/d" ~/.bashrc
        log_note "已移除旧配置块"
    fi

    # 追加新配置
    cat "$TMP_SNIPPET" >> ~/.bashrc
    rm "$TMP_SNIPPET"
    log_info ".bashrc 配置完成"
}

# === 步骤 6: /etc/wsl.conf ===
setup_wslconf() {
    log_step "步骤 6/8: 配置 /etc/wsl.conf"

    if [ "$SKIP_WSL_CONF" = true ]; then
        log_note "已跳过（--skip-wsl-conf）"
        return
    fi

    if [ -f /etc/wsl.conf ] && grep -q "default=$(whoami)" /etc/wsl.conf 2>/dev/null; then
        log_info "/etc/wsl.conf 已配置当前用户"
        return
    fi

    sudo tee /etc/wsl.conf > /dev/null <<EOF
[boot]
systemd=true

[user]
default=$(whoami)
EOF
    log_info "/etc/wsl.conf 已配置（默认用户: $(whoami)）"
}

# === 步骤 7: systemd 用户服务 ===
fix_systemd() {
    log_step "步骤 7/8: 修复 systemd 用户服务"

    if sudo loginctl enable-linger "$CURRENT_USER" 2>/dev/null; then
        log_info "enable-linger 已设置"
    else
        log_warn "enable-linger 设置失败（可能已设置）"
    fi
}

# === 步骤 8: 最终验证 ===
verify() {
    log_step "步骤 8/8: 最终验证"

    export PATH="$HOME/.local/bin:$HOME/.fzf/bin:$PATH"
    [ -s "$HOME/.nvm/nvm.sh" ] && \. "$HOME/.nvm/nvm.sh"

    printf "\n  %-12s %-20s %s\n" "工具" "版本" "状态"
    printf "  %-12s %-20s %s\n" "----" "----" "----"

    for cmd in htop tree rg fd bat tldr zoxide starship eza; do
        if command -v "$cmd" > /dev/null 2>&1; then
            ver=$("$cmd" --version 2>&1 | head -1 | cut -c1-30)
            printf "  %-12s %-20s %s\n" "$cmd" "$ver" "✓"
        else
            printf "  %-12s %-20s %s\n" "$cmd" "-" "✗"
        fi
    done

    if [ -x ~/.fzf/bin/fzf ]; then
        printf "  %-12s %-20s %s\n" "fzf" "$(~/.fzf/bin/fzf --version 2>&1 | head -1 | cut -c1-30)" "✓"
    fi

    if command -v node > /dev/null 2>&1; then
        printf "  %-12s %-20s %s\n" "node" "$(node --version)" "✓"
        printf "  %-12s %-20s %s\n" "npm" "$(npm --version)" "✓"
    fi
}

# === 汇总 ===
summary() {
    log_step "执行汇总"

    echo ""
    if [ ${#ERRORS[@]} -eq 0 ]; then
        echo -e "${GREEN}========================================${NC}"
        echo -e "${GREEN}  🎉 全部步骤成功完成！${NC}"
        echo -e "${GREEN}========================================${NC}"
    else
        echo -e "${RED}========================================${NC}"
        echo -e "${RED}  ⚠️  有 ${#ERRORS[@]} 个错误：${NC}"
        echo -e "${RED}========================================${NC}"
        for err in "${ERRORS[@]}"; do
            echo -e "  ${RED}- $err${NC}"
        done
    fi

    cat <<'EOF'

📌 下一步操作：

  1. 配置 Windows 端 .wslconfig（参考 docs/04-optimization.md）
     把 scripts/wslconfig.template 复制到 C:\Users\<你>\.wslconfig

  2. 让所有配置生效（在 PowerShell 中）：
     wsl --shutdown
     然后重新打开 WSL 终端

  3. 在 WSL 中验证：
     source ~/.bashrc
     htop, ls, rg, z <目录>, Ctrl+R 都应该正常工作

  4. 阅读文档：
     - docs/cheatsheet.md  学习命令用法
     - docs/troubleshooting.md  排查问题
EOF
}

# === 主流程 ===
main() {
    parse_args "$@"
    check_env
    setup_apt_mirror
    install_apt_packages
    install_modern_tools
    install_node
    setup_bashrc
    setup_wsl_conf
    fix_systemd
    verify
    summary
}

main "$@"

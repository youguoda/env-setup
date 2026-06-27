#!/bin/bash
# ====================================================================
# setup-myenv.sh - 共享 GPU 服务器个人环境安装脚本
#
# 设计哲学:
#   - 工具链永久安装(apt + 二进制)
#   - 配置层完全隔离(放 ~/.guoda/,不碰 ~/.bashrc)
#   - 通过 `myenv` 命令进入子 shell 加载配置
#   - `exit` 即可还原,完全无侵入
#
# 跑这一脚的前提:
#   - 在目标服务器上,先把项目 git clone 到 ~/projects/personal/env-setup/
#   - 然后 bash scripts/setup-myenv.sh
#
# 跑完后:
#   - 工具链已装好(zoxide/eza/fzf/bat/rg/fd/yazi/starship/conda)
#   - ~/.guoda/ 已配置好
#   - /usr/local/bin/myenv 已可用
#   - 你只需 ssh 进服务器,敲 myenv 就进入自己的环境
#
# 幂等性:重复跑安全,已装的工具会跳过
# ====================================================================

set -uo pipefail

# === 共享库(颜色 / 日志 / track_error / test_github / proxy_fetch）===
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib.sh
source "$SCRIPT_DIR/lib.sh"

# === 状态 ===
ERRORS=()
SKIP_APT_MIRROR=false
SKIP_SYSTEM_UPDATE=false
SKIP_NODE=true       # 默认不装 Node(服务器场景一般不需要)
SKIP_CONDA=false
SKIP_YAZI=false
SKIP_DOCKER_MIRROR=false

CURRENT_USER=$(whoami)

# === 解析参数 ===
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --skip-apt-mirror)     SKIP_APT_MIRROR=true ;;
            --skip-system-update)  SKIP_SYSTEM_UPDATE=true ;;
            --install-node)        SKIP_NODE=false ;;
            --skip-conda)          SKIP_CONDA=true ;;
            --skip-yazi)           SKIP_YAZI=true ;;
            --skip-docker-mirror)  SKIP_DOCKER_MIRROR=true ;;
            -h|--help)
                cat <<EOF
setup-myenv.sh - 共享 GPU 服务器个人环境安装脚本

用法: bash setup-myenv.sh [选项]

选项:
  --skip-apt-mirror      跳过 apt 清华源切换
  --skip-system-update   跳过 apt update/upgrade
  --install-node         装 Node.js(默认不装,服务器一般不需要)
  --skip-conda           跳过 Miniconda
  --skip-yazi            跳过 Yazi 文件管理器
  --skip-docker-mirror   跳过 Docker 镜像源配置
  -h, --help             显示帮助

核心理念:
  这个脚本不会修改 ~/.bashrc / /etc/profile / /etc/bash.bashrc
  所有个人配置放在 ~/.guoda/ 下,完全隔离
  通过 'myenv' 命令进入子 shell 加载配置,'exit' 退出即可还原
EOF
                exit 0
                ;;
            *)
                log_warn "未知参数: $1(忽略)"
                ;;
        esac
        shift
    done
}

# === 步骤 0:环境检查 ===
check_env() {
    log_step "步骤 0/9: 环境检查"

    if [ "$(uname -s)" != "Linux" ]; then
        track_error "当前不是 Linux 环境"
        exit 1
    fi

    if command -v lsb_release > /dev/null 2>&1; then
        log_info "系统: $(lsb_release -ds)"
    else
        log_info "系统: $(grep PRETTY_NAME /etc/os-release | cut -d= -f2)"
    fi
    log_info "用户: $CURRENT_USER"
    log_info "家目录: $HOME"

    if [ "$CURRENT_USER" != "root" ]; then
        if ! sudo -n true 2>/dev/null; then
            log_warn "需要 sudo 权限,运行过程中可能提示输入密码"
        fi
    fi

    if command -v nvidia-smi > /dev/null 2>&1; then
        GPU_COUNT=$(nvidia-smi --list-gpus 2>/dev/null | wc -l)
        log_info "GPU: ${GPU_COUNT} 块"
    else
        log_warn "未检测到 nvidia-smi"
    fi

    if command -v docker > /dev/null 2>&1; then
        log_info "Docker: $(docker --version)"
    else
        log_warn "Docker 未安装"
    fi

    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    log_note "脚本目录: $SCRIPT_DIR"
}

# === 步骤 1:apt 清华源 ===
setup_apt_mirror() {
    log_step "步骤 1/9: apt 清华源"

    if [ "$SKIP_APT_MIRROR" = true ]; then
        log_note "已跳过(--skip-apt-mirror)"
        return
    fi

    if grep -q "mirrors.tuna.tsinghua.edu.cn" /etc/apt/sources.list 2>/dev/null; then
        log_info "apt 已是清华源"
        return
    fi

    if [ -f /etc/apt/sources.list.d/ubuntu.sources ]; then
        log_note "Ubuntu 24.04+ 新格式 sources,跳过(需手动改)"
        return
    fi

    sudo cp /etc/apt/sources.list "/etc/apt/sources.list.bak.$(date +%s)" 2>/dev/null
    sudo sed -i 's|http://archive.ubuntu.com|https://mirrors.tuna.tsinghua.edu.cn|g' /etc/apt/sources.list
    sudo sed -i 's|http://security.ubuntu.com|https://mirrors.tuna.tsinghua.edu.cn|g' /etc/apt/sources.list
    sudo sed -i 's|http://[a-z]*.archive.ubuntu.com|https://mirrors.tuna.tsinghua.edu.cn|g' /etc/apt/sources.list
    log_info "apt 源已切换到清华镜像"
}

# === 步骤 2:系统更新 + 基础工具 ===
install_apt_packages() {
    log_step "步骤 2/9: 系统更新 + 基础工具(含 Yazi 预览依赖)"

    if [ "$SKIP_SYSTEM_UPDATE" = false ]; then
        log_note "apt update..."
        sudo apt update || track_error "apt update 失败"

        log_note "apt upgrade..."
        sudo DEBIAN_FRONTEND=noninteractive apt upgrade -y || track_error "apt upgrade 失败"
    fi

    log_note "安装基础工具 + Yazi 预览依赖..."
    sudo DEBIAN_FRONTEND=noninteractive apt install -y \
        htop tree bash-completion \
        ripgrep fd-find bat \
        tldr ca-certificates \
        unzip zip p7zip-full unar \
        jq \
        curl wget git \
        build-essential \
        7zip \
        poppler-utils \
        ffmpegthumbnailer \
        imagemagick \
        2>&1 | tail -3 || track_error "基础工具安装失败"

    # 兼容 symlink(fd/fdfind, bat/batcat)
    [ ! -L /usr/local/bin/fd ] && sudo ln -sf "$(which fdfind)" /usr/local/bin/fd 2>/dev/null
    [ ! -L /usr/local/bin/bat ] && sudo ln -sf "$(which batcat)" /usr/local/bin/bat 2>/dev/null
    log_info "基础工具就绪(含 7zip/poppler/ffmpegthumbnailer 供 Yazi 预览)"
}

# === 步骤 3:现代 CLI 工具(zoxide/starship/fzf/eza)===
install_modern_tools() {
    log_step "步骤 3/9: 现代工具(zoxide/starship/fzf/eza)"

    mkdir -p ~/.local/bin

    # test_github / proxy_fetch 来自 lib.sh
    test_github && log_note "github 直连可用" || log_note "github 直连不通,将用代理"

    # --- zoxide ---
    if command -v zoxide > /dev/null 2>&1 || [ -f ~/.local/bin/zoxide ]; then
        log_info "zoxide 已存在"
    else
        log_note "安装 zoxide..."
        if proxy_fetch "https://github.com/ajeetdsouza/zoxide/releases/latest/download/zoxide-x86_64-unknown-linux-musl" ~/.local/bin/zoxide; then
            chmod +x ~/.local/bin/zoxide
            log_info "zoxide 安装完成"
        else
            track_error "zoxide 安装失败(网络)"
        fi
    fi

    # --- starship ---
    if command -v starship > /dev/null 2>&1 || [ -f ~/.local/bin/starship ]; then
        log_info "starship 已存在"
    else
        log_note "安装 starship..."
        if curl -sS --max-time 30 https://starship.rs/install.sh | sh -s -- -y -b ~/.local/bin -f > /dev/null 2>&1; then
            log_info "starship 安装完成"
        else
            URL="https://github.com/starship/starship/releases/latest/download/starship-x86_64-unknown-linux-musl.tar.gz"
            if proxy_fetch "$URL" /tmp/starship.tar.gz; then
                tar xzf /tmp/starship.tar.gz -C ~/.local/bin/ && rm /tmp/starship.tar.gz
                log_info "starship 安装完成(github)"
            else
                track_error "starship 安装失败"
            fi
        fi
    fi

    # --- fzf ---
    if [ -d ~/.fzf ] || command -v fzf > /dev/null 2>&1; then
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
    if command -v eza > /dev/null 2>&1 || [ -f ~/.local/bin/eza ]; then
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
                track_error "eza 安装失败(下载)"
            fi
        else
            track_error "eza 版本号获取失败"
        fi
    fi
}

# === 步骤 3.5:Yazi 文件管理器 ===
install_yazi() {
    log_step "步骤 3.5/9: Yazi 文件管理器"

    if [ "$SKIP_YAZI" = true ]; then
        log_note "已跳过(--skip-yazi)"
        return
    fi

    if command -v yazi > /dev/null 2>&1 || [ -f ~/.local/bin/yazi ]; then
        log_info "yazi 已存在"
        return
    fi

    log_note "下载 yazi(github release)..."
    # test_github / proxy_fetch 来自 lib.sh
    API_URL="https://api.github.com/repos/sxyazi/yazi/releases/latest"
    YAZI_VERSION=""
    test_github && YAZI_VERSION=$(curl -sL --max-time 15 "$API_URL" | grep -oP '"tag_name":\s*"\Ky[^"]+' | head -1)
    if [ -z "$YAZI_VERSION" ]; then
        for proxy in "https://ghproxy.com/" "https://gh-proxy.com/"; do
            YAZI_VERSION=$(curl -sL --max-time 15 "${proxy}${API_URL}" 2>/dev/null | grep -oP '"tag_name":\s*"\Ky[^"]+' | head -1)
            [ -n "$YAZI_VERSION" ] && break
        done
    fi

    if [ -z "$YAZI_VERSION" ]; then
        track_error "yazi 版本号获取失败"
        return
    fi

    URL="https://github.com/sxyazi/yazi/releases/latest/download/yazi-x86_64-unknown-linux-gnu.zip"
    if proxy_fetch "$URL" /tmp/yazi.zip; then
        unzip -o /tmp/yazi.zip -d /tmp/yazi-pkg > /dev/null 2>&1
        # 找 yazi 二进制(可能在子目录)
        YAZI_BIN=$(find /tmp/yazi-pkg -name "yazi" -type f | head -1)
        if [ -n "$YAZI_BIN" ]; then
            cp "$YAZI_BIN" ~/.local/bin/yazi
            chmod +x ~/.local/bin/yazi
            log_info "yazi 安装完成 ($YAZI_VERSION)"
        else
            track_error "yazi 二进制未找到"
        fi
        rm -rf /tmp/yazi.zip /tmp/yazi-pkg
    else
        track_error "yazi 下载失败"
    fi
}

# === 步骤 4:Miniconda ===
install_conda() {
    log_step "步骤 4/9: Miniconda"

    if [ "$SKIP_CONDA" = true ]; then
        log_note "已跳过(--skip-conda)"
        return
    fi

    if [ -f "$HOME/miniconda3/bin/conda" ]; then
        log_info "conda 已存在: $($HOME/miniconda3/bin/conda --version)"
        return
    fi

    log_note "下载 Miniconda(清华镜像)..."
    INSTALLER="/tmp/miniconda.sh"
    URL="https://mirrors.tuna.tsinghua.edu.cn/anaconda/miniconda/Miniconda3-latest-Linux-x86_64.sh"
    if curl -fL --max-time 120 "$URL" -o "$INSTALLER" 2>/dev/null; then
        log_note "安装中..."
        bash "$INSTALLER" -b -p "$HOME/miniconda3" > /dev/null 2>&1 && rm "$INSTALLER"
        log_info "Miniconda 安装完成"

        # 配置清华 conda 源(只对 root 写,不污染系统)
        mkdir -p "$HOME/.conda"
        cat > "$HOME/.condarc" <<'EOF'
channels:
  - defaults
show_channel_urls: true
default_channels:
  - https://mirrors.tuna.tsinghua.edu.cn/anaconda/pkgs/main
  - https://mirrors.tuna.tsinghua.edu.cn/anaconda/pkgs/free
  - https://mirrors.tuna.tsinghua.edu.cn/anaconda/pkgs/r
custom_channels:
  conda-forge: https://mirrors.tuna.tsinghua.edu.cn/anaconda/cloud
EOF
        log_info "conda 清华源已配置"
    else
        track_error "Miniconda 下载失败"
    fi
}

# === 步骤 5:Node.js(可选)===
install_node() {
    log_step "步骤 5/9: Node.js(可选)"

    if [ "$SKIP_NODE" = true ]; then
        log_note "已跳过(默认不装;加 --install-node 启用)"
        return
    fi

    if [ -d ~/.nvm ]; then
        log_info "nvm 已存在,更新..."
        ( cd ~/.nvm && git pull -q 2>/dev/null )
    else
        log_note "克隆 nvm(gitee 镜像)..."
        if git clone https://gitee.com/mirrors/nvm.git ~/.nvm 2>/dev/null; then
            log_info "nvm 克隆完成"
        else
            track_error "nvm 克隆失败"
            return
        fi
    fi

    cd ~/.nvm || return
    LATEST_TAG=$(git describe --abbrev=0 --tags --match "v[0-9]*" 2>/dev/null)
    [ -n "$LATEST_TAG" ] && git checkout "$LATEST_TAG" -q 2>/dev/null
    cd ~ || return

    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

    if ! command -v nvm > /dev/null 2>&1; then
        track_error "nvm 加载失败"
        return
    fi
    log_info "nvm 就绪($LATEST_TAG)"

    if command -v node > /dev/null 2>&1; then
        log_info "Node.js 已存在: $(node --version)"
    else
        log_note "安装 Node.js LTS(npmmirror 加速)..."
        if NVM_NODEJS_ORG_MIRROR=https://npmmirror.com/mirrors/node nvm install --lts > /dev/null 2>&1; then
            log_info "Node.js 安装完成: $(node --version)"
        else
            track_error "Node.js 安装失败"
            return
        fi
    fi

    if command -v npm > /dev/null 2>&1; then
        npm config set registry https://registry.npmmirror.com
        log_info "npm 镜像设置为淘宝"
    fi
}

# === 步骤 6:GPU 监控 + LLM 工具 ===
install_gpu_tools() {
    log_step "步骤 6/9: GPU 监控工具"

    local pip_bin=""
    if [ -f "$HOME/miniconda3/bin/pip" ]; then
        pip_bin="$HOME/miniconda3/bin/pip"
    elif command -v pip3 > /dev/null 2>&1; then
        pip_bin="pip3"
    elif command -v pip > /dev/null 2>&1; then
        pip_bin="pip"
    else
        log_warn "未找到 pip,跳过 GPU 监控工具(需先装 conda 或 python3-pip)"
        return
    fi

    log_note "使用 pip: $pip_bin"
    $pip_bin install --user nvitop gpustat hf_transfer huggingface_hub 2>&1 | tail -3
    log_info "GPU 监控 + HuggingFace 工具就绪"
}

# === 步骤 7:Docker 镜像源 ===
setup_docker_mirror() {
    log_step "步骤 7/9: Docker 镜像源"

    if [ "$SKIP_DOCKER_MIRROR" = true ]; then
        log_note "已跳过(--skip-docker-mirror)"
        return
    fi

    if ! command -v docker > /dev/null 2>&1; then
        log_warn "Docker 未安装,跳过"
        return
    fi

    if grep -q "mirrors.ustc.edu.cn" /etc/docker/daemon.json 2>/dev/null; then
        log_info "Docker 镜像源已配置"
        return
    fi

    sudo mkdir -p /etc/docker
    sudo tee /etc/docker/daemon.json > /dev/null <<'EOF'
{
    "registry-mirrors": [
        "https://docker.mirrors.ustc.edu.cn",
        "https://hub-mirror.c.163.com"
    ],
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "100m",
        "max-file": "3"
    }
}
EOF
    log_info "Docker 镜像源已配置"

    if sudo systemctl restart docker 2>/dev/null; then
        log_info "Docker 已重启"
    else
        log_warn "Docker 重启失败(配置会在下次重启时生效)"
    fi
}

# === 步骤 8:部署 ~/.guoda/ 配置 + 安装 myenv 命令 ===
setup_guoda_config() {
    log_step "步骤 8/9: 部署 ~/.guoda/ 配置 + myenv 命令"

    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    # 创建 ~/.guoda/ 目录
    mkdir -p ~/.guoda/yazi

    # 复制配置文件
    for f in guoda-bashrc.sh guoda-env.sh guoda-starship.toml; do
        if [ -f "$SCRIPT_DIR/$f" ]; then
            # guoda-bashrc.sh → ~/.guoda/bashrc.sh
            # guoda-env.sh    → ~/.guoda/env.sh
            # guoda-starship.toml → ~/.guoda/starship.toml
            case "$f" in
                guoda-bashrc.sh)      DEST="$HOME/.guoda/bashrc.sh" ;;
                guoda-env.sh)         DEST="$HOME/.guoda/env.sh" ;;
                guoda-starship.toml)  DEST="$HOME/.guoda/starship.toml" ;;
            esac
            cp "$SCRIPT_DIR/$f" "$DEST"
            log_info "部署 $DEST"
        else
            track_error "找不到 $SCRIPT_DIR/$f"
        fi
    done

    # 公共别名(单一真相源)→ ~/.guoda/aliases.sh
    if [ -f "$SCRIPT_DIR/aliases.common.sh" ]; then
        cp "$SCRIPT_DIR/aliases.common.sh" "$HOME/.guoda/aliases.sh"
        log_info "部署 $HOME/.guoda/aliases.sh"
    else
        track_error "找不到 $SCRIPT_DIR/aliases.common.sh"
    fi

    # 安装 myenv 命令到 /usr/local/bin
    if [ -f "$SCRIPT_DIR/myenv" ]; then
        sudo cp "$SCRIPT_DIR/myenv" /usr/local/bin/myenv
        sudo chmod +x /usr/local/bin/myenv
        log_info "/usr/local/bin/myenv 已安装"
    fi

    if [ -f "$SCRIPT_DIR/myenv-clean" ]; then
        sudo cp "$SCRIPT_DIR/myenv-clean" /usr/local/bin/myenv-clean
        sudo chmod +x /usr/local/bin/myenv-clean
        log_info "/usr/local/bin/myenv-clean 已安装"
    fi

    # 创建工作目录骨架
    mkdir -p ~/projects/inference/models
    mkdir -p ~/projects/eval/tasks
    mkdir -p ~/data/datasets
    mkdir -p ~/data/results
    mkdir -p ~/models
    mkdir -p ~/logs
    log_info "工作目录骨架已创建(projects/data/models/logs)"

    # 复制 vllm / eval 模板
    if [ -f "$SCRIPT_DIR/vllm-run.template.sh" ]; then
        cp "$SCRIPT_DIR/vllm-run.template.sh" ~/projects/inference/run-vllm.sh
        chmod +x ~/projects/inference/run-vllm.sh
        log_info "vLLM 模板已复制到 ~/projects/inference/run-vllm.sh"
    fi
    if [ -f "$SCRIPT_DIR/eval-run.template.sh" ]; then
        cp "$SCRIPT_DIR/eval-run.template.sh" ~/projects/eval/run-eval.sh
        chmod +x ~/projects/eval/run-eval.sh
        log_info "评测模板已复制到 ~/projects/eval/run-eval.sh"
    fi
}

# === 步骤 9:验证 + 使用说明 ===
verify_and_summary() {
    log_step "步骤 9/9: 验证"

    export PATH="$HOME/.local/bin:$HOME/.fzf/bin:$HOME/miniconda3/bin:$PATH"

    printf "\n  %-14s %-25s %s\n" "工具" "版本" "状态"
    printf "  %-14s %-25s %s\n" "----" "----" "----"

    for cmd in htop tree rg fd bat tldr zoxide starship eza yazi; do
        if command -v "$cmd" > /dev/null 2>&1 || [ -f "$HOME/.local/bin/$cmd" ]; then
            local full_cmd="$cmd"
            [ -f "$HOME/.local/bin/$cmd" ] && full_cmd="$HOME/.local/bin/$cmd"
            ver=$("$full_cmd" --version 2>&1 | head -1 | cut -c1-30)
            printf "  %-14s %-25s %s\n" "$cmd" "$ver" "✓"
        else
            printf "  %-14s %-25s %s\n" "$cmd" "-" "✗"
        fi
    done

    # GPU 工具
    for cmd in nvitop gpustat; do
        if command -v "$cmd" > /dev/null 2>&1; then
            ver=$("$cmd" --version 2>&1 | head -1 | cut -c1-30)
            printf "  %-14s %-25s %s\n" "$cmd" "$ver" "✓"
        fi
    done

    if [ -f "$HOME/miniconda3/bin/conda" ]; then
        printf "  %-14s %-25s %s\n" "conda" "$($HOME/miniconda3/bin/conda --version | head -1)" "✓"
    fi

    if [ -x ~/.fzf/bin/fzf ]; then
        printf "  %-14s %-25s %s\n" "fzf" "$(~/.fzf/bin/fzf --version 2>&1 | head -1 | cut -c1-30)" "✓"
    fi

    if command -v docker > /dev/null 2>&1; then
        printf "  %-14s %-25s %s\n" "docker" "$(docker --version | cut -d' ' -f1-3)" "✓"
    fi

    if [ -f /usr/local/bin/myenv ]; then
        printf "  %-14s %-25s %s\n" "myenv" "/usr/local/bin/myenv" "✓"
    fi

    # === 汇总 ===
    echo ""
    if [ ${#ERRORS[@]} -eq 0 ]; then
        echo -e "${GREEN}========================================${NC}"
        echo -e "${GREEN}  🎉 全部步骤成功完成!${NC}"
        echo -e "${GREEN}========================================${NC}"
    else
        echo -e "${RED}========================================${NC}"
        echo -e "${RED}  ⚠️  有 ${#ERRORS[@]} 个错误:${NC}"
        echo -e "${RED}========================================${NC}"
        for err in "${ERRORS[@]}"; do
            echo -e "  ${RED}- $err${NC}"
        done
    fi

    cat <<EOF

🚀 现在你可以这样工作:

  1. ssh root@server
  2. 敲 myenv(进入你的个人环境)
  3. 在子 shell 里:
     - ls / ll / la    带图标的 eza
     - z <关键词>      zoxide 智能跳转
     - y               yazi 文件管理器
     - gpu / nvi       GPU 监控
     - proj-infer      进入推理项目
     - mydocker        看自己跑的容器
  4. 干完活:
     - exit            退出子 shell(配置自动还原)
     - myenv-clean     一键清理你跑的容器

📌 关键文件:

  ~/.guoda/bashrc.sh        子 shell 加载的配置
  ~/.guoda/env.sh           环境变量(HF_HOME 等)
  ~/.guoda/starship.toml    提示符配置
  ~/projects/inference/     vLLM 启动模板
  ~/projects/eval/          评测模板
  ~/models/                 HF 模型缓存(HF_HOME 指向这里)

🔍 验证不污染别人:

  打开一个新的 ssh 会话,不敲 myenv 直接敲 ls / grep / find ——
  应该全是系统默认行为,因为本脚本没有修改 ~/.bashrc。
EOF
}

# === 主流程 ===
main() {
    parse_args "$@"
    check_env
    setup_apt_mirror
    install_apt_packages
    install_modern_tools
    install_yazi
    install_conda
    install_node
    install_gpu_tools
    setup_docker_mirror
    setup_guoda_config
    verify_and_summary
}

main "$@"

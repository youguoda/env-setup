# shellcheck shell=bash
# guoda-bashrc.sh - myenv 子 shell 加载的配置
# 路径: ~/.guoda/bashrc.sh
#
# 设计原则:
#   1. 先 source 系统默认 + ~/.bashrc,保持基础环境一致
#   2. 再 source 公共别名 + 追加服务器专属
#   3. 完全独立,不影响系统 ~/.bashrc

# === 0. ble.sh 提前加载(必须最先,用 --noattach 延迟 attach)===
# ble.sh 给 bash 加 fish 风格的:
#   - 灰色自动建议(按 → 或 Ctrl+F 接受)
#   - 菜单式 Tab 补全(方向键选择)
#   - 语法高亮(命令存在显示绿色,错误红色)
#   - 历史中已有命令的智能补全
[[ $- == *i* ]] && [ -f ~/.local/share/blesh/ble.sh ] && source ~/.local/share/blesh/ble.sh --noattach

# === 1. 基础:加载系统默认配置 + 用户的 ~/.bashrc ===
[ -f /etc/bash.bashrc ] && source /etc/bash.bashrc
[ -f ~/.bashrc ] && source ~/.bashrc

# === 2. 加载环境变量 ===
[ -f ~/.guoda/env.sh ] && source ~/.guoda/env.sh

# === 3. 现代工具初始化(只在工具存在时初始化,避免报错)===
command -v zoxide > /dev/null 2>&1 && eval "$(zoxide init bash)"
if command -v starship > /dev/null 2>&1; then
    export STARSHIP_CONFIG="$HOME/.guoda/starship.toml"
    eval "$(starship init bash)"
fi
[ -f ~/.fzf.bash ] && source ~/.fzf.bash

# === 4. 公共别名/函数(单一真相源: scripts/aliases.common.sh)===
[ -f ~/.guoda/aliases.sh ] && source ~/.guoda/aliases.sh

# === 5. 服务器专属别名 ===

# Docker(dc 在公共别名里)
alias dps='docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"'
alias dpsi='docker ps -a --format "table {{.Names}}\t{{.Image}}\t{{.Status}}"'
alias dl='docker logs -f'
alias dx='docker exec -it'
alias drm='docker rm -f'

# GPU 监控
command -v gpustat > /dev/null 2>&1 && alias gpu='gpustat'
command -v nvitop > /dev/null 2>&1 && alias nvi='nvitop'
alias smi='nvidia-smi'
alias watch-gpu='watch -n 2 gpustat'
alias gpu-procs='nvidia-smi --query-compute-apps=pid,process_name,used_memory --format=csv'

# HuggingFace
alias hf='huggingface-cli'
alias hf-dl='huggingface-cli download'
alias hf-ls='huggingface-cli scan-cache'
alias hf-du='du -sh $HF_HUB_CACHE/* 2>/dev/null | sort -h'

# conda
alias conda-ls='conda env list'

# 快速进入工作目录
alias proj='cd ~/projects 2>/dev/null || echo "用 z <关键词> 智能跳转"'
alias proj-infer='cd ~/projects/inference 2>/dev/null || echo "目录不存在"'
alias proj-eval='cd ~/projects/eval 2>/dev/null || echo "目录不存在"'
alias models='cd $HF_HOME'
alias results='cd ~/data/results'
alias mylog='cd ~/logs'

# === 6. 服务器专属函数 ===

# Yazi 包装函数(退出时 cd 到 yazi 退出的目录)
function y() {
    local tmp cwd
    tmp="$(mktemp -t "yazi-cwd.XXXXXX")"
    yazi "$@" --cwd-file="$tmp"
    if cwd="$(command cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
        builtin cd -- "$cwd" || return
    fi
    rm -f -- "$tmp"
}

# Docker 容器进入(简化 docker exec -it)
dsh() {
    local container="${1:?用法: dsh <container>}"
    docker exec -it "$container" bash 2>/dev/null || docker exec -it "$container" sh
}

# 看自己跑的容器(按名字前缀过滤)
mydocker() {
    local prefix="${1:-guoda}"
    docker ps -a --filter "name=${prefix}-" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
}

# === Docker 容器内使用 myenv(关键!)===
# 前提:容器启动时挂载了 host 的 ~/.guoda / ~/.local / ~/.fzf
# (drun-corex / drun-tencent 已自动加这些挂载)

# 进容器时自动加载 myenv 配置(替代 docker exec -it xxx bash)
# 用法:
#   dexec <container>             # 进交互式 shell(带 myenv 配置)
#   dexec <container> <cmd...>    # 在容器内跑一条命令(带 myenv 配置)
dexec() {
    local container="${1:?用法: dexec <container> [cmd...]}"
    shift
    if [ ! -d "$HOME/.guoda" ]; then
        echo "✗ host 上没有 $HOME/.guoda/,先在 host 跑 setup-myenv.sh" >&2
        return 1
    fi
    if [ $# -gt 0 ]; then
        # 容器内跑一条命令后退出
        docker exec -it "$container" bash --rcfile /root/.guoda/bashrc.sh -i -c "$*"
    else
        # 进交互式
        docker exec -it "$container" bash --rcfile /root/.guoda/bashrc.sh -i
    fi
}

# 启动特权测试容器(corex_test 模板,Ubuntu 22.04)
# 自动挂载 host 的 myenv 工具链,容器内可用 dexec 进入即可享受 myenv
# 用法: drun-corex <name> [image] [workdir]
drun-corex() {
    local name="${1:?用法: drun-corex <name> [image] [workdir]}"
    local image="${2:-10.150.9.98:80/sw_test/corex_base:ubuntu22.04-py3.10}"
    local workdir="${3:-/data/ws}"

    if docker ps -a --format '{{.Names}}' | grep -qx "$name"; then
        echo "⚠ 容器 $name 已存在,直接 dexec 进入"
        echo "  如要重建: docker rm -f $name && drun-corex ..."
        return 1
    fi

    docker run --name="$name" \
        --ipc host --pid host \
        --volume /usr/src:/usr/src \
        --volume /lib/modules:/lib/modules \
        --volume /dev:/dev \
        --volume /data:/data \
        --volume /mnt/app_auto:/mnt/app_auto \
        --volume "$HOME/.guoda:/root/.guoda" \
        --volume "$HOME/.local:/root/.local" \
        --volume "$HOME/.fzf:/root/.fzf" \
        --cap-add=ALL \
        --network=host \
        --privileged \
        --workdir="$workdir" \
        --runtime=runc \
        --detach=true \
        -t \
        "$image" \
        /bin/bash

    echo ""
    echo "✓ 容器 $name 已启动"
    echo "  镜像:    $image"
    echo "  工作目录: $workdir"
    echo "  进入:    dexec $name"
    echo "  停止:    docker rm -f $name"
}

# 启动特权测试容器(tencentLLM 模板,带 /stores 挂载)
# 用法: drun-tencent <name> [image] [workdir]
drun-tencent() {
    local name="${1:?用法: drun-tencent <name> [image] [workdir]}"
    local image="${2:-corex:4.5.0_sp_0402}"
    local workdir="${3:-/data/ws/guoda/cuda_daily_test}"

    if docker ps -a --format '{{.Names}}' | grep -qx "$name"; then
        echo "⚠ 容器 $name 已存在,直接 dexec 进入"
        echo "  如要重建: docker rm -f $name && drun-tencent ..."
        return 1
    fi

    docker run --name="$name" \
        --ipc host --pid host \
        --volume /usr/src:/usr/src \
        --volume /lib/modules:/lib/modules \
        --volume /dev:/dev \
        --volume /data:/data \
        --volume /mnt/app_auto:/mnt/app_auto \
        --volume /stores:/stores \
        --volume "$HOME/.guoda:/root/.guoda" \
        --volume "$HOME/.local:/root/.local" \
        --volume "$HOME/.fzf:/root/.fzf" \
        --cap-add=ALL \
        --network=host \
        --privileged \
        --workdir="$workdir" \
        --runtime=runc \
        --detach=true \
        -t \
        "$image" \
        /bin/bash

    echo ""
    echo "✓ 容器 $name 已启动"
    echo "  镜像:    $image"
    echo "  工作目录: $workdir"
    echo "  进入:    dexec $name"
    echo "  停止:    docker rm -f $name"
}

# 通用 drun:自定义挂载 + 自动套 myenv 工具
# 用法: drun <name> <image> [workdir] [extra-docker-args...]
drun() {
    local name="${1:?用法: drun <name> <image> [workdir] [extra-args...]}"
    local image="${2:?需要指定 image}"
    local workdir="${3:-/data/ws}"
    shift 3 2>/dev/null || shift $# 2>/dev/null

    docker run --name="$name" \
        --ipc host --pid host \
        --volume /data:/data \
        --volume "$HOME/.guoda:/root/.guoda" \
        --volume "$HOME/.local:/root/.local" \
        --volume "$HOME/.fzf:/root/.fzf" \
        --cap-add=ALL \
        --network=host \
        --privileged \
        --workdir="$workdir" \
        --runtime=runc \
        --detach=true \
        -t \
        "$@" \
        "$image" \
        /bin/bash

    echo "✓ 容器 $name 已启动 → dexec $name 进入"
}

# === 7. 启动提示(告诉用户当前在 myenv)===
echo -e "\033[0;36m[myenv]\033[0m 已加载 guoda 环境(zoxide/eza/fzf/bat/yazi/conda/docker 别名)"
echo -e "  退出: \033[1;33mexit\033[0m | 清理: \033[1;33mmyenv-clean\033[0m | 文件管理器: \033[1;33my\033[0m | 进容器: \033[1;33mdexec <name>\033[0m"

# === 8. ble.sh attach(必须最后,启动自动建议/补全)===
# 前面所有配置加载完后,再激活 ble.sh 的 fish 风格体验
[[ ${BLE_VERSION-} ]] && ble-attach

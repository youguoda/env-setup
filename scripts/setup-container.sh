#!/bin/bash
# ====================================================================
# setup-container.sh - 容器内效率工具安装(第三条产品线)
#
# 场景:已经在容器里,要自包含地装 CLI,不从宿主机挂 ~/.local。
# 哲学:
#   - 只装效率工具,不装 conda / Node / GPU / HF / vLLM
#   - 不改 ~/.bashrc、/etc/profile、不 apt upgrade、不换 apt 源
#   - 配置走 ~/.guoda/ + myenv 子 shell,exit 即还原
#   - root 直接 apt;二进制默认 ~/.local,可用 --prefix 持久化
#
# 用法:
#   bash scripts/setup-container.sh
#   bash scripts/setup-container.sh --prefix /data/ws/.local
#
# 幂等:重复跑安全,已装的工具会跳过
# ====================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib.sh
source "$SCRIPT_DIR/lib.sh"

ERRORS=()
PREFIX="${GUODA_PREFIX:-$HOME/.local}"
SKIP_YAZI=false
SKIP_BLESH=false
SKIP_UV=false
SKIP_APT=false

CURRENT_USER=$(whoami)

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --prefix)
                PREFIX="${2:?--prefix 需要目录}"
                shift
                ;;
            --skip-yazi)  SKIP_YAZI=true ;;
            --skip-blesh) SKIP_BLESH=true ;;
            --skip-uv)    SKIP_UV=true ;;
            --skip-apt)   SKIP_APT=true ;;
            -h|--help)
                cat <<EOF
setup-container.sh - 容器内效率工具安装

用法: bash setup-container.sh [选项]

选项:
  --prefix DIR     二进制安装前缀(默认 \$HOME/.local)
                   容器 HOME 会随实例消失时,建议: --prefix /data/ws/.local
  --skip-apt       跳过 apt 包(镜像里已有 htop/rg 等时)
  --skip-yazi      跳过 Yazi
  --skip-blesh     跳过 ble.sh
  --skip-uv        跳过 uv
  -h, --help       显示帮助

装什么:
  apt:  htop tree ripgrep fd-find bat jq unzip git curl tldr
        (+ ca-certificates wget bash-completion,下载/补全依赖)
  bin:  zoxide starship fzf eza yazi ble.sh uv
  链接: fd → fdfind, bat → batcat
  配置: ~/.guoda/ + myenv 子 shell(不改默认 bashrc)

不装: conda / Node / nvitop / HuggingFace / vLLM / myenv-clean
不做: apt upgrade / 换 apt 源 / 改 ~/.bashrc
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

# root 直接跑,否则 sudo;两者都没有则记错误
root_cmd() {
    if [ "$(id -u)" -eq 0 ]; then
        "$@"
    elif command -v sudo > /dev/null 2>&1; then
        sudo "$@"
    else
        track_error "需要 root 或 sudo 才能执行: $*"
        return 1
    fi
}

have_bin() {
    local name=$1
    command -v "$name" > /dev/null 2>&1 || [ -x "$PREFIX/bin/$name" ]
}

check_env() {
    log_step "步骤 0/6: 环境检查"

    if [ "$(uname -s)" != "Linux" ]; then
        track_error "当前不是 Linux,拒绝执行"
        exit 1
    fi

    if [ -f /proc/1/cgroup ] && grep -qaE 'docker|containerd|kubepods|lxc' /proc/1/cgroup 2>/dev/null; then
        log_info "检测到容器 cgroup"
    elif [ -f /.dockerenv ]; then
        log_info "检测到 /.dockerenv"
    else
        log_warn "未明确检测到容器;脚本仍可跑,但本产品线是为容器内安装设计的"
    fi

    log_info "用户: $CURRENT_USER"
    log_info "家目录: $HOME"
    log_info "安装前缀: $PREFIX"
    log_note "不改 ~/.bashrc,不 apt upgrade,不换 apt 源"

    mkdir -p "$PREFIX/bin" "$PREFIX/share" "$PREFIX/opt"
    export PATH="$PREFIX/bin:$PATH"
}

install_apt_packages() {
    log_step "步骤 1/6: apt 效率工具"

    if [ "$SKIP_APT" = true ]; then
        log_note "已跳过(--skip-apt)"
        return
    fi

    if ! command -v apt-get > /dev/null 2>&1; then
        track_error "没有 apt-get,跳过系统包(请用 --skip-apt 并自行保证依赖)"
        return
    fi

    log_note "apt-get update(不做 upgrade)..."
    root_cmd env DEBIAN_FRONTEND=noninteractive apt-get update -y \
        || track_error "apt-get update 失败"

    log_note "安装 htop tree ripgrep fd-find bat jq unzip git curl tldr..."
    root_cmd env DEBIAN_FRONTEND=noninteractive apt-get install -y \
        htop tree bash-completion \
        ripgrep fd-find bat \
        tldr jq \
        unzip git curl wget ca-certificates \
        || track_error "apt 包安装失败"

    # fd → fdfind, bat → batcat(优先系统路径,可写则放到 /usr/local/bin)
    local fdfind batcat dest_dir
    fdfind=$(command -v fdfind 2>/dev/null || true)
    batcat=$(command -v batcat 2>/dev/null || true)
    dest_dir="/usr/local/bin"
    if [ ! -w "$dest_dir" ] && [ "$(id -u)" -ne 0 ]; then
        dest_dir="$PREFIX/bin"
    fi
    if [ -n "$fdfind" ]; then
        if [ ! -e "$dest_dir/fd" ]; then
            root_cmd ln -sf "$fdfind" "$dest_dir/fd" 2>/dev/null \
                || ln -sf "$fdfind" "$PREFIX/bin/fd"
        fi
        log_info "fd → $fdfind"
    fi
    if [ -n "$batcat" ]; then
        if [ ! -e "$dest_dir/bat" ]; then
            root_cmd ln -sf "$batcat" "$dest_dir/bat" 2>/dev/null \
                || ln -sf "$batcat" "$PREFIX/bin/bat"
        fi
        log_info "bat → $batcat"
    fi
}

# 下载压缩包并从中取出二进制到 $PREFIX/bin
# 用法: fetch_extract_bin <url> <bin1> [bin2...]   # 至少取到 bin1 才算成功
fetch_extract_bin() {
    local url=$1
    shift
    local primary=$1 tmp unpack b src got=1
    tmp=$(mktemp) || return 1
    unpack=$(mktemp -d) || { rm -f "$tmp"; return 1; }

    if ! proxy_fetch "$url" "$tmp"; then
        rm -rf "$tmp" "$unpack"
        return 1
    fi

    case "$url" in
        *.zip)          unzip -o "$tmp" -d "$unpack" > /dev/null 2>&1 ;;
        *.tar.gz|*.tgz) tar xzf "$tmp" -C "$unpack" 2>/dev/null ;;
        *.tar.xz)       tar xJf "$tmp" -C "$unpack" 2>/dev/null ;;
        *)              tar xf  "$tmp" -C "$unpack" 2>/dev/null ;;
    esac

    for b in "$@"; do
        src=$(find "$unpack" -name "$b" -type f -perm -u+x 2>/dev/null | head -1)
        [ -z "$src" ] && src=$(find "$unpack" -name "$b" -type f 2>/dev/null | head -1)
        if [ -n "$src" ]; then
            cp "$src" "$PREFIX/bin/$b" && chmod +x "$PREFIX/bin/$b"
        elif [ "$b" = "$primary" ]; then
            got=0
        fi
    done

    rm -rf "$tmp" "$unpack"
    [ "$got" -eq 1 ]
}

install_modern_tools() {
    log_step "步骤 2/6: 现代工具(zoxide/starship/fzf/eza)"

    test_github && log_note "github 直连可用" || log_note "github 直连不通,将用代理"

    # zoxide: release 只提供带版本号的 tar.gz(不再有裸二进制)
    if have_bin zoxide; then
        log_info "zoxide 已存在"
    else
        log_note "安装 zoxide..."
        local ztag zver
        ztag=$(gh_latest_tag ajeetdsouza/zoxide)
        if [ -z "$ztag" ]; then
            track_error "zoxide 版本号获取失败"
        else
            zver=${ztag#v}
            if fetch_extract_bin \
                "https://github.com/ajeetdsouza/zoxide/releases/download/${ztag}/zoxide-${zver}-x86_64-unknown-linux-musl.tar.gz" \
                zoxide; then
                log_info "zoxide 安装完成 ($ztag)"
            else
                track_error "zoxide 下载失败"
            fi
        fi
    fi

    # starship: latest/download 的 musl tarball,包内就是 starship
    if have_bin starship; then
        log_info "starship 已存在"
    else
        log_note "安装 starship..."
        if fetch_extract_bin \
            "https://github.com/starship/starship/releases/latest/download/starship-x86_64-unknown-linux-musl.tar.gz" \
            starship; then
            log_info "starship 安装完成"
        else
            track_error "starship 安装失败"
        fi
    fi

    # fzf: gitee 镜像 clone 到 PREFIX/opt/fzf
    if [ -x "$PREFIX/opt/fzf/bin/fzf" ] || command -v fzf > /dev/null 2>&1; then
        log_info "fzf 已存在"
    else
        log_note "安装 fzf..."
        if git clone --depth 1 https://gitee.com/mirrors/fzf.git "$PREFIX/opt/fzf" 2>/dev/null; then
            # pipefail 下 yes 被 SIGPIPE 会让整条管道非 0,用产物判断成败
            yes | "$PREFIX/opt/fzf/install" --bin > /dev/null 2>&1 || true
            if [ -x "$PREFIX/opt/fzf/bin/fzf" ]; then
                log_info "fzf 安装完成"
            else
                track_error "fzf install --bin 失败"
            fi
        else
            track_error "fzf clone 失败"
        fi
    fi

    # eza: 优先 musl
    if have_bin eza; then
        log_info "eza 已存在"
    else
        log_note "安装 eza..."
        local etag
        etag=$(gh_latest_tag eza-community/eza)
        if [ -z "$etag" ]; then
            track_error "eza 版本号获取失败"
        elif fetch_extract_bin \
            "https://github.com/eza-community/eza/releases/download/${etag}/eza_x86_64-unknown-linux-musl.tar.gz" \
            eza; then
            log_info "eza 安装完成 ($etag)"
        else
            track_error "eza 下载失败"
        fi
    fi
}

install_yazi() {
    log_step "步骤 3/6: Yazi / ble.sh / uv"

    if [ "$SKIP_YAZI" = true ]; then
        log_note "yazi 已跳过(--skip-yazi)"
    elif have_bin yazi; then
        log_info "yazi 已存在"
    else
        log_note "安装 yazi(musl)..."
        if fetch_extract_bin \
            "https://github.com/sxyazi/yazi/releases/latest/download/yazi-x86_64-unknown-linux-musl.zip" \
            yazi ya; then
            log_info "yazi 安装完成"
        else
            track_error "yazi 下载失败"
        fi
    fi

    if [ "$SKIP_BLESH" = true ]; then
        log_note "ble.sh 已跳过(--skip-blesh)"
    elif [ -f "$PREFIX/share/blesh/ble.sh" ]; then
        log_info "ble.sh 已存在"
    else
        log_note "安装 ble.sh(nightly tarball,容器内不强制编译)..."
        local tmp
        tmp=$(mktemp)
        if proxy_fetch "https://github.com/akinomyoga/ble.sh/releases/download/nightly/ble-nightly.tar.xz" "$tmp"; then
            mkdir -p "$PREFIX/share/blesh"
            tar xf "$tmp" -C "$PREFIX/share/blesh/" --strip-components=1
            rm -f "$tmp"
            log_info "ble.sh 安装完成"
        else
            rm -f "$tmp"
            track_error "ble.sh 下载失败"
        fi
    fi

    if [ "$SKIP_UV" = true ]; then
        log_note "uv 已跳过(--skip-uv)"
    elif have_bin uv; then
        log_info "uv 已存在"
    else
        log_note "安装 uv(musl)..."
        if fetch_extract_bin \
            "https://github.com/astral-sh/uv/releases/latest/download/uv-x86_64-unknown-linux-musl.tar.gz" \
            uv uvx; then
            log_info "uv 安装完成"
        else
            track_error "uv 下载失败"
        fi
    fi

    # rich-cli: yazi 预览依赖,命令名是 rich
    if have_bin rich; then
        log_info "rich-cli 已存在"
    elif ! have_bin uv && [ ! -x "$PREFIX/bin/uv" ]; then
        log_warn "没有 uv,跳过 rich-cli(yazi 预览会退回内置 code)"
    else
        log_note "安装 rich-cli(uv tool,清华 PyPI)..."
        local uvbin
        uvbin=$(command -v uv 2>/dev/null || true)
        [ -z "$uvbin" ] && uvbin="$PREFIX/bin/uv"
        if UV_TOOL_BIN_DIR="$PREFIX/bin" \
            UV_TOOL_DIR="$PREFIX/share/uv/tools" \
            UV_INDEX_URL="https://pypi.tuna.tsinghua.edu.cn/simple" \
            "$uvbin" tool install --force rich-cli > /tmp/uv-rich.log 2>&1; then
            log_info "rich-cli 安装完成"
        else
            track_error "rich-cli 安装失败(见 /tmp/uv-rich.log)"
        fi
    fi
}

setup_guoda_config() {
    log_step "步骤 4/6: 部署 ~/.guoda/ + myenv"

    mkdir -p "$HOME/.guoda/yazi/plugins"

    if [ -f "$SCRIPT_DIR/yazi/yazi.toml" ]; then
        cp "$SCRIPT_DIR/yazi/yazi.toml" "$HOME/.guoda/yazi/yazi.toml"
        log_info "部署 $HOME/.guoda/yazi/yazi.toml (rich-cli 预览)"
    fi
    if [ -d "$SCRIPT_DIR/yazi/plugins/rich-preview.yazi" ]; then
        rm -rf "$HOME/.guoda/yazi/plugins/rich-preview.yazi"
        cp -a "$SCRIPT_DIR/yazi/plugins/rich-preview.yazi" "$HOME/.guoda/yazi/plugins/"
        log_info "部署 rich-preview.yazi 插件"
    fi

    local src dest
    src="$SCRIPT_DIR/guoda-bashrc.container.sh"
    dest="$HOME/.guoda/bashrc.sh"
    if [ -f "$src" ]; then
        cp "$src" "$dest"
        log_info "部署 $dest"
    else
        track_error "找不到 $src"
    fi

    src="$SCRIPT_DIR/guoda-env.container.sh"
    dest="$HOME/.guoda/env.sh"
    if [ -f "$src" ]; then
        # 把模板里的占位符换成实际 PREFIX(允许 PREFIX 含 &)
        local prefix_esc
        prefix_esc=$(printf '%s' "$PREFIX" | sed 's/[&|]/\\&/g')
        sed "s|__GUODA_PREFIX__|${prefix_esc}|g" "$src" > "$dest"
        log_info "部署 $dest (PREFIX=$PREFIX)"
    else
        track_error "找不到 $src"
    fi

    printf '%s\n' "$PREFIX" > "$HOME/.guoda/prefix"
    log_info "记录安装前缀到 ~/.guoda/prefix"

    if [ -f "$SCRIPT_DIR/guoda-starship.toml" ]; then
        cp "$SCRIPT_DIR/guoda-starship.toml" "$HOME/.guoda/starship.toml"
        log_info "部署 $HOME/.guoda/starship.toml"
    fi

    if [ -f "$SCRIPT_DIR/guoda-blerc.sh" ]; then
        cp "$SCRIPT_DIR/guoda-blerc.sh" "$HOME/.guoda/blerc"
        log_info "部署 $HOME/.guoda/blerc (ble.sh 输入提示设置)"
    fi

    if [ -f "$SCRIPT_DIR/aliases.common.sh" ]; then
        cp "$SCRIPT_DIR/aliases.common.sh" "$HOME/.guoda/aliases.sh"
        log_info "部署 $HOME/.guoda/aliases.sh"
    else
        track_error "找不到 aliases.common.sh"
    fi

    # myenv 启动器:可写 /usr/local/bin 则装系统路径,否则装到 PREFIX/bin
    if [ -f "$SCRIPT_DIR/myenv" ]; then
        if [ "$(id -u)" -eq 0 ] || [ -w /usr/local/bin ]; then
            root_cmd cp "$SCRIPT_DIR/myenv" /usr/local/bin/myenv
            root_cmd chmod +x /usr/local/bin/myenv
            log_info "/usr/local/bin/myenv 已安装"
        else
            cp "$SCRIPT_DIR/myenv" "$PREFIX/bin/myenv"
            chmod +x "$PREFIX/bin/myenv"
            log_info "$PREFIX/bin/myenv 已安装(无 /usr/local/bin 写权限)"
            log_warn "当前 shell 请先: export PATH=\"$PREFIX/bin:\$PATH\""
        fi
    else
        track_error "找不到 $SCRIPT_DIR/myenv"
    fi

    log_note "不安装 myenv-clean(宿主机 Docker 清理,容器内无意义)"
    log_note "未修改 ~/.bashrc / /etc/profile"
}

verify_and_summary() {
    log_step "步骤 5/6: 验证"

    export PATH="$PREFIX/bin:$PREFIX/opt/fzf/bin:$PATH"

    printf "\n  %-14s %-32s %s\n" "工具" "路径/版本" "状态"
    printf "  %-14s %-32s %s\n" "----" "----" "----"

    local cmd full ver
    for cmd in htop tree rg fd bat tldr jq unzip git curl zoxide starship eza yazi uv rich; do
        full=$(command -v "$cmd" 2>/dev/null || true)
        [ -z "$full" ] && [ -x "$PREFIX/bin/$cmd" ] && full="$PREFIX/bin/$cmd"
        if [ -n "$full" ]; then
            ver=$("$full" --version 2>&1 | head -1 | cut -c1-32)
            printf "  %-14s %-32s %s\n" "$cmd" "$ver" "✓"
        else
            printf "  %-14s %-32s %s\n" "$cmd" "-" "✗"
        fi
    done

    if [ -x "$PREFIX/opt/fzf/bin/fzf" ]; then
        printf "  %-14s %-32s %s\n" "fzf" "$($PREFIX/opt/fzf/bin/fzf --version 2>&1 | head -1 | cut -c1-32)" "✓"
    elif command -v fzf > /dev/null 2>&1; then
        printf "  %-14s %-32s %s\n" "fzf" "$(fzf --version 2>&1 | head -1 | cut -c1-32)" "✓"
    else
        printf "  %-14s %-32s %s\n" "fzf" "-" "✗"
    fi

    if [ -f "$PREFIX/share/blesh/ble.sh" ]; then
        printf "  %-14s %-32s %s\n" "ble.sh" "$PREFIX/share/blesh" "✓"
    else
        printf "  %-14s %-32s %s\n" "ble.sh" "-" "✗"
    fi

    if command -v myenv > /dev/null 2>&1; then
        printf "  %-14s %-32s %s\n" "myenv" "$(command -v myenv)" "✓"
    else
        printf "  %-14s %-32s %s\n" "myenv" "-" "✗"
    fi

    echo ""
    if [ ${#ERRORS[@]} -eq 0 ]; then
        echo -e "${GREEN}========================================${NC}"
        echo -e "${GREEN}  容器效率工具安装完成${NC}"
        echo -e "${GREEN}========================================${NC}"
    else
        echo -e "${RED}========================================${NC}"
        echo -e "${RED}  有 ${#ERRORS[@]} 个错误:${NC}"
        echo -e "${RED}========================================${NC}"
        for err in "${ERRORS[@]}"; do
            echo -e "  ${RED}- $err${NC}"
        done
    fi

    cat <<EOF

下一步(必须敲 myenv,默认 bash 不会改):

  myenv
  ls          # eza
  z <关键词>  # zoxide
  y           # yazi(md/json/py 用 rich-cli 预览)
  uv --version
  Ctrl+R      # fzf 历史
  exit        # 回到容器默认 bash

关键路径:
  二进制     $PREFIX/bin
  fzf        $PREFIX/opt/fzf
  ble.sh     $PREFIX/share/blesh
  配置       ~/.guoda/  (bashrc.sh / env.sh / aliases.sh)
  启动器     myenv

持久化:HOME 会随容器消失时,请用
  bash scripts/setup-container.sh --prefix /data/ws/.local
EOF
}

main() {
    parse_args "$@"
    # 规范化前缀(去掉末尾 /)
    PREFIX="${PREFIX%/}"
    check_env
    install_apt_packages
    install_modern_tools
    install_yazi
    setup_guoda_config
    verify_and_summary
}

main "$@"

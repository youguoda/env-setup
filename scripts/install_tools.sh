#!/bin/bash
# WSL 开发工具链安装脚本
# 用法：bash install_tools.sh
#
# 包含：
#   - apt 工具：htop, tree, ripgrep, fd, bat, tldr 等
#   - 现代工具：zoxide, starship, fzf, eza（通过二进制/gitee 镜像）
#   - .bashrc 优化配置（30+ 别名 + 7 个函数）
#   - 兼容 symlink: fd → fdfind, bat → batcat

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib.sh
source "$SCRIPT_DIR/lib.sh"   # test_github / proxy_fetch

echo "=========================================="
echo "  WSL 工具链安装"
echo "=========================================="

# ========== 1. apt 安装基础工具 ==========
echo ""
echo "=== 步骤 1: 安装 apt 工具（需要 sudo）==="
sudo apt update
sudo DEBIAN_FRONTEND=noninteractive apt install -y \
    htop tree bash-completion \
    ripgrep fd-find bat \
    tldr ca-certificates \
    unzip zip p7zip-full

# ========== 2. 兼容 symlink ==========
echo ""
echo "=== 步骤 2: 创建兼容 symlink ==="
[ ! -L /usr/local/bin/fd ] && sudo ln -sf "$(which fdfind)" /usr/local/bin/fd || echo "  fd symlink 已存在"
[ ! -L /usr/local/bin/bat ] && sudo ln -sf "$(which batcat)" /usr/local/bin/bat || echo "  bat symlink 已存在"

# ========== 3. 修复 user service ==========
echo ""
echo "=== 步骤 3: 修复 user@1000.service ==="
sudo loginctl enable-linger $USER 2>&1 | tail -3

# ========== 4. 安装现代工具 ==========
echo ""
echo "=== 步骤 4: 安装现代工具到 ~/.local/bin ==="
mkdir -p ~/.local/bin

# test_github / proxy_fetch 来自 lib.sh
test_github && echo "  github 直连可用 ✓" || echo "  github 直连不通，将使用代理 ⚠️"

# --- zoxide ---
echo "  -- zoxide --"
if [ -f ~/.local/bin/zoxide ]; then
    echo "    zoxide 已存在，跳过"
else
    URL="https://github.com/ajeetdsouza/zoxide/releases/latest/download/zoxide-x86_64-unknown-linux-musl"
    if proxy_fetch "$URL" ~/.local/bin/zoxide; then
        chmod +x ~/.local/bin/zoxide
        echo "    ✓ zoxide 安装成功"
    else
        echo "    ✗ zoxide 安装失败（网络）"
    fi
fi

# --- starship ---
echo "  -- starship --"
if [ -f ~/.local/bin/starship ]; then
    echo "    starship 已存在，跳过"
else
    if curl -sS --max-time 30 https://starship.rs/install.sh | sh -s -- -y -b ~/.local/bin -f > /dev/null 2>&1; then
        echo "    ✓ starship 安装成功"
    else
        URL="https://github.com/starship/starship/releases/latest/download/starship-x86_64-unknown-linux-musl.tar.gz"
        if proxy_fetch "$URL" /tmp/starship.tar.gz; then
            tar xzf /tmp/starship.tar.gz -C ~/.local/bin/
            rm /tmp/starship.tar.gz
            echo "    ✓ starship 安装成功（github）"
        fi
    fi
fi

# --- fzf ---
echo "  -- fzf --"
if [ -d ~/.fzf ]; then
    echo "    fzf 已存在，跳过"
else
    if git clone --depth 1 https://gitee.com/mirrors/fzf.git ~/.fzf 2>/dev/null; then
        yes | ~/.fzf/install --all --no-update-rc --no-bash --no-zsh --no-fish > /dev/null 2>&1
        echo "    ✓ fzf 安装成功（gitee 镜像）"
    fi
fi

# --- eza ---
echo "  -- eza --"
if [ -f ~/.local/bin/eza ]; then
    echo "    eza 已存在，跳过"
else
    API_URL="https://api.github.com/repos/eza-community/eza/releases/latest"
    EZA_VERSION=""
    if test_github; then
        EZA_VERSION=$(curl -sL --max-time 15 "$API_URL" | grep -oP '"tag_name":\s*"\Kv[^"]+' | head -1)
    fi
    if [ -z "$EZA_VERSION" ]; then
        for proxy in "https://ghproxy.com/" "https://gh-proxy.com/"; do
            EZA_VERSION=$(curl -sL --max-time 15 "${proxy}${API_URL}" 2>/dev/null | grep -oP '"tag_name":\s*"\Kv[^"]+' | head -1)
            [ -n "$EZA_VERSION" ] && break
        done
    fi
    if [ -n "$EZA_VERSION" ]; then
        URL="https://github.com/eza-community/eza/releases/download/${EZA_VERSION}/eza_x86_64-unknown-linux-gnu.tar.gz"
        if proxy_fetch "$URL" /tmp/eza.tar.gz; then
            tar xzf /tmp/eza.tar.gz -C ~/.local/bin/
            rm /tmp/eza.tar.gz
            [ -f ~/.local/bin/eza_x86_64-unknown-linux-gnu/eza ] && mv ~/.local/bin/eza_x86_64-unknown-linux-gnu/eza ~/.local/bin/eza
            echo "    ✓ eza 安装成功"
        fi
    fi
fi

# ========== 5. 配置 .bashrc ==========
echo ""
echo "=== 步骤 5: 配置 ~/.bashrc ==="
BAK_NAME=~/.bashrc.bak.$(date +%s)
cp ~/.bashrc "$BAK_NAME"
echo "  已备份原 .bashrc 到 $BAK_NAME"

# 部署公共别名到 home（snippet 会 source 它，与仓库解耦）
if [ -f "$SCRIPT_DIR/aliases.common.sh" ]; then
    mkdir -p ~/.config/guoda
    cp "$SCRIPT_DIR/aliases.common.sh" ~/.config/guoda/aliases.sh
    echo "  ✓ 公共别名已部署到 ~/.config/guoda/aliases.sh"
fi

# 加载配置片段
SNIPPET="$SCRIPT_DIR/bashrc.snippet.sh"
if [ -f "$SNIPPET" ]; then
    MARKER_BEGIN="# >>> guoda optimization begin >>>"
    MARKER_END="# <<< guoda optimization end <<<"
    if grep -q "$MARKER_BEGIN" ~/.bashrc; then
        sed -i "/$MARKER_BEGIN/,/$MARKER_END/d" ~/.bashrc
        echo "  已移除旧配置块"
    fi
    cat "$SNIPPET" >> ~/.bashrc
    echo "  ✓ 已追加优化配置"
else
    echo "  ⚠️ 找不到 $SNIPPET，跳过 .bashrc 配置"
fi

# ========== 6. 更新 tldr 数据 ==========
echo ""
echo "=== 步骤 6: 更新 tldr 离线数据 ==="
if command -v tldr > /dev/null; then
    tldr --update 2>&1 | tail -3 || true
fi

# ========== 7. 验证 ==========
echo ""
echo "=== 验证 ==="
export PATH="$HOME/.local/bin:$HOME/.fzf/bin:$PATH"
for cmd in htop tree rg fd bat tldr zoxide starship eza fzf; do
    if command -v $cmd > /dev/null 2>&1 || [ -x ~/.fzf/bin/$cmd ]; then
        printf "  ✓ %s\n" "$cmd"
    else
        printf "  ✗ %s 未就绪\n" "$cmd"
    fi
done

echo ""
echo "=========================================="
echo "  🎉 安装完成！"
echo "=========================================="
echo ""
echo "下一步："
echo "  1. 打开新终端窗口，或运行: source ~/.bashrc"
echo "  2. 试试: Ctrl+R（历史命令搜索）"
echo "  3. 试试: ls（带图标的 eza）"
echo "  4. 浏览 docs/cheatsheet.md 学习更多命令"

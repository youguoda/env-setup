# shellcheck shell=bash
# lib.sh - 安装脚本共享库(颜色 / 日志 / GitHub 下载容错)
#
# 由 restore.sh、setup-myenv.sh 在开头 source:
#   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
#   source "$SCRIPT_DIR/lib.sh"
#
# 注意:本文件只定义变量与函数,不执行副作用,也不开 set 选项
# (set -uo pipefail 由调用方脚本自己负责)

# === 颜色 ===
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# === 日志 ===
log_info()  { echo -e "${GREEN}  ✓${NC} $1"; }
log_warn()  { echo -e "${YELLOW}  ⚠${NC} $1"; }
log_error() { echo -e "${RED}  ✗${NC} $1"; }
log_step()  { echo -e "\n${BLUE}${BOLD}=== $1 ===${NC}"; }
log_note()  { echo -e "${CYAN}  ℹ${NC} $1"; }

# === 错误收集(调用方需先 declare -a ERRORS=()) ===
track_error() {
    ERRORS+=("$1")
    log_error "$1"
}

# === GitHub 连通性检测 ===
test_github() {
    curl -sI --max-time 5 https://github.com > /dev/null 2>&1
}

# === 带代理回退的下载 ===
# 用法: proxy_fetch <url> <输出路径>
# 先尝试直连(若 github 可达),失败再依次走公共代理
proxy_fetch() {
    local url=$1 output=$2
    if test_github; then
        curl -fL --max-time 60 "$url" -o "$output" 2>/dev/null && return 0
    fi
    for proxy in "https://gh-proxy.com/" "https://ghproxy.net/" "https://mirror.ghproxy.com/"; do
        if curl -fL --max-time 60 "${proxy}${url}" -o "$output" 2>/dev/null; then
            return 0
        fi
    done
    return 1
}

#!/usr/bin/env bash
# check.sh - 对仓库内所有 shell 脚本跑 shellcheck(全量,手动/CI 用)
#
# 用法:
#   bash scripts/check.sh
#
# 依赖: shellcheck (sudo apt install shellcheck)
set -uo pipefail

cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)" || exit 1

if ! command -v shellcheck > /dev/null 2>&1; then
    echo "✗ 需要 shellcheck: sudo apt install shellcheck"
    exit 127
fi

# 工作区里所有 shell 文件(含未跟踪):*.sh + 无后缀的 myenv / myenv-clean
mapfile -t files < <(
    find . -path ./.git -prune -o \
        \( -name '*.sh' -o -name 'myenv' -o -name 'myenv-clean' \) -type f -print | sort
)

# --severity=warning: 只拦 warning 及以上(info/style 仅建议,不阻断)
# --exclude=SC1090,SC1091: 运行时 source 的文件无法静态跟踪,属误报
echo "检查 ${#files[@]} 个 shell 文件(含未跟踪)..."
if shellcheck -x --severity=warning --exclude=SC1090,SC1091 "${files[@]}"; then
    echo "✓ 全部通过(warning 级别)"
    echo "  想看 info/style 建议: shellcheck -x ${files[*]}"
else
    echo "✗ 有问题,见上方输出"
    exit 1
fi

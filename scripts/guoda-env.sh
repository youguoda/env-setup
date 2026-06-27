# shellcheck shell=bash
# guoda-env.sh - 环境变量(由 myenv 子 shell 加载)
# 不修改任何全局配置,只在这个文件里集中管理
# 路径: ~/.guoda/env.sh

# === PATH(优先级:自己的 > conda > 系统)===
export PATH="$HOME/.local/bin:$HOME/.fzf/bin:$HOME/miniconda3/bin:$PATH"

# === 提示符标识(让 starship 知道当前在 myenv)===
export GUODA_ENV=1
export MYENV_ACTIVE=1

# === HuggingFace(关键!避免爆 ~/.cache)===
export HF_HOME="$HOME/models"
export HF_HUB_CACHE="$HF_HOME/hub"
export TRANSFORMERS_CACHE="$HF_HOME/transformers"
export HUGGINGFACE_HUB_CACHE="$HF_HOME/hub"
export HF_HUB_ENABLE_HF_TRANSFER=1    # 大模型下载加速

# 国内服务器启用 HF 镜像(按需取消注释)
# export HF_ENDPOINT=https://hf-mirror.com

# === Torch / CUDA 路径(按需调整)===
# export CUDA_HOME=/usr/local/cuda
# export LD_LIBRARY_PATH=$CUDA_HOME/lib64:$LD_LIBRARY_PATH

# === conda 初始化 ===
if [ -f "$HOME/miniconda3/etc/profile.d/conda.sh" ]; then
    source "$HOME/miniconda3/etc/profile.d/conda.sh"
fi

# === Yazi 配置目录(让 yazi 读 ~/.guoda/yazi/ 而不是 ~/.config/yazi/)===
export YAZI_CONFIG_HOME="$HOME/.guoda/yazi"

# === 编辑器 / Pager ===
export EDITOR=vim
export VISUAL=vim
export MANPAGER="sh -c 'col -bx | batcat -l man -p'"
export BAT_THEME="Monokai Extended"
export LESS="-FRSXMI"

# === 默认端口段(供 vllm-run 等脚本读取)===
export MY_PORT_BASE=18000

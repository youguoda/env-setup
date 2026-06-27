#!/bin/bash
# ====================================================================
# vLLM 推理服务 - 通用启动脚本(模板)
#
# 用法:
#   1. 在 ./models/ 目录下创建模型配置(如 qwen2-7b.sh)
#   2. 运行: ./run-vllm.sh <配置名>
#
# 示例:
#   ./run-vllm.sh qwen2-7b
#   ./run-vllm.sh qwen2-72b
#
# 配置文件示例(models/qwen2-7b.sh):
#   MODEL_PATH="/models/hub/models--Qwen--Qwen2.5-7B-Instruct/snapshots/xxx"
#   SERVED_NAME="qwen2.5-7b"
#   TP_SIZE=1
#   MAX_LEN=32768
#   PORT=18001
# ====================================================================

set -euo pipefail

# === 默认值(可被配置文件覆盖)===
DOCKER_IMAGE="vllm/vllm-openai:latest"
GPU_UTIL=0.9
SHM_SIZE="8g"
CONTAINER_PREFIX="guoda-vllm"
LOG_DIR="${HOME}/logs"

# === 解析参数 ===
MODEL_CFG="${1:?用法: $0 <model-config>(配置文件在 ./models/<name>.sh)}"

CFG_FILE="./models/${MODEL_CFG}.sh"
if [ ! -f "$CFG_FILE" ]; then
    echo "✗ 配置不存在: $CFG_FILE"
    echo "  可用配置:"
    ls models/*.sh 2>/dev/null | sed 's|models/||;s|\.sh$|  - |' | head -20
    exit 1
fi

# 加载配置
source "$CFG_FILE"

# 必需字段检查
for var in MODEL_PATH SERVED_NAME TP_SIZE MAX_LEN PORT; do
    if [ -z "${!var:-}" ]; then
        echo "✗ 配置 $CFG_FILE 缺少必需字段: $var"
        exit 1
    fi
done

CONTAINER="${CONTAINER_PREFIX}-${MODEL_CFG}"
LOG_FILE="${LOG_DIR}/${CONTAINER}.log"

# === 前置检查 ===
echo "▶ 启动推理服务"
echo "  配置:   $MODEL_CFG"
echo "  容器:   $CONTAINER"
echo "  模型:   $SERVED_NAME"
echo "  TP:     $TP_SIZE"
echo "  端口:   $PORT (主机) → 8000 (容器)"
echo "  镜像:   $DOCKER_IMAGE"
echo ""

# Docker 可用?
if ! command -v docker > /dev/null 2>&1; then
    echo "✗ Docker 未安装"
    exit 1
fi

# GPU 够不够?
GPU_COUNT=$(nvidia-smi --list-gpus 2>/dev/null | wc -l)
if [ "$GPU_COUNT" -lt "$TP_SIZE" ]; then
    echo "✗ GPU 数不够:需要 $TP_SIZE 块,实际 $GPU_COUNT 块"
    exit 1
fi

# 模型路径存在?
if [ ! -d "$MODEL_PATH" ]; then
    echo "⚠ 模型路径不存在: $MODEL_PATH"
    echo "  用 hf-dl 下载:huggingface-cli download <repo>"
    read -p "  仍然继续?(y/N) " confirm
    [ "$confirm" = "y" ] || exit 1
fi

# 端口被占?
if ss -tln 2>/dev/null | grep -q ":${PORT} "; then
    echo "⚠ 端口 $PORT 已被占用,可能已有同名服务"
    read -p "  停掉旧容器并重启?(y/N) " confirm
    if [ "$confirm" = "y" ]; then
        docker rm -f "$CONTAINER" 2>/dev/null || true
    else
        exit 1
    fi
fi

# === 启动 ===
mkdir -p "$LOG_DIR"

# 已存在就先删
docker rm -f "$CONTAINER" 2>/dev/null || true

# 启动时间戳
echo "[$(date '+%Y-%m-%d %H:%M:%S')] 启动 $CONTAINER" >> "$LOG_FILE"

docker run -d \
    --name "$CONTAINER" \
    --gpus all \
    --ipc=host \
    --shm-size "$SHM_SIZE" \
    -p "${PORT}:8000" \
    -v "${HOME}/models:/models:ro" \
    -v "${LOG_DIR}:/logs" \
    --restart=unless-stopped \
    "$DOCKER_IMAGE" \
    --model "$MODEL_PATH" \
    --served-model-name "$SERVED_NAME" \
    --tensor-parallel-size "$TP_SIZE" \
    --gpu-memory-utilization "$GPU_UTIL" \
    --max-model-len "$MAX_LEN" \
    --trust-remote-code \
    2>&1 | tee -a "$LOG_FILE"

echo ""
echo "✓ 容器已启动"
echo ""
echo "📌 常用命令:"
echo "  看日志:    docker logs -f $CONTAINER"
echo "  测试 API:  curl http://localhost:${PORT}/v1/models"
echo "  进入容器:  docker exec -it $CONTAINER bash"
echo "  停止:      docker rm -f $CONTAINER"
echo ""
echo "🧪 快速测试:"
echo "  curl http://localhost:${PORT}/v1/chat/completions \\"
echo "    -H 'Content-Type: application/json' \\"
echo "    -d '{\"model\":\"$SERVED_NAME\",\"messages\":[{\"role\":\"user\",\"content\":\"hi\"}]}'"

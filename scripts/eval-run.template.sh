#!/bin/bash
# ====================================================================
# 模型评测 - 通用启动脚本(模板,基于 lm-eval-harness)
#
# 用法:
#   ./run-eval.sh <task> <model-endpoint> [model-name]
#
# 示例:
#   ./run-eval.sh mmlu http://localhost:18001/v1 qwen2.5-7b
#   ./run-eval.sh humaneval http://localhost:18001/v1 qwen2.5-7b
#
# 前置条件:
#   conda activate eval
#   pip install lm-eval
# ====================================================================

set -euo pipefail

TASK="${1:?用法: $0 <task> <endpoint> [model-name]}"
ENDPOINT="${2:?需要提供模型 endpoint,例如 http://localhost:18001/v1}"
MODEL_NAME="${3:-}"

# === 配置 ===
RESULT_ROOT="${HOME}/data/results"
DATE_STR=$(date +%Y%m%d-%H%M%S)
RESULT_DIR="${RESULT_ROOT}/${DATE_STR}"
mkdir -p "$RESULT_DIR"

# === 前置检查 ===
echo "▶ 启动评测"
echo "  任务:     $TASK"
echo "  Endpoint: $ENDPOINT"
echo "  模型:     ${MODEL_NAME:-auto}"
echo "  结果目录: $RESULT_DIR"
echo ""

# lm_eval 可用?
if ! command -v lm_eval > /dev/null 2>&1; then
    echo "✗ lm_eval 未安装"
    echo "  先装: conda activate eval && pip install lm-eval"
    exit 1
fi

# Endpoint 可达?
if ! curl -s --max-time 5 "${ENDPOINT}/models" > /dev/null 2>&1; then
    echo "⚠ Endpoint 不可达: $ENDPOINT"
    read -p "  仍然继续?(y/N) " confirm
    [ "$confirm" = "y" ] || exit 1
fi

# 自动取模型名(从 /v1/models)
if [ -z "$MODEL_NAME" ]; then
    MODEL_NAME=$(curl -s --max-time 5 "${ENDPOINT}/models" | jq -r '.data[0].id' 2>/dev/null)
    if [ -z "$MODEL_NAME" ] || [ "$MODEL_NAME" = "null" ]; then
        echo "✗ 无法自动获取模型名,请显式传入"
        exit 1
    fi
    echo "  自动检测模型: $MODEL_NAME"
fi

# === 跑评测 ===
OUTPUT_FILE="${RESULT_DIR}/${TASK}.json"

# 跑 lm_eval,用 OpenAI 兼容接口
lm_eval \
    --model local-chat-completions \
        --model_args "model=${MODEL_NAME},base_url=${ENDPOINT}/chat/completions,num_concurrent=8" \
    --tasks "$TASK" \
    --output_path "$OUTPUT_FILE" \
    --log_samples \
    --seed 42

# === 结果汇总 ===
echo ""
echo "✓ 评测完成: $OUTPUT_FILE"
echo ""
echo "📊 结果速览:"
jq '.results | to_entries[] | {task: .key, metric: (.value | to_entries[0].key), value: (.value | to_entries[0].value)}' \
    "$OUTPUT_FILE" 2>/dev/null || cat "$OUTPUT_FILE"

echo ""
echo "📁 完整结果(含每个样本的 log):"
ls -lh "${RESULT_DIR}/"

# 写一个 meta.json 方便后续追溯
cat > "${RESULT_DIR}/meta.json" <<EOF
{
    "task": "$TASK",
    "endpoint": "$ENDPOINT",
    "model": "$MODEL_NAME",
    "timestamp": "$(date -Iseconds)",
    "evaluator": "lm-eval-harness",
    "host": "$(hostname)"
}
EOF

echo ""
echo "📝 meta 已记录: ${RESULT_DIR}/meta.json"

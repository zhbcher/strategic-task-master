#!/bin/bash
# init-strategic-ledger.sh — 初始化 STM 战略级 WBS 台账
# v2: 支持自适应模式选择
# Usage: bash scripts/init-strategic-ledger.sh "项目名称" [output_path] [adaptive_mode]

set -e
PROJECT_NAME="${1:-My Project}"
OUTPUT_DIR="${2:-docs/spm}"
ADAPTIVE_MODE="${3:-strategic}"  # tiny/normal/strategic
OUTPUT_FILE="${OUTPUT_DIR}/ledger.md"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE="$SCRIPT_DIR/../templates/stm-ledger.md"

if [[ ! -f "$TEMPLATE" ]]; then
  echo " Template not found: $TEMPLATE"
  exit 1
fi

mkdir -p "$OUTPUT_DIR"
cp "$TEMPLATE" "$OUTPUT_FILE"

# 替换占位符
sed -i '' "s/\[项目名称\]/$PROJECT_NAME/g" "$OUTPUT_FILE" 2>/dev/null || \
sed -i "s/\[项目名称\]/$PROJECT_NAME/g" "$OUTPUT_FILE"

TIMESTAMP=$(date +"%Y-%m-%d %H:%M")
sed -i '' "s/{TIMESTAMP}/$TIMESTAMP/g" "$OUTPUT_FILE" 2>/dev/null || \
sed -i "s/{TIMESTAMP}/$TIMESTAMP/g" "$OUTPUT_FILE"

# 根据 adaptive_mode 填充默认值
case "$ADAPTIVE_MODE" in
  tiny)
    sed -i '' "s/\[tiny \/ normal \/ strategic\]/tiny/g" "$OUTPUT_FILE" 2>/dev/null || \
    sed -i "s/\[tiny \/ normal \/ strategic\]/tiny/g" "$OUTPUT_FILE"
    sed -i '' "s/\[low \/ medium \/ high\]/low/g" "$OUTPUT_FILE" 2>/dev/null || \
    sed -i "s/\[low \/ medium \/ high\]/low/g" "$OUTPUT_FILE"
    echo " Mode: tiny (skip StrategicMap, single task)"
    ;;
  normal)
    sed -i '' "s/\[tiny \/ normal \/ strategic\]/normal/g" "$OUTPUT_FILE" 2>/dev/null || \
    sed -i "s/\[tiny \/ normal \/ strategic\]/normal/g" "$OUTPUT_FILE"
    sed -i '' "s/\[low \/ medium \/ high\]/medium/g" "$OUTPUT_FILE" 2>/dev/null || \
    sed -i "s/\[low \/ medium \/ high\]/medium/g" "$OUTPUT_FILE"
    echo " Mode: normal (简版 WBS, 2-5 tasks)"
    ;;
  strategic|*)
    sed -i '' "s/\[tiny \/ normal \/ strategic\]/strategic/g" "$OUTPUT_FILE" 2>/dev/null || \
    sed -i "s/\[tiny \/ normal \/ strategic\]/strategic/g" "$OUTPUT_FILE"
    sed -i '' "s/\[low \/ medium \/ high\]/high/g" "$OUTPUT_FILE" 2>/dev/null || \
    sed -i "s/\[low \/ medium \/ high\]/high/g" "$OUTPUT_FILE"
    echo " Mode: strategic (完整 STM)"
    ;;
esac

echo " STM Strategic Ledger initialized:"
echo " Location: $OUTPUT_FILE"
echo " Adaptive Mode: $ADAPTIVE_MODE"
echo ""
echo " Next steps:"
echo "  1. 填写战略上下文（tiny/normal 模式跳过 StrategicMap）"
echo "  2. 展开 WBS 任务（每任务 Context Brief + Exit Criteria）"
echo "  3. 运行: bash scripts/attest-ledger.sh $OUTPUT_FILE"
echo ""
echo " Verify:"
echo "   bash scripts/verify-stm-ledger.sh $OUTPUT_FILE"

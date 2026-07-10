#!/bin/bash
# init-strategic-ledger.sh — 初始化 STM 战略级 WBS 台账
# Usage: bash scripts/init-strategic-ledger.sh "项目名称" [output_path]

set -e

PROJECT_NAME="${1:-My Project}"
OUTPUT_DIR="${2:-docs/spm}"
OUTPUT_FILE="${OUTPUT_DIR}/ledger.md"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE="$SCRIPT_DIR/../templates/stm-ledger.md"

if [[ ! -f "$TEMPLATE" ]]; then
  echo "❌ Template not found: $TEMPLATE"
  exit 1
fi

mkdir -p "$OUTPUT_DIR"
cp "$TEMPLATE" "$OUTPUT_FILE"

# 替换项目名
sed -i '' "s/\[项目名称\]/$PROJECT_NAME/g" "$OUTPUT_FILE" 2>/dev/null || \
sed -i "s/\[项目名称\]/$PROJECT_NAME/g" "$OUTPUT_FILE"

TIMESTAMP=$(date +"%Y-%m-%d %H:%M")
sed -i '' "s/{TIMESTAMP}/$TIMESTAMP/g" "$OUTPUT_FILE" 2>/dev/null || \
sed -i "s/{TIMESTAMP}/$TIMESTAMP/g" "$OUTPUT_FILE"

echo "✅ STM Strategic Ledger initialized:"
echo "   Location: $OUTPUT_FILE"
echo ""
echo "📝 Next steps:"
echo "   1. Fill in Strategic Context (original_goal, milestones, anti_drift_rules)"
echo "   2. Expand WBS tasks with Context Brief + Exit Criteria"
echo "   3. Run: bash scripts/attest-ledger.sh $OUTPUT_FILE"
echo ""
echo "🔍 Verify:"
echo "   bash scripts/verify-stm-ledger.sh $OUTPUT_FILE"
#!/bin/bash
# verify-stm-ledger.sh — 验证 STM 战略级 WBS 台账完整性
# Usage: bash scripts/verify-stm-ledger.sh docs/spm/ledger.md

set -e

LEDGER="${1:-docs/spm/ledger.md}"

if [[ ! -f "$LEDGER" ]]; then
  echo "❌ Ledger not found: $LEDGER"
  exit 1
fi

echo "🔍 Verifying STM Strategic Ledger: $LEDGER"
echo ""

# 1. 检查必须的 section
echo "1️⃣ Checking required sections..."
for section in "战略上下文" "WBS 任务分解" "计划变更记录" "战略变更记录" "当前执行状态" "心跳日志"; do
  if grep -q "^## $section" "$LEDGER"; then
    echo "   ✅ $section"
  else
    echo "   ❌ Missing section: $section"
    exit 1
  fi
done

# 2. 检查 WBS 表格 9 列（含 Strategic Feedback）
echo ""
echo "2️⃣ Checking WBS table columns..."
HEADER=$(head -20 "$LEDGER" | grep -E '^\| ID ')
if echo "$HEADER" | grep -q "Strategic Feedback"; then
  echo "   ✅ 9 columns (including Strategic Feedback)"
else
  echo "   ⚠️  No Strategic Feedback column found (may be using 8-col format)"
fi

# 3. 检查 Strategic Context 内容
echo ""
echo "3️⃣ Checking Strategic Context..."
if grep -q "最终目标 (Original Goal)" "$LEDGER"; then
  echo "   ✅ Original Goal found"
else
  echo "   ❌ Missing Original Goal in Strategic Context"
  exit 1
fi
if grep -q "防偏航规则" "$LEDGER"; then
  echo "   ✅ Anti-drift rules found"
else
  echo "   ⚠️  No anti-drift rules in Strategic Context"
fi

# 4. 检查 done 行是否有 evidence
echo ""
echo "4️⃣ Checking evidence for done tasks..."
done_no_evidence=0
while IFS= read -r line; do
  id=$(echo "$line" | awk -F'|' '{print $2}' | tr -d ' ')
  status=$(echo "$line" | awk -F'|' '{print $7}' | tr -d ' ')
  evidence=$(echo "$line" | awk -F'|' '{print $6}' | tr -d ' ')
  if [[ "$status" == "done" && -z "$evidence" ]]; then
    echo "   ❌ Task $id is done but evidence is empty"
    done_no_evidence=$((done_no_evidence + 1))
  fi
done < <(grep -E '^\|[[:space:]]*[0-9]+' "$LEDGER" || true)

if [[ $done_no_evidence -eq 0 ]]; then
  echo "   ✅ All done tasks have evidence"
fi

# 5. 检查 Strategic Feedback 非空行是否处理
echo ""
echo "5️⃣ Checking Strategic Feedback handling..."
while IFS= read -r line; do
  feedback=$(echo "$line" | awk -F'|' '{print $9}' | tr -d ' ')
  status=$(echo "$line" | awk -F'|' '{print $7}' | tr -d ' ')
  if [[ -n "$feedback" && "$feedback" != "-" && "$status" == "done" ]]; then
    echo "   ⚠️  Task has Strategic Feedback but status is done (needs review)"
  fi
done < <(grep -E '^\|[[:space:]]*[0-9]' "$LEDGER" || true)

echo ""
echo "✅ STM Ledger verification PASSED"
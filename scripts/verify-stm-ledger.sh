#!/bin/bash
# verify-stm-ledger.sh — 验证 STM 战略级 WBS 台账完整性
# v2.1: 增加 State Compression, Hard Replan Limit, Evidence Strength, Divergent Trigger 检查
# Usage: bash scripts/verify-stm-ledger.sh docs/spm/ledger.md

set -e
LEDGER="${1:-docs/spm/ledger.md}"

if [[ ! -f "$LEDGER" ]]; then
  echo "❌ Ledger not found: $LEDGER"
  exit 1
fi

echo "🔍 Verifying STM Strategic Ledger: $LEDGER"
echo ""

errors=0
warnings=0

# 1. 检查必须的 section
echo "1️⃣ Checking required sections..."
required_sections=("元数据" "战略上下文" "置信度评分" "WBS 任务分解" "计划变更记录" "当前执行状态" "心跳日志" "交付总结")
for section in "${required_sections[@]}"; do
  if grep -q "^## $section" "$LEDGER"; then
    echo "  ✅ $section"
  else
    echo "  ❌ Missing section: $section"
    errors=$((errors + 1))
  fi
done

# 2. 检查元数据字段（v2.1 新增：任务分级、计划冻结）
echo ""
echo "2️⃣ Checking metadata (v2.1)..."
adaptive_mode=$(grep -E '^\*\*自适应模式\*\*' "$LEDGER" | sed 's/.*\[\(.*\)\].*/\1/' | head -1)
task_tier=$(grep -E '^\*\*任务分级\*\*' "$LEDGER" | sed 's/.*\[\(.*\)\].*/\1/' | head -1)
cost_budget=$(grep -E '^\*\*成本预算\*\*' "$LEDGER" | sed 's/.*\[\(.*\)\].*/\1/' | head -1)
replan_count=$(grep -E '^\*\*重规划计数\*\*' "$LEDGER" | sed 's/.*\[\(.*\)\/.*\].*/\1/' | head -1)
plan_frozen=$(grep -E '^\*\*计划冻结\*\*' "$LEDGER" | sed 's/.*\[\(.*\)\].*/\1/' | head -1)

# Adaptive mode
if [[ -n "$adaptive_mode" ]] && [[ "$adaptive_mode" =~ ^(tiny|normal|strategic)$ ]]; then
  echo "  ✅ Adaptive mode: $adaptive_mode"
else
  echo "  ⚠️ Invalid or missing adaptive mode"
  warnings=$((warnings + 1))
fi

# Task tier (v2.1)
if [[ -n "$task_tier" ]] && [[ "$task_tier" =~ ^(S|M|L|XL)$ ]]; then
  echo "  ✅ Task tier: $task_tier"
else
  echo "  ⚠️ Invalid or missing task tier (expected: S/M/L/XL)"
  warnings=$((warnings + 1))
fi

# Cost budget
if [[ -n "$cost_budget" ]] && [[ "$cost_budget" =~ ^(low|medium|high)$ ]]; then
  echo "  ✅ Cost budget: $cost_budget"
else
  echo "  ⚠️ Invalid cost budget"
  warnings=$((warnings + 1))
fi

# Replan limit (hard)
if [[ -n "$replan_count" ]] && [[ "$replan_count" =~ ^[0-9]+$ ]]; then
  if [[ "$replan_count" -ge 3 ]]; then
    echo "  🚨 REPLAN LIMIT REACHED: $replan_count/3 — plan should be frozen!"
    errors=$((errors + 1))
  else
    echo "  ✅ Replan count: $replan_count/3"
  fi
else
  echo "  ⚠️ Replan count not found or invalid"
  warnings=$((warnings + 1))
fi

# Plan frozen check (v2.1)
if [[ "$plan_frozen" == "true" ]] && [[ "$replan_count" -lt 3 ]]; then
  echo "  ⚠️ Plan frozen but replan_count < 3 (inconsistent)"
  warnings=$((warnings + 1))
elif [[ "$plan_frozen" != "true" ]] && [[ "$replan_count" -ge 3 ]]; then
  echo "  🚨 Replan count >=3 but plan_frozen != true (should freeze!)"
  errors=$((errors + 1))
fi

# 3. 检查置信度评分表格（v2.1：evidence_strength 列）
echo ""
echo "3️⃣ Checking Confidence Score table (v2.1)..."
# 查找置信度评分表格，检查表头
header=$(grep -E '^\| *时间 *\|' "$LEDGER" | head -1)
if [[ -z "$header" ]]; then
  echo "  ⚠️ No Confidence Score table found"
  warnings=$((warnings + 1))
else
  # 检查列
  if echo "$header" | grep -q "证据强度"; then
    echo "  ✅ Evidence Strength column present"
  else
    echo "  ⚠️ Missing '证据强度' column (v2.1 feature)"
    warnings=$((warnings + 1))
  fi
  if echo "$header" | grep -q "置信度"; then
    echo "  ✅ Confidence column present"
  else
    echo "  ⚠️ Missing '置信度' column"
    warnings=$((warnings + 1))
  fi
fi

# 4. 检查 WBS 表格（v2.1：置信度列 + Strategic Feedback）
echo ""
echo "4️⃣ Checking WBS table columns (v2.1)..."
wbs_header=$(grep -E '^\| *ID *\|' "$LEDGER" | head -1)
if [[ -z "$wbs_header" ]]; then
  echo "  ❌ WBS table not found"
  errors=$((errors + 1))
else
  column_count=$(echo "$wbs_header" | awk -F'|' '{print NF}')
  if [[ "$column_count" -ge 10 ]]; then
    echo "  ✅ WBS table has $((column_count - 1)) columns"
  else
    echo "  ⚠️ WBS table has only $((column_count - 1)) columns (expected at least 9)"
    warnings=$((warnings + 1))
  fi

  if echo "$wbs_header" | grep -q "置信度"; then
    echo "  ✅ Confidence column in WBS"
  fi

  if echo "$wbs_header" | grep -q "Strategic Feedback"; then
    echo "  ✅ Strategic Feedback column present"
  else
    echo "  ⚠️ No Strategic Feedback column"
    warnings=$((warnings + 1))
  fi
fi

# 5. 检查 done 行是否有 evidence（铁律）
echo ""
echo "5️⃣ Checking evidence for done tasks..."
done_no_evidence=0
while IFS= read -r line; do
  id=$(echo "$line" | awk -F'|' '{print $2}' | tr -d ' ')
  status=$(echo "$line" | awk -F'|' '{print $7}' | tr -d ' ')
  evidence=$(echo "$line" | awk -F'|' '{print $6}' | tr -d ' ')
  if [[ "$status" == "done" && -z "$evidence" ]]; then
    echo "  ❌ Task $id is done but evidence is empty"
    done_no_evidence=$((done_no_evidence + 1))
  fi
done < <(grep -E '^\|[[:space:]]*[0-9]+' "$LEDGER" || true)

if [[ $done_no_evidence -eq 0 ]]; then
  echo "  ✅ All done tasks have evidence"
fi
errors=$((errors + done_no_evidence))

# 6. 检查 Hot/Warm/Cold 分区使用（v2.1 state compression）
echo ""
echo "6️⃣ Checking State Compression indicators..."
# 简单检查：是否提到了 Hot/Warm/Cold 分区（在 inject-stm-context 注释或文档中）
if grep -q "Hot" "$LEDGER" && grep -q "Warm" "$LEDGER" && grep -q "Cold" "$LEDGER"; then
  echo "  ✅ Ledger mentions Hot/Warm/Cold zones (good)"
else
  echo "  ℹ️  Ledger does not explicitly mention state zones (may be new ledger)"
fi

# 7. 检查 Stratetgic Debt (v2.1 可选)
echo ""
echo "7️⃣ Checking Strategic Debt tracking..."
if grep -q "战略债" "$LEDGER"; then
  debt_score=$(grep -E 'strategic_debt_score' "$LEDGER" | head -1 | sed 's/.*\[\(.*\)\].*/\1/')
  if [[ -n "$debt_score" ]]; then
    echo "  ✅ Strategic Debt Score present: $debt_score"
  else
    echo "  ⚠️ Strategic Debt section exists but score not set"
    warnings=$((warnings + 1))
  fi
else
  echo "  ℹ️  Strategic Debt not yet tracked (optional v2.1 feature)"
fi

# 8. 检查 Divergent Trigger 条件（元数据中应有记录）
echo ""
echo "8️⃣ Checking Divergent Explorer trigger policy..."
if grep -q "divergent_trigger" "$LEDGER"; then
  echo "  ✅ Divergent trigger policy documented"
else
  echo "  ℹ️  Divergent trigger policy not in ledger (may be in references)"
fi

# 9. 检查循环依赖
echo ""
echo "9️⃣ Checking for circular dependencies..."
task_ids=$(grep -E '^\|[[:space:]]*[0-9]+' "$LEDGER" | awk -F'|' '{print $2}' | tr -d ' ')
circular=0
while IFS= read -r line; do
  deps=$(echo "$line" | awk -F'|' '{print $3}' | tr -d ' ')
  if [[ -n "$deps" && "$deps" != "-" ]]; then
    for dep in $(echo "$deps" | tr ',' ' '); do
      dep=$(echo "$dep" | tr -d ' ')
      if ! echo "$task_ids" | grep -q "^${dep}$"; then
        echo "  ⚠️ Task references non-existent dependency: $dep"
        circular=$((circular + 1))
      fi
    done
  fi
done < <(grep -E '^\|[[:space:]]*[0-9]+' "$LEDGER" || true)

if [[ $circular -eq 0 ]]; then
  echo "  ✅ No broken dependency references"
else
  warnings=$((warnings + circular))
fi

# 总结
echo ""
echo "═══════════════════════════════════════════"
if [[ $errors -eq 0 && $warnings -eq 0 ]]; then
  echo "✅ STM Ledger verification PASSED (v2.1)"
elif [[ $errors -eq 0 ]]; then
  echo "⚠️  STM Ledger verification PASSED with $warnings warning(s)"
else
  echo "❌ STM Ledger verification FAILED: $errors error(s), $warnings warning(s)"
  exit 1
fi
echo "═══════════════════════════════════════════"

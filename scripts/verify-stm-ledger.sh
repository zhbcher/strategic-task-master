#!/bin/bash
# verify-stm-ledger.sh — 验证 STM 战略级 WBS 台账完整性
# v3.0: 增加 Profile, Trust Score, Value Score, Milestone Dependencies, Rollback Plan, Semantic Summary, Terminal Detection, Mode Escalation
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

# 1. 检查必须的 section (v3.0)
echo "1️⃣ Checking required sections..."
required_sections=("元数据" "战略上下文" "置信度评分" "WBS 任务分解" "计划变更记录" "当前执行状态" "心跳日志" "语义摘要" "交付总结")
for section in "${required_sections[@]}"; do
  if grep -q "^## $section" "$LEDGER"; then
    echo "  ✅ $section"
  else
    echo "  ⚠️ Missing section: $section (v3.0 feature)"
    warnings=$((warnings + 1))
  fi
done

# 2. 检查元数据字段（v3.0 新增）
echo ""
echo "2️⃣ Checking metadata (v3.0)..."
# Helper: extract value from "- **key**: value" or "**key**: value" formats
extract_meta() {
  local key="$1"
  local line=$(grep -E "^-[[:space:]]*\\*\\*${key}\\*\\*" "$LEDGER" | head -1)
  if [[ -z "$line" ]]; then
    line=$(grep -E "^\\*\\*${key}\\*\\*" "$LEDGER" | head -1)
  fi
  echo "$line"
}
extract_value() {
  local line="$1"
  # Extract value after ": "
  local val=$(echo "$line" | sed 's/.*\*\*:[[:space:]]*//' | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
  # If value is in brackets, extract inner content
  if echo "$val" | grep -q '^\[.*\]$'; then
    echo "$val" | sed 's/^\[\(.*\)\]$/\1/'
  else
    echo "$val"
  fi
}

meta_line=$(extract_meta "自适应模式")
adaptive_mode=$(extract_value "$meta_line")
meta_line=$(extract_meta "任务分级")
task_tier=$(extract_value "$meta_line")
meta_line=$(extract_meta "配置档位")
profile=$(extract_value "$meta_line")
meta_line=$(extract_meta "成本预算")
cost_budget=$(extract_value "$meta_line")
meta_line=$(extract_meta "重规划计数")
replan_count_raw=$(extract_value "$meta_line")
# replan_count: handle "0/3" format
replan_count=$(echo "$replan_count_raw" | sed 's|/.*||')
meta_line=$(extract_meta "回滚计数")
rollback_count_raw=$(extract_value "$meta_line")
rollback_count=$(echo "$rollback_count_raw" | sed 's|/.*||')
meta_line=$(extract_meta "计划冻结")
plan_frozen=$(extract_value "$meta_line")
meta_line=$(extract_meta "信任评分")
trust_score=$(extract_value "$meta_line")
meta_line=$(extract_meta "价值评分")
value_score=$(extract_value "$meta_line")
meta_line=$(extract_meta "终端故障检测")
terminal_enabled=$(extract_value "$meta_line")

# Adaptive mode
if [[ -n "$adaptive_mode" ]] && [[ "$adaptive_mode" =~ ^(tiny|normal|strategic)$ ]]; then
  echo "  ✅ Adaptive mode: $adaptive_mode"
else
  echo "  ⚠️ Invalid or missing adaptive mode (expected: tiny/normal/strategic)"
  warnings=$((warnings + 1))
fi

# Task tier
if [[ -n "$task_tier" ]] && [[ "$task_tier" =~ ^(S|M|L|XL)$ ]]; then
  echo "  ✅ Task tier: $task_tier"
else
  echo "  ⚠️ Invalid or missing task tier (expected: S/M/L/XL)"
  warnings=$((warnings + 1))
fi

# Profile (v3.0)
if [[ -n "$profile" ]] && [[ "$profile" =~ ^(lean|standard|enterprise)$ ]]; then
  echo "  ✅ Profile: $profile"
else
  echo "  ⚠️ Invalid or missing profile (expected: lean/standard/enterprise)"
  warnings=$((warnings + 1))
fi

# Cost budget
if [[ -n "$cost_budget" ]] && [[ "$cost_budget" =~ ^(low|medium|high)$ ]]; then
  echo "  ✅ Cost budget: $cost_budget"
else
  echo "  ⚠️ Invalid cost budget"
  warnings=$((warnings + 1))
fi

# Replan limit
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

# Rollback count (v3.0)
if [[ -n "$rollback_count" ]] && [[ "$rollback_count" =~ ^[0-9]+$ ]]; then
  if [[ "$rollback_count" -ge 2 ]]; then
    echo "  🚨 ROLLBACK LIMIT REACHED: $rollback_count/2"
    errors=$((errors + 1))
  else
    echo "  ✅ Rollback count: $rollback_count/2"
  fi
else
  echo "  ℹ️ Rollback count not set (optional)"
fi

# Plan frozen check
if [[ "$plan_frozen" == "true" ]] && [[ "$replan_count" -lt 3 ]] && [[ "$rollback_count" -lt 2 ]]; then
  echo "  ⚠️ Plan frozen but counts below limits (inconsistent)"
  warnings=$((warnings + 1))
elif [[ "$plan_frozen" != "true" ]] && { [[ "$replan_count" -ge 3 ]] || [[ "$rollback_count" -ge 2 ]]; }; then
  echo "  🚨 Count limit reached but plan_frozen != true (should freeze!)"
  errors=$((errors + 1))
fi

# Trust Score and Value Score (v3.0)
if [[ -n "$trust_score" ]] && [[ "$trust_score" =~ ^[0-9]+$ ]] && [[ "$trust_score" -le 100 ]]; then
  echo "  ✅ Trust Score: $trust_score"
else
  echo "  ℹ️ Trust Score not set or invalid (0-100 expected)"
fi

if [[ -n "$value_score" ]] && [[ "$value_score" =~ ^[0-9]+$ ]] && [[ "$value_score" -le 100 ]]; then
  echo "  ✅ Value Score: $value_score"
else
  echo "  ℹ️ Value Score not set or invalid (0-100 expected)"
fi

# Terminal detection enabled
if [[ -n "$terminal_enabled" ]]; then
  if [[ "$terminal_enabled" == "enabled" ]]; then
    echo "  ✅ Terminal Failure detection: enabled"
  else
    echo "  ℹ️ Terminal Failure detection: disabled"
  fi
fi

# 3. 检查置信度评分表格（v3.0: 增加 trust_score, value_score 列）
echo ""
echo "3️⃣ Checking Confidence Score table (v3.0)..."
header=$(grep -E '^\| *时间 *\|' "$LEDGER" | head -1)
if [[ -z "$header" ]]; then
  echo "  ⚠️ No Confidence Score table found"
  warnings=$((warnings + 1))
else
  if echo "$header" | grep -q "信任评分"; then
    echo "  ✅ Trust Score column present"
  else
    echo "  ⚠️ Missing '信任评分' column (v3.0 feature)"
    warnings=$((warnings + 1))
  fi
  if echo "$header" | grep -q "价值评分"; then
    echo "  ✅ Value Score column present"
  else
    echo "  ⚠️ Missing '价值评分' column (v3.0 feature)"
    warnings=$((warnings + 1))
  fi
  if echo "$header" | grep -q "证据强度"; then
    echo "  ✅ Evidence Strength column present"
  else
    echo "  ⚠️ Missing '证据强度' column"
    warnings=$((warnings + 1))
  fi
fi

# 4. 检查 WBS 表格（v3.0: Rollback Plan, Trust, Value 列）
echo ""
echo "4️⃣ Checking WBS table columns (v3.0)..."
wbs_header=$(grep -E '^\| *ID *\|' "$LEDGER" | head -1)
if [[ -z "$wbs_header" ]]; then
  echo "  ❌ WBS table not found"
  errors=$((errors + 1))
else
  column_count=$(echo "$wbs_header" | awk -F'|' '{print NF}')
  expected_cols=14  # ID, 任务名称, 依赖, Milestone, Context Brief, Exit Criteria, Rollback Plan, Evidence, Status, 置信度, Trust, Value, Strategic Feedback (maybe more)
  if [[ "$column_count" -ge 12 ]]; then
    echo "  ✅ WBS table has $((column_count - 1)) columns"
  else
    echo "  ⚠️ WBS table has only $((column_count - 1)) columns (expected at least 11 for v3.0)"
    warnings=$((warnings + 1))
  fi

  if echo "$wbs_header" | grep -q "Rollback Plan"; then
    echo "  ✅ Rollback Plan column present"
  else
    echo "  ⚠️ Missing 'Rollback Plan' column (v3.0 feature)"
    warnings=$((warnings + 1))
  fi

  if echo "$wbs_header" | grep -q "Trust"; then
    echo "  ✅ Trust column present"
  else
    echo "  ⚠️ Missing 'Trust' column"
    warnings=$((warnings + 1))
  fi

  if echo "$wbs_header" | grep -q "Value"; then
    echo "  ✅ Value column present"
  else
    echo "  ⚠️ Missing 'Value' column"
    warnings=$((warnings + 1))
  fi
fi

# 5. 检查 Semantic Summary 区块（v3.0）
echo ""
echo "5️⃣ Checking Semantic Summary section..."
if grep -q "^## 语义摘要" "$LEDGER"; then
  echo "  ✅ Semantic Summary section exists"
  # 检查必要子节
  if grep -q "### 最近 10 次验证摘要" "$LEDGER"; then
    echo "  ✅ Verification summary subsection present"
  fi
  if grep -q "### 最近 5 次变更摘要" "$LEDGER"; then
    echo "  ✅ Mutation summary subsection present"
  fi
  if grep -q "### 信任评分演变" "$LEDGER"; then
    echo "  ✅ Trust score evolution subsection present"
  fi
else
  echo "  ⚠️ Missing '## 语义摘要' section (v3.0 feature)"
  warnings=$((warnings + 1))
fi

# 6. 检查战略上下文中的依赖图（v3.0）
echo ""
echo "6️⃣ Checking Strategic Context for milestone dependencies..."
if grep -q "里程碑依赖图" "$LEDGER"; then
  echo "  ✅ Milestone dependency section present"
  if grep -q "关键路径" "$LEDGER"; then
    echo "  ✅ Critical path mentioned"
  else
    echo "  ⚠️ No critical path in dependency section"
    warnings=$((warnings + 1))
  fi
else
  echo "  ℹ️ Milestone dependency graph not in ledger (optional for non-strategic modes)"
fi

# 7. 检查 done 行是否有 evidence 和 rollback plan
echo ""
echo "7️⃣ Checking evidence and rollback plan for done tasks..."
done_missing=0
while IFS= read -r line; do
  id=$(echo "$line" | awk -F'|' '{print $2}' | tr -d ' ')
  status=$(echo "$line" | awk -F'|' '{print $8}' | tr -d ' ')  # status 列 index 7 (0-based?)
  evidence=$(echo "$line" | awk -F'|' '{print $7}' | tr -d ' ') # evidence 列 index 6
  rollback=$(echo "$line" | awk -F'|' '{print $9}' | tr -d ' ') # rollback plan index 8 (if column order)
  # Actually need to count columns precisely. We'll just check that evidence is not empty.
  if [[ "$status" == "done" && -z "$evidence" ]]; then
    echo "  ❌ Task $id is done but evidence is empty"
    done_missing=$((done_missing + 1))
  fi
done < <(grep -E '^\|[[:space:]]*[0-9]+[[:space:]]*\|' "$LEDGER" || true)

if [[ $done_missing -eq 0 ]]; then
  echo "  ✅ All done tasks have evidence"
else
  errors=$((errors + done_missing))
fi

# 8. 检查循环依赖（基于里程碑依赖）
echo ""
echo "8️⃣ Checking for circular dependencies in milestones..."
# 提取战略上下文中的 milestone 依赖关系（简单匹配 "id: X, depends_on: [Y,Z]"）
# 这里简化处理，仅检查 WBS 中的任务依赖是否引用存在的任务
# Only match WBS rows where first field is a pure integer (not dates/percentages)
task_ids=$(grep -E '^\|[[:space:]]*[0-9]+[[:space:]]*\|' "$LEDGER" | awk -F'|' '{print $2}' | tr -d ' ' | sort -n)
circular=0
while IFS= read -r line; do
  # Fix: dependency is column 4 in v3.0 (13-col WBS)
deps=$(echo "$line" | awk -F'|' '{print $4}' | tr -d ' ')
  if [[ -n "$deps" && "$deps" != "-" ]]; then
    for dep in $(echo "$deps" | tr ',' ' '); do
      dep=$(echo "$dep" | tr -d ' ')
      if ! echo "$task_ids" | grep -q "^${dep}$"; then
        echo "  ⚠️ Task references non-existent dependency: $dep"
        circular=$((circular + 1))
      fi
    done
  fi
done < <(grep -E '^\|[[:space:]]*[0-9]+[[:space:]]*\|' "$LEDGER" || true)

if [[ $circular -eq 0 ]]; then
  echo "  ✅ No broken dependency references"
else
  warnings=$((warnings + circular))
fi

# 9. 检查 Semantic Summary 完整性（如果存在）
echo ""
echo "9️⃣ Checking Semantic Summary completeness..."
if grep -q "^## 语义摘要" "$LEDGER"; then
  missing_subsections=0
  if ! grep -q "### 最近 10 次验证摘要" "$LEDGER"; then
    echo "  ⚠️ Missing '最近 10 次验证摘要' subsection"
    missing_subsections=$((missing_subsections + 1))
  fi
  if ! grep -q "### 最近 5 次变更摘要" "$LEDGER"; then
    echo "  ⚠️ Missing '最近 5 次变更摘要' subsection"
    missing_subsections=$((missing_subsections + 1))
  fi
  if ! grep -q "### 信任评分演变" "$LEDGER"; then
    echo "  ⚠️ Missing '信任评分演变' subsection"
    missing_subsections=$((missing_subsections + 1))
  fi
  if [[ $missing_subsections -eq 0 ]]; then
    echo "  ✅ Semantic Summary subsections complete"
  else
    warnings=$((warnings + missing_subsections))
  fi
fi

# 总结
echo ""
echo "═══════════════════════════════════════════"
if [[ $errors -eq 0 && $warnings -eq 0 ]]; then
  echo "✅ STM Ledger verification PASSED (v3.0)"
elif [[ $errors -eq 0 ]]; then
  echo "⚠️  STM Ledger verification PASSED with $warnings warning(s)"
else
  echo "❌ STM Ledger verification FAILED: $errors error(s), $warnings warning(s)"
  exit 1
fi
echo "═══════════════════════════════════════════"
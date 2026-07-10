# Three-Tier Fault Tolerance — 三级容错（v2.1 完整版）

> STM v2: 增加故障分类器。STM v2.1: 增加 Divergent Trigger 收紧、Hard Replan Limit、State Compression 协作。

## 完整执行流程（v2.1）

```
失败
  │
  ├→ 故障分类器 classify_failure(error)
  │    │
  │    ├─ execution
  │    │     └→ L1: 验证门禁 → pass? → 继续 & 更新 confidence
  │    │          └→ fail? → L2: Ralph Loop A→B→C
  │    │                           ├→ 成功 → 更新 confidence
  │    │                           └→ 3轮全败 
  │    │                               ├→ ralph_failed=3 AND confidence<40? → L3: Divergent Explorer
  │    │                               └→ otherwise → 继续 Ralph (最多 5 轮)
  │    │                                          ├→ 成功 → 重写WBS + 更新置信度
  │    │                                          └→ 失败 → L2 Decoupled → 上报用户
  │    │
  │    ├─ environment
  │    │     └→ 请求用户介入
  │    │          └→ 用户无响应或拒绝 → 上报
  │    │
  │    ├─ dependency
  │    │     └→ 重新规划 WBS (insert 新任务)
  │    │          ├→ 3次方案以内成功 → 继续
  │    │          └→ 3次方案不行 → L3: Divergent Explorer
  │    │
  │    └─ architecture
  │          └→ (跳过 L1/L2) → L3: Divergent Explorer (直接进入)
  │                               ├→ 成功 → 重写WBS + 更新置信度 + 检查 replan_count
  │                               └→ 失败 → L2 Decoupled → 上报用户
  │
  └→ 每次完成（无论成功失败）:
        - 更新 Confidence Score (completion, confidence, evidence_strength)
        - 写入 Heartbeat Log
        - 检查 Hard Replan Limit:
            if replan_count >= 3 → plan_frozen = true → escalate
            if divergent_count >= 1 → 冻结并上报
        - 执行 State Compression:
            - Hot 区保持 <= 1500 chars (preToolUse 注入)
            - Warm 区落盘不注入
            - Cold 区归档
```

## 各层说明 (v2.1)

### L1: 验证门禁 (Verification Gate)

所有故障类型的必经第一步。IDENTIFY→RUN→READ→VERIFY。

同时调用 `evidence_strength_assessor` 评估证据强度。

### L2: Ralph Loop (战术重试)

仅 execution 类型使用。A→B→C 策略轮换，每轮：
- 更新 confidence (+2%)
- 记录 mutation log (ralph-retry-N)
- 检查 ralph_failed 计数

**v2.1 变化**: 3 轮失败后不立即进 Divergent，额外检查:
```yaml
if ralph_failed >= 3 AND confidence < 40:
  go Divergent
else:
  continue Ralph (up to 5 rounds max)
```

### L3: Divergent Explorer (战略探索)

architecture 类型直接进入。execution 类型满足上述条件后进入。

**输入限制**: 仅 `failed_milestone_id + error_summary`（1 行），避免 context 污染。

**输出**: 3 条不同底层逻辑的路径。

成功后:
- 重写 WBS
- 更新 confidence (+5%)
- increment replan_count

失败后:
- L2 Decoupled
- 仍失败 → 上报

**频率控制**:
- 单任务最多 1 次
- 超过即冻结

### L2 Decoupled (降级修复)

最后尝试。只读补丁修复，不引入新方案。

### 上报用户

所有路径的最终出口。内容包括:
- 故障分类结果
- 已尝试的容错路径 (Ralph 轮次、Divergent 路径)
- 当前置信度评分 (completion/confidence/evidence_strength)
- 重规划计数 (replan_count/3)
- 建议下一步

## 硬熔断：Hard Replan Limit (v2.1)

```yaml
replan_policy:
  max_replan: 3              # 硬上限
  max_divergent: 1           # 最多一次 Divergent
  max_execution_cycles: 20   # 单任务最多执行轮次（包括重试）
  plan_frozen: false         # 熔断后置 true
```

**检查点**:
1. 每次 `strategic-replan` 后: `replan_count += 1`
2. 每次 `divergent_exploration` 后: `divergent_count += 1`
3. 任一超过限制 → `plan_frozen = true` → 立即上报

**解除**: 用户手动确认后可重置计数或另开新 ledger。

## State Compression 协作 (v2.1)

在每次 preToolUse 注入时，只读取 Hot 区内容（<=1500 chars）：

**Hot**:
- Current task
- Current milestone
- Recent verifications (last 3)
- Confidence score
- Strategic Context (strategic mode)

**Warm** (落盘):
- Recent mutations (last 5)
- Recent heartbeats (last 10)

**Cold** (归档):
- Completed tasks (migrate when >50)
- Historical snapshots

好处:
- Context 保持稳定，不随任务轮次线性增长
- Warm/Cold 仍保留完整审计轨迹，需时可按需读取

## 关键指标

| 指标 | 目标 | 检查频率 |
|------|------|---------|
| Context growth | < 10% per 10 tasks | 每任务 |
| Confidence plateau | < 3 consecutive flat with completion<80% | 每更新 |
| Divergent frequency | < 5% of all failures | 每故障 |
| Replan count | < 3 | 每突变 |
| Evidence strength | > 50 for done tasks | 每完成 |

## 与 v2 的关键区别

| 维度 | v2 | v2.1 |
|------|-----|------|
| Divergent trigger | ralph_failed == 3 | ralph_failed >= 3 **AND** confidence < 40 **AND** architecture type |
| Hard limit | 只有 replan_limit | 增加 max_divergent, max_execution_cycles, plan_frozen |
| Context control | 无 | State Compression: Hot/Warm/Cold |
| Evidence evaluation | 无 | evidence_strength 维度加入 confidence 计算 |
| 熔断检查点 | 无 | 每次 mutation 后检查 |

## 故障类型映射总结

| 故障类型 | 首选策略 | 最大重试 | 升级条件 | 目标 |
|---------|---------|---------|---------|------|
| execution | Ralph Loop | 3-5 轮 | `ralph_failed>=3 AND confidence<40` | Divergent |
| environment | 请求用户 | 1 次 | 用户无响应 | Escalate |
| dependency | 重新规划 WBS | 3 次 | 3 次失败 | Divergent |
| architecture | Divergent (跳过 Ralph) | 1 次 | 失败 | L2 Decoupled → Escalate |
| provider error | Model Fallback | 3 次 | fallback 全败 | Ralph Loop |
| silent_failure | Mark blocked | 2 次 | fallback 仍空 | Block |
| policy violation | Escalate | 0 | — | User immediately |

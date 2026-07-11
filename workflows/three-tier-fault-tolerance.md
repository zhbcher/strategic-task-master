# Three-Tier Fault Tolerance — 三级容错（v3.0 完整版）

> v2: 故障分类器。v2.1: Divergent 触发收紧、硬熔断、State Compression。v3.0: Terminal 故障、Rollback 策略、Mode Escalation、Semantic Summary。

## 完整执行流程（v3.0）

```
任务开始
  │
  ├─ Phase 0: Value Assessment + Adaptive Mode Selector
  │     → 输出: adaptive_mode, task_tier, profile, value_score
  │
  ├─ Phase 1: (strategic only) Strategic Map + Dependencies + Snapshot
  │
  └─ Phase 2: 子代理执行循环
        │
        ├─ 执行 → 验证门禁
        │     │
        │     └─ 失败? → 故障分类器
        │           │
        │           ├─ execution → Ralph Loop (3-5轮)
        │           │            ├→ 成功 → 更新多维评分 + trust_score
        │           │            └→ 3轮全败
        │           │                ├→ ralph_failed>=3 AND confidence<40? → Divergent Explorer
        │           │                └→ otherwise → 继续 Ralph (最多5轮) → 仍失败 → L2 Decoupled → 上报
        │           │
        │           ├─ environment → 请求用户介入 → 无响应 → 上报
        │           │
        │           ├─ dependency → 重新规划 WBS (最多3次) → 成功继续, 失败 → Divergent
        │           │
        │           ├─ architecture → (跳过 Ralph) → Divergent Explorer
        │           │                     ├→ 成功 → 重写 WBS + 更新评分 + 检查 replan_count
        │           │                     └→ 失败 → L2 Decoupled → 上报
        │           │
        │           └─ terminal → 立即停止，标记 blocked，上报用户（不进入容错）
        │
        ├─ 每次完成（无论成功失败）:
        │     - 更新 Confidence Score (含 evidence_strength, trust_score, value_score)
        │     - 写入 Heartbeat Log
        │     - 生成 Semantic Summary (每 10 次心跳)
        │     - 检查 Hard Replan Limit & Rollback Limit:
        │         if replan_count >= 3 → plan_frozen = true → escalate
        │         if rollback_count >= 2 → plan_frozen = true → escalate
        │         if divergent_count >= 1 → escalate
        │     - 运行 mode_escalation_assessor → 如有升级/降级 → 触发 strategic-replan
        │     - 运行 rollback_recommender → 如建议 rollback → 执行回滚 (task/milestone/strategic)
        │
        └─ 继续执行或退出（根据 status）
```

## 各层说明 (v3.0)

### L1: 验证门禁 (Verification Gate)

- IDENTIFY → RUN → READ → VERIFY
- 同时调用 `evidence_strength_assessor` 评估证据强度
- 触发条件：任何任务完成后

### L2: Ralph Loop (战术重试)

- 仅 `execution` 类型使用
- 策略 A→B→C 轮换
- 每轮后：
  - 更新 `confidence` (+2%)
  - 记录 `mutation log` (ralph-retry-N)
  - 检查 `ralph_failed` 计数
- **v3.0**:
  - 3 轮失败后检查 `ralph_failed>=3 AND confidence<40` 再进 Divergent
  - 同时运行 `trust_score_calculator` 更新信任评分

### L3: Divergent Explorer (战略探索)

- `architecture` 类型直接进入
- `execution` 类型满足条件后进入
- 输入：仅 `failed_milestone_id + error_summary`（1 行）
- 输出：3 条不同底层逻辑的路径
- 成功后：重写 WBS、更新评分、`replan_count += 1`
- 失败后：L2 Decoupled → 上报
- **v3.0**:
  - 单任务最多 1 次，超限冻结
  - 完成后检查 `mode_escalation_assessor`（如果失败触发升级）

### L2 Decoupled (降级修复)

- 只读补丁修复，不引入新方案
- 仍失败 → 上报用户

### 新增：Terminal Failure

- 分类为 `terminal`（API 不存在、许可证禁止、第三方下线）
- **立即停止**，不进入任何容错
- 标记 `blocked - terminal`
- 直接上报用户

### 新增：Rollback Strategy

三级回滚：

| 级别 | 触发条件 | 操作 |
|------|---------|------|
| **Task** | confidence_drop > 30 或 regression | `git checkout HEAD -- <files>` (撤销本任务) |
| **Milestone** | 同一里程碑连续 2 任务失败 或 confidence < 20 | 恢复 `snapshots/milestone-{N}-end/` |
| **Strategic** | StrategicMap 根本错误 或 用户请求 | 恢复上一版 StrategicMap (Plan Lineage) |

- 回滚后必须触发 `strategic-replan`
- 记录 `rollback_count`，上限 2 次
- 回滚执行前建议创建快照（如果不存在）

### 新增：Mode Escalation

在 Phase2 Evaluation 后运行：

- 检查是否需要升级（tiny→normal, normal→strategic）或降级
- 触发条件：
  - 升级：touched_files>3, replan_count>=2, architecture_issue
  - 降级：confidence_drop>50, user_requested_simplify, plan_frozen
- 每次升级计入 `replan_count`
- 每任务最多升级 1 次

## 硬熔断（v3.0）

```yaml
replan_policy:
  max_replan: 3           # 硬上限
  max_divergent: 1        # 最多一次 Divergent
  max_execution_cycles: 20 # 单任务最多执行轮次
  max_rollback: 2         # 最多两次回滚
  plan_frozen: false      # 任一超限即置 true
```

**检查点**（每次任务完成后）：

1. `replan_count >= 3` → freeze
2. `divergent_count >= 1` → freeze
3. `rollback_count >= 2` → freeze
4. `execution_cycles >= 20` → freeze

冻结后 → 立即上报用户，提供所有计数和原因。

## State Compression + Semantic Summary（v3.0）

- **Hot** (<=1500 chars, 注入): 当前任务、里程碑、最近3验证、置信度、trust_score、value_score
- **Warm** (落盘): **语义摘要**（聚合统计），不再保留原始 Heartbeat/Mutation 条目
- **Cold** (归档): 原始日志、已完成任务（>50 迁移）

Semantic Summary 每 10 次心跳或 5 次验证生成一次，包含：

- verification_summary (通过率、常见失败)
- mutation_summary (重规划次数、方向变更)
- confidence_trend
- trust_score_evolution

## 多维评分体系（v3.0）

| 维度 | 含义 | 范围 | 更新时机 |
|------|------|------|---------|
| completion | 主观完成度 | 0-100% | 每次验证 +5% |
| confidence | 主观信心 | 0-100% | 每次验证调整 |
| evidence_strength | 客观证据强度 | 0-100 | 每次验证评估 |
| trust_score | 预测准确率 | 0-100 | 每次任务完成重新计算 |
| value_score | 投入产出比 | 0-100 | Phase 0 确定，需求变更时才变 |
| risk | 剩余风险 | low/medium/high | 随 confidence 调整 |

## 关键指标（v3.0）

| 指标 | 目标 | 检查频率 | 行动 |
|------|------|---------|------|
| trust_score | > 60 | 每任务 | < 40 时增加验证频率 |
| value_score | > 40 | Phase 0 | < 40 建议重新评估需求 |
| replan_count | < 3 | 每突变 | 达到 3 冻结 |
| rollback_count | < 2 | 每回滚 | 达到 2 冻结 |
| divergent_count | < 1 | 每次探索 | 达到 1 冻结 |
| semantic_summary_ratio | > 70% compression | 每生成 | 调整 Warm 区大小 |

## 与 v2.1 的关键区别

| 维度 | v2.1 | v3.0 |
|------|------|------|
| 故障类型 | 4 类 | 5 类（新增 terminal） |
| 容错路径 | 三级 | 三级 + 立即停止（terminal） |
| 回滚能力 | 无 | 三级回滚（task/milestone/strategic） |
| 模式管理 | 静态 | 动态升级/降级 |
| 上下文压缩 | Hot/Warm/Cold | + Semantic Summary（Warm 区聚合） |
| 评分体系 | 3 维 | 5 维（+trust, value） |
| 熔断检查 | replan + divergent | + rollback + execution_cycles |
| 价值评估 | 无 | Phase 0 Value Assessor |

## 故障类型映射总结（v3.0）

| 故障类型 | 策略 | 最大重试 | 升级条件 | 目标 | terminal? |
|---------|------|---------|---------|------|-----------|
| execution | Ralph Loop | 3-5 轮 | ralph_failed>=3 AND confidence<40 | Divergent | 否 |
| environment | 请求用户 | 1 次 | 用户无响应 | Escalate | 否 |
| dependency | 重新规划 WBS | 3 次 | 3 次方案失败 | Divergent | 否 |
| architecture | Divergent (直接) | 1 次 | 失败 | L2 Decoupled → Escalate | 否 |
| **terminal** | **立即停止** | **0** | **无** | **上报用户** | **是** |

## 示例场景

### 小型任务（lean profile, tiny mode）

用户需求："修 typo"
- Phase 0: auto → tiny, S, lean
- 跳过 StrategicMap
- 单任务 WBS
- 执行 → 验证 → 完成
- 无容错、无回滚、无摘要

### 中型任务（standard, normal → strategic 升级）

用户需求："重构登录模块"
1. Phase 0: auto → normal, M, standard
2. Phase 1: 简版 StrategicMap (3 milestones)
3. 执行中第 2 个里程碑遇到架构问题，replan_count 已达 2
4. Phase 2: mode_escalation_assessor 建议升级到 strategic
5. 触发 strategic-replan，生成完整 StrategicMap（含依赖图）
6. 继续执行，最终完成
7. trust_score: 58 → 54 (略有下降)

### 大型任务（enterprise, terminal failure）

用户需求："迁移认证系统至第三方 API"
1. Phase 0: auto → strategic, XL, enterprise
2. Phase 1: 完整 StrategicMap (6 milestones, 依赖图)
3. 执行 Milestone 3 时调用第三方 API → 发现 API 已下线
4. 故障分类器: terminal (third_party_shutdown)
5. 立即停止，blocked，上报用户："API 已下线，任务无法完成"
6. 避免 20 小时无效工作

---

**相关**: `references/terminal-failure.md`, `references/rollback-strategy.md`, `references/mode-escalation.md`, `references/semantic-summary.md`, `references/trust-score.md`, `references/value-score.md`, `templates/stm-ledger.md`
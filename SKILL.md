---
name: "strategic-task-master"
description: "工业级长程任务 Agent OS。双层规划+三级容错+状态压缩+动态模式升级+回滚策略+信任评分+价值评估。v3.0"
---

# Strategic Task Master (STM) — 战略任务主控

> 融合 StrategicNavigator（StraTA 战略领航员）的认知层与 long-task-manager（LTM）的工程层，构建工业级、无坚不摧的长程任务终极方案。
>
> **核心理念**: SN 是"战略大脑"（方向偏航、死胡同探索），LTM 是"工程铁腕"（任务拆解、质量验证、持久化、重试）。两者融合 = 1 + 1 > 2。

## 核心架构（v3.0）

| 层 | 组件 | 职责 |
|----|------|------|
| 战略层 (SN) | 全局战略生成器、防偏航校验器、高维探索器、战略反馈处理器 | 做正确的事 |
| 工程层 (LTM) | WBS 台账、子代理调度、验证门禁、计划突变、Heartbeat | 正确地做事 |
| 评估层 (Eval) | 故障分类器、置信度评分、证据强度评估、状态压缩器、成本控制器 | 判断该做什么 |
| 决策层 (Decide) | 价值评估、信任评分、回滚决策、模式升级引擎 | 决定值不值得做 |

**接口契约**: 战略层输出 `StrategicMap`（JSON）→ 工程层生成 `docs/spm/ledger.md`（Markdown）。子代理通过 evidence 中的 `strategic_feedback` 向上反馈。评估层在每次验证后更新多维置信度评分。决策层在 Phase 0 和 Phase 2 输出价值评估、模式升级、回滚推荐。

## Profile Presets（配置档位 v3.0）

一键配置参数，避免参数爆炸：

| Profile | 适用场景 | adaptive_mode | cost_budget | max_replan | max_divergent | max_rollback |
|---------|---------|---------------|-------------|------------|---------------|-------------|
| **lean** | 单文件 <15min | auto | low | 2 | 0 | 1 |
| **standard** | 多文件 <2h | auto | medium | 3 | 1 | 2 |
| **enterprise** | 系统重构 >2h | auto | high | 5 | 2 | 3 |

初始化时指定：`bash scripts/init-strategic-ledger.sh "项目名" docs/spm --profile=standard`

## 自适应模式 (Adaptive Mode v3.0)

根据任务规模自动选择执行模式，并支持运行时动态升级/降级。

```yaml
adaptive_mode:
  tiny:   # <10分钟任务，单文件修改
    skip: StrategicMap
    skip: Divergent Explorer
    skip: Anti-drift monitoring
    use:  WBS (单任务) + Verification + State Compression

  normal:  # 10-60分钟任务，多文件修改
    skip: StrategicMap (可选简版)
    use:  WBS (2-5 任务) + Ralph Loop + Verification + Feedback + State Compression

  strategic:  # >1小时任务，多阶段
    use: 完整 STM: StrategicMap → WBS → Ralph Loop → Divergent → Confidence Scoring → State Compression
```

### 动态模式升级 (Mode Escalation v3.0)

任务执行过程中自动评估是否需要调整模式：

```yaml
mode_escalation:
  tiny -> normal:
    - touched_files > 3
    - estimated_time > 30 minutes
    - detected_architecture_issue

  normal -> strategic:
    - replan_count >= 2
    - touched_milestones > 1
    - confidence_plateau_detected
    - architecture_issue_severe

mode_downgrade:
  strategic -> normal:
    - confidence_drop > 50
    - user_requested_simplify
    - plan_frozen_true
```

**限制**: 每任务最多升级 1 次。降级不限制。

## 任务复杂度分级 (Task Tiering)

与 `adaptive_mode` 联动：

- **S** (tiny): <15分钟，单文件修改
- **M** (normal): <60分钟，多文件改动
- **L** (strategic): <4小时，系统重构
- **XL** (strategic): >4小时，全项目级

## 故障分类器 (Failure Classifier v3.0)

每次失败先分类，决定策略。v3.0 新增 `terminal` 类型：

| 故障类型 | 首选策略 | 升级条件 | 升级目标 | 示例 |
|---------|---------|---------|---------|------|
| **execution** | Ralph Loop A→B→C | `ralph_failed>=3 AND confidence<40` | Divergent Explorer | 语法错误、测试失败、类型错误 |
| **environment** | 请求用户介入 | 用户无响应或拒绝 | 上报用户（不重试） | 权限不足、API key 无效、网络不通 |
| **dependency** | 重新规划 WBS | 3 次方案不行 | Divergent Explorer | 依赖冲突、版本不兼容、库缺失 |
| **architecture** | Divergent Explorer（跳过 Ralph） | 探索失败 | L2 Decoupled → 上报用户 | 方向错了、设计缺陷、死胡同 |
| **terminal** | 立即停止 | 无 | 直接上报用户 | API 不存在、许可证禁止、第三方下线、法规限制 |

**terminal 故障不进入任何容错机制**，直接标记 `blocked - terminal` 并上报用户。

输出 JSON: `{failure_type, strategy, confidence_delta, reason, trust_score_delta}`

## 状态压缩 (State Compression v3.0)

防止上下文爆炸，三层分区：

- **Hot** (<=1500 chars, preToolUse 注入): 当前任务、当前里程碑、最近 3 次验证、置信度、信任评分、Strategic Context (strategic 模式)
- **Warm** (落盘不注入): 语义摘要（聚合统计）、最近 5 次 Mutation 概要
- **Cold** (归档): 已完成任务 (>50 个时迁移)、历史快照、原始日志

`inject-stm-context.py` 实现 Hot 区提取，Warm/Cold 仅保留磁盘审计，不进入上下文。

### 语义摘要 (Semantic Summary v3.0)

Warm 区不再存原始记录，而是聚合统计：

```yaml
verification_summary: { passed:20, failed:3, recurring:"auth timeout" }
mutation_summary: { replan:2, direction_changes:1 }
confidence_trend: { from:60, to:45, trend:"down" }
```

每 10 次心跳或 5 次验证生成一次摘要，Warm 区大小下降 80%+。

## 证据强度评估 (Evidence Strength)

`completion` ≠ 完成，必须有客观证据。

| 维度 | 分值 | 说明 |
|------|------|------|
| 测试输出 | 0-40 | 按测试通过率计算 |
| 运行日志 | 0-30 | 有 stdout/stderr 即 30 分 |
| 用户验证 | 0-30 | 明确确认 30 分，模糊回应 10 分 |

`evidence_strength` (0-100) 与 `completion`、`confidence` 并列。当 `evidence_strength < 30` 时，即使 `completion` 和 `confidence` 高也应警惕幻觉。

## 结构化 StrategicMap (v3.0)

固定 JSON Schema，确保跨模型一致。v3.0 新增 `value_score`、`value_assessment`、`depends_on`、`parallel_with`：

```json
{
  "adaptive_mode": "tiny|normal|strategic",
  "task_tier": "S|M|L|XL",
  "profile": "lean|standard|enterprise",
  "goal": "最终目标（一句话，≤200字）",
  "value_score": 0-100,
  "value_assessment": {
    "options_considered": 2,
    "recommended_option": "A",
    "reason": "性价比最高"
  },
  "constraints": ["约束1", "约束2"],
  "risks": [
    {"risk": "风险描述", "likelihood": "low|medium|high", "impact": "low|medium|high"}
  ],
  "milestones": [
    {
      "id": 1,
      "title": "里程碑标题",
      "description": "详细描述",
      "depends_on": [],
      "parallel_with": [],
      "success_criteria": "可验证的完成标准",
      "status": "PENDING",
      "initial_directions": ["方向1", "方向2"]
    }
  ],
  "success_criteria": ["全局验收标准1", "全局验收标准2"],
  "fallbacks": ["备用方案1", "备用方案2"],
  "anti_drift_rules": ["规则1", "规则2"],
  "replan_limit": 3,
  "cost_budget": "low|medium|high"
}
```

**里程碑依赖图**: `depends_on` 定义前置依赖，`parallel_with` 定义可并行里程碑。自动拓扑排序确定执行顺序，关键路径分析识别瓶颈，最大化并行度分配给子代理。

## 置信度评分 (Confidence Score v3.0)

五位一体评估：

- `completion` (0-100%): 主观完成度
- `confidence` (0-100%): 主观信心
- `evidence_strength` (0-100): 客观证据强度
- `trust_score` (0-100): 历史预测准确率（外部参考）
- `value_score` (0-100): 投入产出比（是否值得做）
- `risk` (low|medium|high)
- `trend` (up|flat|down)
- `last_updated`

### 信任评分 (Trust Score v3.0)

量化 Agent 预测可靠性，基于历史表现：

```python
trust_score = estimate_deviation(0-40) + failure_rate(0-30) - rollback_penalty(0-30)
```

- 预估偏差: 最近 5 任务，偏差<20% 得 40 分，20-50% 得 20 分，50-100% 得 10 分，>100% 得 0 分
- 失败率: 最近 10 任务失败率，0% 得 30 分，每 10% 扣 5 分
- 回滚惩罚: 每次回滚扣 3 分（上限 30 分）

**低 trust_score (< 40)** → 当前 confidence 不可全信，需增加验证频率。

### 价值评估 (Value Score v3.0)

评估任务性价比，避免资源浪费：

```python
value_score = impact(0-50) + effort_score(0-30) + risk_score(0-20)
```

- impact: 业务影响（minor=15, moderate=30, major=50, critical=50）
- effort_score: 基于工时，`max(0, 30 - (hours * 1.5))`
- risk_score: low=20, medium=10, high=0

**value_score < 40** → 建议重新评估需求或寻找 MVP 方案。

### 计分规则 (v3.0)

| 事件 | completion | confidence | evidence_strength | trust_score | value_score | risk | 备注 |
|------|------------|------------|-------------------|-------------|-------------|------|------|
| 验证通过 + 无回归 | +5% | +5% | 按实际评估 | +2 | 保持 | — | 正常推进 |
| 验证通过 + 有回归 | +5% | -10% | 不变 | -5 | 保持 | 升一级 | 有副作用 |
| Ralph Loop 修复 | +5% | +2% | 不变 | +1 | 保持 | — | 可信度略增 |
| Ralph Loop 3轮全败 | +0% | -15% | 不变 | -5 | 保持 | 升一级 | 需换策略 |
| Divergent 成功 | +10% | +5% | 根据新路径评估 | +2 | 保持 | 降一级 | 新路径可行 |
| 触发回滚 | +0% | -20% | 重置 | -10 | 保持 | 升两级 | 方向错误 |
| 子代理 empty/error | +0% | -20% | 不变 | -5 | 保持 | — | 严重问题 |
| 用户介入确认 | +0% | +10% | 根据用户反馈调整 | +5 | 保持 | 降一级 | 人工确认 |
| 完成所有 WBS | 100% | 累计 | 累计 | 累计 | 累计 | 累计 | 最终值 |

`evidence_strength` 不随 confidence 自动增长，必须通过实际测试/运行/用户验收提升。

## 回滚策略 (Rollback Strategy v3.0)

三级回滚可逆操作：

| 级别 | 范围 | 触发条件 | 操作 |
|------|------|---------|------|
| **Task** | 单个 WBS 任务 | confidence_drop > 30, evidence_strength_drop > 40 | 撤销本任务修改的文件 |
| **Milestone** | 整个里程碑 | 里程碑连续 2 个失败, confidence < 20 | 恢复到快照 (`snapshots/`) |
| **Strategic** | 整体战略 | StrategicMap 根本错误, user requested rollback | 恢复到上一版 StrategicMap |

**限制**: 最多回滚 2 次。回滚后必须触发 `strategic-replan`。Strategic 级回滚需要用户确认。

## 触发条件（v2.1 收紧）

Divergent Explorer 仅在同时满足以下条件时触发：

- `ralph_failed >= 3`
- `AND confidence < 40`
- `AND failure_type == 'architecture'`
- `AND plan_frozen == false`

例外：若故障明显是方向性错误（如技术选型错误），即使 `ralph_failed < 3` 也可直接触发（由 phase2_evaluation 判断）。

## 硬熔断 (Hard Replan Limit v3.0)

```yaml
replan_policy:
  max_replan: 3           # 最大重规划次数
  max_divergent: 1        # 最多一次 Divergent Explorer
  max_execution_cycles: 20 # 单任务最多执行轮次（包括重试）
  max_rollback: 2         # 最大回滚次数 (v3.0)
  plan_frozen: false
  profile: "standard"     # 由 profile 决定 (v3.0)
```

**检查点**:
- 每次 `strategic-replan` 后: `replan_count += 1`
- 每次 `divergent_exploration` 后: `divergent_count += 1`
- 每次 `rollback` 后: `rollback_count += 1`
- 任一超限 → `plan_frozen = true` → 立即上报用户

## 三级容错（v3.0 完整流程）

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
  │    ├─ architecture
  │    │     └→ (跳过 L1/L2) → L3: Divergent Explorer (直接进入)
  │    │          ├→ 成功 → 重写WBS + 更新置信度 + 检查 replan_count
  │    │          └→ 失败 → L2 Decoupled → 上报用户
  │    │
  │    └─ terminal (v3.0 新增)
  │          └→ 立即停止，标记 blocked - terminal
  │               └→ 上报用户，不进入任何容错循环
  │
  └→ 每次完成（无论成功失败）:
        - 检查是否需要回滚 (rollback_recommender, v3.0)
        - 检查是否需要模式升级 (mode_escalation, v3.0)
        - 更新 Confidence Score (completion, confidence, evidence_strength, trust_score)
        - 写入 Heartbeat Log
        - 检查 Hard Replan Limit (replan_count, divergent_count, rollback_count, execution_cycles)
        - 执行 State Compression (Hot 区保持 <=1500 chars)
        - 需要时生成 Semantic Summary (v3.0)
```

## 完整工作流

- **Phase 0**: 自适应模式判定 + 价值评估 → 选择 tiny/normal/strategic + profile + 多方案 ROI 分析
- **Phase 1** (strategic only): SN 生成结构化 StrategicMap（含里程碑依赖图）→ 用户确认 → 哈希认证
- **Phase 2**: 子代理执行 → 验证门禁 → 故障分类器 → 容错处理 → 置信度更新 + 证据强度评估 + 模式升级检查 + 回滚检查
- **Phase 3**: 7 阶段验证矩阵 → 置信度报告（含 trust_score, value_score, evidence_strength）→ Semantic Summary → Delivery Summary → 用户决策

## 铁律（v3.0）

1. **配置档位先行** — 先选 profile (lean/standard/enterprise)，再决定参数
2. **自适应先行** — 先判断任务规模，再决定投入多少规划成本
3. **验证不撒谎** — 无当次验证命令输出不能 claim 完成
4. **故障先分类** — 任何失败先归类再处理，terminal 故障立即停止
5. **容错有终止** — 重规划超过限制必须冻结，不能无限循环
6. **异步独立** — 子代理隔离执行
7. **全量留痕** — 所有突变记录到审计日志
8. **物理持久化** — 战略和 WBS 写入物理文件
9. **置信度可见** — 每次验证后必须更新五维置信度评分
10. **快照不可删除** — strategic-replan 前的快照保留到交付
11. **状态分区** — Hot/Warm/Cold 分离，上下文只注入 Hot 区
12. **证据强度** — completion 不等于完成，必须要有 evidence_strength 客观支撑
13. **硬熔断** — 触发 max_replan、max_divergent、max_rollback 或 max_execution_cycles 后立即冻结计划并上报
14. **回滚不无限** — 最多回滚 2 次，回滚后必须 replan
15. **成本意识** — 每次 Phase 0 进行价值评估，value_score < 40 时建议缩小范围

## 参考

- `templates/stm-ledger.md` — WBS 台账模板 v3.0（含 trust_score, value_score, Rollback Plan, Semantic Summary, Milestone Dependencies）
- `references/strategic-planning.md` — SN Phase 1 + 自适应模式 + 固定 Schema
- `references/anti-drift-monitoring.md` — SN Phase 2
- `references/divergent-exploration.md` — SN Phase 3（触发条件收紧）
- `references/strategic-feedback-loop.md` — 双向反馈
- `references/fault-tolerance-matrix.md` — 容错边界 + 故障分类器 + 硬熔断 + State Compression
- `references/ralph-loop.md` — 战术重试（集成故障分类器）
- `references/confidence-scoring.md` — 置信度评分系统（v3.0 含 trust_score, value_score）
- `references/state-compression.md` — 状态压缩策略
- `references/mode-escalation.md` — 动态模式升级 (v3.0)
- `references/trust-score.md` — 信任评分计算 (v3.0)
- `references/value-score.md` — 价值评估 (v3.0)
- `references/rollback-strategy.md` — 三级回滚策略 (v3.0)
- `references/terminal-failure.md` — 终端故障处理 (v3.0)
- `references/semantic-summary.md` — 语义摘要 (v3.0)
- `references/milestone-dependencies.md` — 里程碑依赖图 (v3.0)
- `workflows/three-tier-fault-tolerance.md` — 三级容错完整流程（v3.0 含 terminal 和 rollback）
- `workflows/strategic-replan-snapshot.md` — 快照回滚
- `workflows/verification-before-completion.md` — 完成前验证
- `workflows/subagent-driven-execution.md` — 子代理驱动执行
- `scripts/init-strategic-ledger.sh` — 初始化台账（支持 --profile 和 --adaptive-mode 参数）
- `scripts/inject-stm-context.py` — Hook 注入（State Compression + Semantic Summary 实现）
- `scripts/verify-stm-ledger.sh` — 完整性验证（v3.0 增强，含 profile/trust/value/rollback 检查）
- `scripts/attest-ledger.sh` — 台账哈希认证
- `presets/strategic-prompts.yaml` — Prompt 模板（含 value_assessor, mode_escalation, rollback, trust_score, semantic_summary, terminal_failure）

---

**版本**: v3.0
**许可**: MIT
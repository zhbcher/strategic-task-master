---
name: "strategic-task-master"
description: "工业级长程任务 Agent OS。双层规划+三级容错+状态压缩+动态模式升级+回滚策略+信任评分+价值评估。v3.0"
---

# Strategic Task Master (STM) — 战略任务主控

> 融合 StrategicNavigator（StraTA 战略领航员）的认知层与 long-task-manager（LTM）的工程层，构建工业级、无坚不摧的长程任务终极方案。
>
> **核心理念**: SN 是"战略大脑"（方向偏航、死胡同探索），LTM 是"工程铁腕"（任务拆解、质量验证、持久化、重试）。两者融合 = 1 + 1 > 2。

## 核心架构（v2.1）

| 层 | 组件 | 职责 |
|----|------|------|
| 战略层 (SN) | 全局战略生成器、防偏航校验器、高维探索器、战略反馈处理器 | 做正确的事 |
| 工程层 (LTM) | WBS 台账、子代理调度、验证门禁、计划突变、Heartbeat | 正确地做事 |
| 评估层 (Eval) | 故障分类器、置信度评分、证据强度评估、状态压缩器、成本控制器 | 判断该做什么 |

**接口契约**: 战略层输出 `StrategicMap`（JSON）→ 工程层生成 `docs/spm/ledger.md`（Markdown）。子代理通过 evidence 中的 `strategic_feedback` 向上反馈。评估层在每次验证后更新多维置信度评分。

## 自适应模式 (Adaptive Mode)

根据任务规模自动选择执行模式，避免"规划 > 执行"：

```yaml
adaptive_mode:
  tiny:   # <10分钟任务，单文件修改
    skip: StrategicMap
    skip: Divergent Explorer
    skip: Anti-drift monitoring
    use:  WBS (单任务) + Verification + State Compression

  normal:  # 10-60分钟任务，多文件修改
    skip: StrategicMap
    use:  WBS (2-5 任务) + Ralph Loop + Verification + Feedback + State Compression

  strategic:  # >1小时任务，多阶段
    use: 完整 STM: StrategicMap → WBS → Ralph Loop → Divergent → Confidence Scoring → State Compression
```

**判定函数**: 基于用户输入长度、涉及文件数、估算时间、是否存在架构问题自动选择。用户可在 `StrategicMap` 的 `adaptive_mode` 字段中覆写。

## 任务复杂度分级 (Task Tiering v2.1)

与 `adaptive_mode` 联动：

- **S** (tiny): <15分钟，单文件修改
- **M** (normal): <60分钟，多文件改动
- **L** (strategic): <4小时，系统重构
- **XL** (strategic): >4小时，全项目级

## 故障分类器 (Failure Classifier)

每次失败先分类，决定策略：

| 故障类型 | 首选策略 | 升级条件 | 升级目标 | 示例 |
|---------|---------|---------|---------|------|
| **execution** | Ralph Loop A→B→C | `ralph_failed>=3 AND confidence<40` | Divergent Explorer | 语法错误、测试失败、类型错误 |
| **environment** | 请求用户介入 | 用户无响应或拒绝 | 上报用户（不重试） | 权限不足、API key 无效、网络不通 |
| **dependency** | 重新规划 WBS | 3 次方案不行 | Divergent Explorer | 依赖冲突、版本不兼容、库缺失 |
| **architecture** | Divergent Explorer（跳过 Ralph） | 探索失败 | L2 Decoupled → 上报用户 | 方向错了、设计缺陷、死胡同 |

输出 JSON: `{failure_type, strategy, confidence_delta, reason}`

## 状态压缩 (State Compression v2.1)

防止上下文爆炸，三层分区：

- **Hot** (<=1500 chars, preToolUse 注入): 当前任务、当前里程碑、最近 3 次验证、置信度、Strategic Context (strategic 模式)
- **Warm** (落盘不注入): 最近 5 次 Mutation、最近 10 次 Heartbeat
- **Cold** (归档): 已完成任务 (>50 个时迁移)、历史快照

`inject-stm-context.py` 实现 Hot 区提取，Warm/Cold 仅保留磁盘审计，不进入上下文。

## 证据强度评估 (Evidence Strength v2.1)

`completion` ≠ 完成，必须有客观证据。

| 维度 | 分值 | 说明 |
|------|------|------|
| 测试输出 | 0-40 | 按测试通过率计算 |
| 运行日志 | 0-30 | 有 stdout/stderr 即 30 分 |
| 用户验证 | 0-30 | 明确确认 30 分，模糊回应 10 分 |

`evidence_strength` (0-100) 与 `completion`、`confidence` 并列。当 `evidence_strength < 30` 时，即使 `completion` 和 `confidence` 高也应警惕幻觉。

## 结构化 StrategicMap (v2.1)

固定 JSON Schema，确保跨模型一致：

```json
{
  "adaptive_mode": "tiny|normal|strategic",
  "task_tier": "S|M|L|XL",
  "goal": "最终目标（一句话，≤200字）",
  "constraints": ["约束1", "约束2"],
  "risks": [
    {"risk": "风险描述", "likelihood": "low|medium|high", "impact": "low|medium|high"}
  ],
  "milestones": [
    {
      "id": 1,
      "title": "里程碑标题",
      "description": "详细描述",
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

## 置信度评分 (Confidence Score v2.1)

三维评估：

- `completion` (0-100%): 主观完成度
- `confidence` (0-100%): 主观信心
- `evidence_strength` (0-100): 客观证据强度
- `risk` (low|medium|high)
- `trend` (up|flat|down)
- `last_updated`

**计分规则**:

| 事件 | completion | confidence | evidence_strength | 备注 |
|------|------------|------------|-------------------|------|
| 验证通过 + 无回归 | +5% | +5% | 按实际评估 | 正常推进 |
| 验证通过 + 有回归 | +5% | -10% | 不变 | 有副作用 |
| Ralph Loop 修复 | +5% | +2% | 不变 | 可信度略增 |
| Ralph Loop 3轮全败 | +0% | -15% | 不变 | 需换策略 |
| Divergent 成功 | +10% | +5% | 根据新路径评估 | 新路径可行 |
| 子代理 empty/error | +0% | -20% | 不变 | 严重问题 |
| 用户介入确认 | +0% | +10% | 根据用户反馈调整 | 人工确认 |

`evidence_strength` 不随 confidence 自动增长，必须通过实际测试/运行/用户验收提升。

## 触发条件（v2.1 收紧）

Divergent Explorer 仅在同时满足以下条件时触发：

- `ralph_failed >= 3`
- `AND confidence < 40`
- `AND failure_type == 'architecture'`
- `AND plan_frozen == false`

例外：若故障明显是方向性错误（如技术选型错误），即使 `ralph_failed < 3` 也可直接触发（由 phase2_evaluation 判断）。

## 硬熔断 (Hard Replan Limit v2.1)

```yaml
replan_policy:
  max_replan: 3           # 最大重规划次数
  max_divergent: 1        # 最多一次 Divergent Explorer
  max_execution_cycles: 20 # 单任务最多执行轮次（包括重试）
  plan_frozen: false
```

**检查点**:
- 每次 `strategic-replan` 后: `replan_count += 1`
- 每次 `divergent_exploration` 后: `divergent_count += 1`
- 任一超限 → `plan_frozen = true` → 立即上报用户

## 三级容错（v2.1 完整流程）

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
        - 检查 Hard Replan Limit (replan_count, divergent_count, execution_cycles)
        - 执行 State Compression (Hot 区保持 <=1500 chars)
```

## 完整工作流

- **Phase 0**: 自适应模式判定 → 选择 tiny/normal/strategic
- **Phase 1** (strategic only): SN 生成结构化 StrategicMap → 用户确认 → 哈希认证
- **Phase 2**: 子代理执行 → 验证门禁 → 故障分类器 → 容错处理 → 置信度更新 + 证据强度评估
- **Phase 3**: 7 阶段验证矩阵 → 置信度报告（含 evidence_strength） → Delivery Summary → 用户决策

## 铁律（v2.1）

1. **自适应先行** — 先判断任务规模，再决定投入多少规划成本
2. **验证不撒谎** — 无当次验证命令输出不能 claim 完成
3. **故障先分类** — 任何失败先归类再处理，不用错策略
4. **容错有终止** — 重规划超过 3 次必须冻结，不能无限循环
5. **异步独立** — 子代理隔离执行
6. **全量留痕** — 所有突变记录到审计日志
7. **物理持久化** — 战略和 WBS 写入物理文件
8. **置信度可见** — 每次验证后必须更新三维置信度评分
9. **快照不可删除** — strategic-replan 前的快照保留到交付
10. **状态分区** — Hot/Warm/Cold 分离，上下文只注入 Hot 区
11. **证据强度** — completion 不等于完成，必须要有 evidence_strength 客观支撑
12. **硬熔断** — 触发 max_replan、max_divergent 或 max_execution_cycles 后立即冻结计划并上报

## 参考

- `templates/stm-ledger.md` — WBS 台账模板（含 evidence_strength 列、plan_frozen、task_tier）
- `references/strategic-planning.md` — SN Phase 1 + 自适应模式 + 固定 Schema
- `references/anti-drift-monitoring.md` — SN Phase 2
- `references/divergent-exploration.md` — SN Phase 3（触发条件 v2.1 收紧）
- `references/strategic-feedback-loop.md` — 双向反馈
- `references/fault-tolerance-matrix.md` — 容错边界 + 故障分类器 + 硬熔断 + State Compression
- `references/ralph-loop.md` — 战术重试（集成故障分类器）
- `references/confidence-scoring.md` — 置信度评分系统（v2.1 含 evidence_strength）
- `references/state-compression.md` — 状态压缩策略（v2.1 核心）
- `workflows/three-tier-fault-tolerance.md` — 三级容错完整流程（v2.1）
- `workflows/strategic-replan-snapshot.md` — 快照回滚
- `workflows/verification-before-completion.md` — 完成前验证
- `scripts/init-strategic-ledger.sh` — 初始化台账（支持 3 种模式参数）
- `scripts/inject-stm-context.py` — Hook 注入（State Compression 实现）
- `scripts/verify-stm-ledger.sh` — 完整性验证（v2.1 增强）
- `presets/strategic-prompts.yaml` — Prompt 模板（含 state_compressor, evidence_strength_assessor, adaptive_mode_selector 增强, divergent_exploration 收紧）

---

**版本**: v2.1  
**许可**: MIT
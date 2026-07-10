# STM 战略任务台账 — [项目名称]

## 元数据 (Metadata)

- **自适应模式**: [tiny / normal / strategic]
- **任务分级**: [S / M / L / XL]  # 与 adaptive_mode 联动
- **成本预算**: [low / medium / high]
- **重规划计数**: [0/3]
- **计划冻结**: [false / true]  # Hard Replan Limit 触发后置为 true
- **启动时间**: {TIMESTAMP}
- **最后更新**: 

## 战略上下文 (Strategic Context)

> 由 StrategicNavigator（SN Phase 1）生成，作为本次任务的"宪法"。
> 仅 adaptive_mode=strategic 时填充。

- **最终目标 (Original Goal)**: 
- **约束**: 
- **风险**: 
- **当前里程碑**: Milestone [ID] — [title]
- **全局验收标准**: 
- **备用方案**: 
- **战略状态**: PENDING / IN_PROGRESS / COMPLETED / FAILED
- **防偏航规则**:
  1. 
  2. 
- **上次战略检查点**: 

> tiny/normal 模式下，仅保留 "最终目标" 和 "防偏航规则" 即可。

## 置信度评分 (Confidence Score)

> 每次验证后更新。包含 completion、confidence、evidence_strength 三个维度。

| 时间 | 完成度 | 置信度 | 证据强度 | 风险 | 趋势 | 备注 |
|------|--------|--------|----------|------|------|------|
| | 0% | 0% | 0 | medium | flat | 初始状态 |

### 证据强度评估维度

| 维度 | 分值 | 说明 |
|------|------|------|
| 有测试输出 | 0-40 | 测试命令执行成功，结果明确 |
| 有运行日志 | 0-30 | 程序实际运行过，有 stdout/stderr |
| 有用户验证 | 0-30 | 用户手动检查通过或确认 |
| **总分** | **0-100** | 三项相加，反映客观完成度 |

### 评分规则

- 验证通过 + 无回归 → completion +5%, confidence +5%, evidence_strength 根据实际评估
- 验证通过 + 有回归 → completion +5%, confidence -10%, evidence_strength 不变
- Ralph Loop 修复 → completion +5%, confidence +2%
- Divergent 探索 → completion +0%, confidence +0%
- 连续 3 次 confidence 无提升 → 触发终止条件

### 与 Completion 的区别

- **completion**: 我认为完成了多少（主观）
- **confidence**: 我对完成度的信心（主观）
- **evidence_strength**: 我有多少客观证据证明（客观）

> 当 evidence_strength < 30 时，即使 confidence 高也应警惕幻觉。

## 共享上下文 (Shared Context)

> 所有任务的共同背景。

- **项目类型**: 
- **代码规范**: 
- **技术前提**: 
- **已知架构决策**: 
- **外部依赖**: 

## WBS 任务分解

| ID | 任务名称 | 依赖 | Milestone | Context Brief | Exit Criteria | Evidence | Status | 置信度 | Strategic Feedback |
|----|---------|------|-----------|--------------|---------------|----------|--------|--------|-------------------|
| 1  | | - | 1 | | | | todo | - | - |

### 允许的状态

| 状态 | 含义 |
|------|------|
| `todo` | 未开始 |
| `doing` | 执行中 |
| `done` | 已完成（必须有 evidence） |
| `blocked` | 阻塞（必须说明原因） |
| `skipped` | 跳过（必须说明原因） |

## 计划变更记录 (Mutation Log)

> 铁律: 所有计划变更必须记录，不删除原任务行（用 skipped 标记）。

| 时间 | 变更类型 | 影响任务 | 原因 | 新任务 |
|------|---------|---------|------|--------|
| | | | | |

### 允许的突变类型

| 类型 | 说明 |
|------|------|
| **split** | 拆分任务为更小单元 |
| **insert** | 在已有任务之间插入新任务 |
| **skip** | 跳过不需要的任务 |
| **reorder** | 重排任务顺序 |
| **abandon** | 废弃任务（方向错误） |
| **strategic-replan** | 战略层面重规划（影响全表） |
| **rollback** | 回滚到前一次 strategic-replan 之前的战略 |
| **confidence-update** | 置信度评分更新（非必须记录） |

## 战略变更记录 (Strategic Mutation Log)

> 只有 Strategic Replanning 或 Rollback 才会触发此日志。

| 时间 | 变更类型 | 原战略 | 新战略 | 原因 | replan计数 |
|------|---------|--------|--------|------|-----------|
| | | | | | 1/3 |

### 重规划终止条件

- 最大重规划次数: 3
- 超过后: 冻结计划，上报用户
- 用户确认后才可继续

## 当前执行状态 (Active State)

- **自适应模式**: 
- **任务分级**: 
- **当前任务**: 
- **最后完成**: 
- **最后检查点**: 
- **从此处恢复**: 
- **当前阻塞**: 
- **置信度**: 0% / 0% / 0
- **计划冻结**: false
- **Previous attempt saved**: 

## 心跳日志 (Heartbeat Log)

> 每个子任务完成后更新。（Warm 区：落盘但不注入上下文）

| 时间 | 活跃任务 | 已完成 | 证据 | 置信度 | 恢复点 |
|------|---------|--------|------|--------|--------|
| | | | | | |

## 交付总结 (Delivery Summary)

- **已完成工作**: 
- **最终置信度**: 
- **证据强度**: 
- **证据包**: 
- **战略变更记录**: 
- **剩余阻塞/跳过**: 
- **残留风险**: 
- **计划冻结**: 
- **战略债**:
- **最终交接说明**:
# Rollback Strategy — 分级回滚策略 (v3.0)

## 问题

当任务执行中发现方向错误或严重 regression，仅 `replan` 不够，因为代码/配置已被污染，需要**回到上一个已知良好状态**。

## 三级回滚

| 级别 | 范围 | 触发条件 | 操作 |
|------|------|---------|------|
| **Task** | 单个 WBS 任务 | confidence_drop > 30, evidence_strength_drop > 40 | 撤销本任务修改的文件（git checkout HEAD -- <files>） |
| **Milestone** | 整个里程碑 | milestones 连续 2 个失败, confidence < 20 | 恢复到此里程碑开始前的快照（`snapshots/` 目录） |
| **Strategic** | 整体战略 | StrategicMap 被证明根本错误, user requested rollback | 恢复到上一版本 StrategicMap（Plan Lineage） |

## 触发条件（在 Phase 2 Evaluation 中判断）

```yaml
if confidence_delta < -20:
  recommend: rollback_to: "last_task_snapshot"

if regression_detected (verification passed but evidence shows breakage):
  recommend: rollback_to: "pre_change_state"

if strategic_feedback indicates fundamental flaw:
  recommend: rollback_to: "previous_strategic_map"
```

## 实施步骤

1. **Snapshot 策略**（已有）
   - 每次 `strategic-replan` 前自动创建快照到 `snapshots/`
   - 快照包含：WBS ledger, StrategicMap, 关键文件哈希

2. **Rollback 命令**
   ```bash
   # Task 级
   scripts/rollback-task.sh <task_id>
   # Milestone 级
   scripts/rollback-milestone.sh <milestone_id>
   # Strategic 级
   scripts/rollback-strategic.sh <strategic_map_version>
   ```

3. **集成到 LTM**
   - 当 `phase2_evaluation` 输出 `rollback_recommendation` 时，LTM 执行对应回滚
   - 回滚后更新 WBS：blocked 任务标记原因，并重新规划
   - 记录到 `Mutation Log`，类型为 `rollback`

## 与 Replan 的区别

- **Replan**: 往前走，调整计划方向
- **Rollback**: 先退回到安全点，再重新规划

## 限制

- 最多回滚次数：2 次（防止无限循环）
- 回滚后必须触发 `strategic-replan`（不能继续原计划）
- Strategic 级回滚需要用户确认

## 示例

```
执行 Milestone 2 的任务
↓
测试通过但引入回归（原有功能损坏）
↓
Phase2 检测到 regression
↓
触发 Milestone 级回滚
↓
恢复快照 snapshots/milestone-1-end/
↓
重新规划 Milestone 2 的实现方案
```

---

**相关**: `templates/stm-ledger.md` (Rollback Plan 列), `workflows/three-tier-fault-tolerance.md`
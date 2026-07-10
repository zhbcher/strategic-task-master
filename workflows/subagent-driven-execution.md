# Subagent-Driven Execution — 子代理驱动执行

> 继承自 long-task-manager。每个 WBS 任务派发一个独立子代理。

## STM 增强

与原 LTM 相比，STM 版本新增：

1. **战略上下文注入**: 子代理 prompt 中包含当前 Milestone 目标 + anti_drift_rules
2. **Phase 2 评估嵌入**: 子代理 prompt 末尾注入 [EVALUATION] 指令
3. **Strategic Feedback 采集**: 子代理输出中检测是否包含 Strategic Feedback

## 执行流程

```
FOR each task in WBS ledger (in dependency order):
  1. 读取任务: ID, Context Brief, exit_criteria, milestone_id, anti_drift_ref
  2. 读取 Strategic Context (从 WBS 台账顶部)
  3. 更新 WBS: status = doing
  4. 记录 Heartbeat: Active = Task ID
  5. 构建 dispatch prompt:
     - Strategic Context (Milestone 目标 + anti_drift_rules)
     - Context Brief (冷启动)
     - Task Description
     - Exit Criteria
     - Phase 2 [EVALUATION] 指令 (要求输出 STATUS 标记)
     - Strategic Feedback 格式说明 (可选)
  6. Dispatch 子代理:
     sessions_spawn(task=prompt, model=get_model_for_tier(model_tier))
  7. 等待返回
  8. 从子代理输出提取:
     - [STATUS: PROCEED/DRIFT/BLOCKED] 标记
     - 验证命令输出
     - (可选) Strategic Feedback
  9. 进入验证门禁 (verification-before-completion)
  10. 进入防偏航检查 (anti-drift-monitoring)
  11. 扫描 Strategic Feedback
  12. 更新 WBS + Heartbeat
```

## 子代理 Prompt 模板

```
## Strategic Context
{当前 milestone 目标 + original_goal + anti_drift_rules}

## Context Brief (冷启动)
{task.context_brief}

## Task Description
{task.description}

## Exit Criteria
{task.exit_criteria}

## Phase 2 Evaluation (必须在回复末尾输出)
请在完成操作后，评估上一步的执行结果，输出以下标记之一:
- [STATUS: PROCEED] — 符合预期
- [STATUS: DRIFT] — 偏离目标
- [STATUS: BLOCKED] — 当前路径已失效
```

## Model Tier 路由

参考 `references/fault-tolerance-matrix.md` 的 Model Fallback 规则。

## Heartbeat 记录

| Time | Active | Completed | Evidence | Resume Point |
|------|--------|-----------|----------|-------------|
| HH:MM | Task 3 (standard) | Task 2 | 8/8 pass | Task 3 subagent |
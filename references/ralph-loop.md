# Ralph Loop — 战术重试

> 继承自 long-task-manager。验证失败时自动重试，最多 3 轮，每轮必须换策略。

## 触发条件

- Phase 2 验证门禁任一检查失败
- 子代理返回 `DONE_WITH_CONCERNS`
- WBS 任务 `status=done` 但 evidence 显示有 regression

## 核心规则

**最多循环 3 轮。** 3 轮后仍失败 → 进入 L3 Divergent Explorer（不直接上报用户）。

**每轮必须改变策略。**

## 策略选择

| 失败类型 | 推荐策略 | 说明 |
|---------|---------|------|
| 编译/语法错误 | Strategy A | 直接定位报错行，精准修复 |
| 测试失败（单一） | Strategy A | 修代码，让该测试通过 |
| 测试失败（多个） | Strategy C | 可能要大改，拆分成小任务 |
| 覆盖率不足 | Strategy B | 回滚到上一版本，换测试策略 |
| 架构性错误 | **不进 Ralph Loop** | 直接进入 L3 Divergent Explorer |

## 执行流程

```
FOR each failed task (max 3 rounds):
  1. 读取失败原因
  2. 选择新策略（不可与上一轮相同）
  3. 派发修复子代理（含失败上下文 + 策略说明）
  4. 子代理完成后重新验证
  5. 验证通过 → 标记 done + evidence
  6. 验证仍失败 → 轮次+1

IF 3 轮后仍失败:
  → 输入 L3: Divergent Explorer
  → 只传: failed_milestone_id + error_summary（1 行）
```

## STM 增强点

与原 LTM 相比，STM 中的 Ralph Loop 有以下增强：

1. **出口变化**: 3 轮失败后不直接上报用户，而是进入 L3 Divergent Explorer
2. **策略感知**: 修复子代理的 prompt 中包含 strategic_context（当前 Milestone 目标 + anti_drift_rules）
3. **反馈采集**: 修复成功后检查子代理输出中是否有 Strategic Feedback

## 记录

每次 Ralph Loop 尝试记录到 Mutation Log：

| 时间 | 变更类型 | 影响任务 | 原因 | 新任务 |
|------|---------|---------|------|--------|
| HH:MM | ralph-retry-1 | 3 | Test failed: expected 200 got 500 | 3 (Strategy A) |
| HH:MM | ralph-retry-2 | 3 | Still failing | 3 (Strategy B) |
| HH:MM | ralph-retry-3 | 3 | Still failing → Divergent | 3 (Strategy C) |
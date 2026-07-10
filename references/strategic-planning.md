# Strategic Planning — 全局战略规划 (SN Phase 1)

## 概述

接收用户复杂任务，输出结构化 JSON StrategicMap。这是 STM 的起点——所有后续工作都基于此地图。

## 触发时机

- 收到用户长程任务请求（满足 AGENTS.md 长任务触发条件）
- 收到 `strategic-replan` 突变（在 L3 Divergent Explorer 之后）

## 执行流程

```
1. 读用户 Prompt
2. 注入 Phase 1 [STRATEGY_MAP] System Prompt（见 presets/strategic-prompts.yaml）
3. LLM 输出 JSON 格式 StrategicMap
4. 校验 JSON 合法性（至少 1 个 milestone + 1 条 anti_drift_rule）
5. 写入 WBS 台账的 Strategic Context 区块
6. 用户确认
7. 执行 Hash Attestation
```

## 输出契约

```json
{
  "task_id": "uuid-v4",
  "original_goal": "一句话总结用户的最终核心诉求",
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
  "current_milestone_id": 1,
  "anti_drift_rules": [
    "规则1: 禁止在...之前...",
    "规则2: 如果...超过X次则..."
  ]
}
```

## 校验规则

- `original_goal`: 不能为空，不超过 200 字
- `milestones`: 至少 1 个，最多 8 个
- `success_criteria`: 必须可验证（避免"已完成""处理好"等模糊词）
- `anti_drift_rules`: 至少 1 条，最多 10 条
- `current_milestone_id`: 必须存在于 milestones 数组中

## 与 LTM 的协作

- 输出直接写入 `docs/spm/ledger.md` 的 `## 战略上下文` 区块
- 每个 milestone 后续由 LTM 的 WBS 扩展机制展开为子任务列表

## 铁律

- Phase 1 未完成前，禁止进入任何执行操作
- StrategicMap 必须物理持久化（不依赖 LLM 上下文）
- 每次修改必须先快照再写入
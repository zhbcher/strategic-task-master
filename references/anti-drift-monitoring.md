# Anti-Drift Monitoring — 防偏航监控 (SN Phase 2)

## 概述

每步 Action 后评估结果是否符合里程碑预期。防止 Agent 在海量上下文中偏离初始目标。

## 触发时机

- 每种子代理执行完成后
- 每次 Todo Enforcement 阶段
- 每次 Strategic Feedback 非空时

## 执行流程

```
1. 读取 StrategicMap (从 WBS 台账 Strategic Context 区块)
2. 读取当前任务的 exit_criteria + evidence
3. 执行防偏航判断：
   a) 本次执行是否推进了里程碑进度？
   b) 是否产生了无关的副作用/偏离了 original_goal？
   c) 是否陷入了重复循环（连续 X 步无实质进展）？
4. 输出评估状态
```

## 输出状态

| 状态 | 含义 | 下一步 |
|------|------|--------|
| `PROCEED` | 符合预期，推进到下一步 | 正常继续 |
| `DRIFT` | 发生偏航 | 强制拉回主线，输出纠偏指令 |
| `BLOCKED` | 当前路径彻底失效 | 触发 Phase 3 Divergent Explorer |

## 纠偏策略

**DRIFT 时**:
- 输出指令格式: `CORRECT: [任务ID] 偏离点: [具体描述] 拉回: [纠正动作]`
- 子代理收到纠偏指令后，重新执行
- 如果连续 2 次 DRIFT → 自动升级为 BLOCKED

## 注入方式

由于 OpenClaw 不支持 `postToolUse` Hook，Phase 2 采用两种替代方案：

**方案 A (子代理 prompt 嵌入)**:
- 每次 sessions_spawn 时，在 prompt 末尾注入 Phase 2 评估指令
- 子代理返回输出 `[STATUS: PROCEED/DRIFT/BLOCKED]`
- 主 Agent 从输出中提取标记

**方案 B (主 Agent 执行)**:
- 子代理返回后，主 Agent 读取 StrategicMap
- 手动执行防偏航检查
- 适用于 inline 执行
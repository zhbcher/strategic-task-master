# Strategic Planning — 全局战略规划 (SN Phase 1)

## 概述

接收用户复杂任务，输出结构化 JSON StrategicMap。这是 STM 的起点——所有后续工作都基于此地图。

**关键变化 v2**: 增加了自适应模式，小型任务跳过此阶段。

## 触发时机

- adaptive_mode 为 `strategic` 时触发
- 收到 `strategic-replan` 突变（在 L3 Divergent Explorer 之后）
- 用户明确要求完整 STM 规划

## 自适应模式判定

在进入 Phase 1 之前，先判定任务规模：

```yaml
评估维度:
  - 用户输入长度
  - 涉及文件数
  - 估算执行时间
  - 用户是否明确要求"完整规划"

判定规则:
  单文件 + <10分钟 + 未要求完整规划
    → adaptive_mode: tiny
    → 跳过 Phase 1，直接进 Phase 2（单任务 WBS）

  多文件 + 10-60分钟
    → adaptive_mode: normal
    → 跳过 Phase 1，使用简版 WBS

  多阶段 + >1小时 + 架构性问题
    → adaptive_mode: strategic
    → 走完整 Phase 1 - Phase 3
```

用户可在 StrategicMap 的 `adaptive_mode` 字段中覆写此判定。

## 执行流程

```
1. 读用户 Prompt
2. 判定 adaptive_mode → 若不是 strategic，跳过此阶段
3. 注入 Phase 1 [STRATEGY_MAP] System Prompt（见 presets/strategic-prompts.yaml）
4. LLM 输出结构化 JSON StrategicMap（固定 Schema）
5. 校验 JSON 合法性
6. 写入 WBS 台账的 Strategic Context 区块
7. 用户确认
8. 执行 Hash Attestation
```

## 输出契约（固定 Schema）

```json
{
  "adaptive_mode": "tiny|normal|strategic",
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
  "anti_drift_rules": ["规则1：禁止在完成X之前做Y", "规则2：如果某方案失败超过3次则换方向"],
  "replan_limit": 3,
  "cost_budget": "low|medium|high"
}
```

### 字段规则

| 字段 | 必填 | 约束 |
|------|------|------|
| `adaptive_mode` | 是 | tiny/normal/strategic 三选一 |
| `goal` | 是 | 不超过 200 字，必须可验证 |
| `constraints` | 否 | 最多 10 条 |
| `risks` | 否 | 每条必须含 risk/likelihood/impact |
| `milestones` | 是 | 至少 1 个，最多 8 个 |
| `success_criteria` | 是 | 至少 1 条，必须可验证 |
| `fallbacks` | 否 | 最多 3 条 |
| `anti_drift_rules` | 是 | 至少 1 条，最多 10 条 |
| `replan_limit` | 否 | 默认 3 |
| `cost_budget` | 是 | low/medium/high 三选一，默认 medium |

## 重规划终止条件

```yaml
replan_limit: 3    # 固定值，StrategicMap 的 replan_limit 字段可覆盖

if exceeded:
  - freeze_plan: true
  - action: 上报用户，提供当前 WBS 状态和完整重规划记录
  - recover: 用户确认后继续
```

## 校验规则

- JSON Schema 校验所有必填字段
- `milestones` 中不能有空 `success_criteria`
- `anti_drift_rules` 必须具体可执行（禁止"保持专注"这类模糊规则）
- `replan_limit` 不能超过 10
- `cost_budget` 值不在三选一内时报错

## 与 LTM 的协作

- 输出直接写入 `docs/spm/ledger.md` 的 `## 战略上下文` 区块
- 每个 milestone 后续由 LTM 的 WBS 扩展机制展开为子任务列表
- 每次 replan 更新 `replan_count` 计数器

## 铁律

- adaptive_mode 不为 strategic 时，禁止进入 Phase 1
- Phase 1 未完成前，禁止进入任何执行操作
- StrategicMap 必须物理持久化（不依赖 LLM 上下文）
- 每次修改必须先快照再写入
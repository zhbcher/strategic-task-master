# Divergent Explorer — 高维探索 (v2.1)

## 触发条件（v2.1 收紧版）

Divergent Explorer 不再轻易触发。满足 **全部** 条件才启动：

| 条件 | 要求 | 说明 |
|------|------|------|
| `ralph_failed` | >= 3 | Ralph Loop 已失败 3 轮 |
| `confidence` | < 40 | 信心已跌至低位 |
| `failure_type` | `architecture` | 故障分类器判定为架构级问题 |
| `plan_frozen` | `false` | 重规划未冻结 |

**例外**: 如果 `failure_type == 'architecture'` 且故障明显是方向性错误（如技术选型错误），即使 `ralph_failed < 3` 也可直接触发（由 phase2_evaluation 判断）。

## 输入规范

- **仅提供**: `failed_milestone_id` + `error_summary`（1 行摘要）
- **不传**: 具体实现细节、代码文件、完整错误堆栈

```
Input:
{
  "failed_milestone_id": 3,
  "error_summary": "架构设计无法满足性能要求：当前方案预估 QPS < 100，需求是 QPS > 1000"
}
```

## 输出要求

输出 3 条备选路径，每条包含：

```json
{
  "path_title": "路径标题",
  "底层逻辑": "与当前路径完全不同的技术方向",
  "预期风险": ["风险1", "风险2"],
  "可信度": 1-10,
  "理由": "为什么这个方向可能成功"
}
```

**底层逻辑必须不同**（如：调用 API → 网页抓取；精确计算 → 模糊估算；自建 → 调用外部服务）。

## 输出后处理

- 成功 → 重写 WBS → 更新置信度
- 失败 → L2 Decoupled（降级只读修复）
- L2 仍失败 → 上报用户

## 与 State Compression 的协作

Divergent 探索期间：
- 输入只取 Hot 区内容（当前任务 + 最近验证）
- Warm/Cold 区不参与决策（避免历史噪音）

## 频率控制

| 统计 | 预期比例 |
|------|---------|
| 所有故障中进入 Divergent 的比例 | < 5% |
| 单任务最多触发次数 | 1 |
| 重规划后再次触发的惩罚 | 立即冻结并上报 |

## 与 Replan Limit 的关系

- 每次 Divergent 探索计入 `replan_count`
- 如果 `divergent_count >= 1` 后再需 Divergent → 直接冻结
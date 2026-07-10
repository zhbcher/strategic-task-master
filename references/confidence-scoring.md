# Confidence Scoring — 置信度评分系统

## 概述

每次验证后更新，跟踪任务完成的可信度。解决 Agent"看起来快完成，实际上还有大坑"的问题。

## 评分结构

```yaml
confidence_score:
  completion: 0-100%    # 任务完成度
  confidence: 0-100%    # 完成可信度（低 = 可能还有坑）
  risk: "low|medium|high"  # 剩余风险
  trend: "up|flat|down"    # 置信度趋势
  last_updated: "ISO-8601"
```

## 计分规则

| 事件 | completion 变化 | confidence 变化 | risk | 备注 |
|------|----------------|----------------|------|------|
| 验证通过 + 无回归 | +5% | +5% | — | 正常推进 |
| 验证通过 + 有回归 | +5% | -10% | 升一级 | 虽然完成了但可能有副作用 |
| Ralph Loop 修复 | +5% | +2% | — | 重试后修复，可信度略增 |
| Ralph Loop 3轮全败 | +0% | -15% | 升一级 | 需要换策略 |
| Divergent 探索 | +0% | +0% | 设为 high | 探索阶段，不确定性最高 |
| Divergent 成功 | +10% | +5% | 降一级 | 新路径可行 |
| 子代理返回 empty/error | +0% | -20% | 升两级 | 严重问题 |
| 用户介入确认 | +0% | +10% | 降一级 | 人工确认增加可信度 |
| 完成所有 WBS 任务 | 100% | 按累计值 | 按累计值 | 最终值 |

## 趋势计算

```python
def calculate_trend(scores: list) -> str:
    """
    scores: 最近 3 次 confidence 值列表 [c1, c2, c3]
    返回: 'up' | 'flat' | 'down'
    """
    if len(scores) < 2:
        return 'flat'

    slope = scores[-1] - scores[0]
    if slope > 5:
        return 'up'
    elif slope < -5:
        return 'down'
    else:
        return 'flat'
```

## 终止条件

```yaml
# 连续 3 次 confidence 无提升且 completion < 80%
confidence_plateau:
  check: 连续 3 次 update, trend == 'flat' 且 completion < 80%
  action: 触发 replan_limit 终止条件

# confidence 连续下降
confidence_downward:
  check: 连续 3 次 update, trend == 'down'
  action: 上报用户，请求介入
```

## 记录位置

- 每次更新写入 `stm-ledger.md` 的 `## 置信度评分` 表格
- 可选写入 `Mutation Log` 的 `confidence-update` 行
- 最终交付总结中包含最终置信度

## 与其它组件的协作

| 组件 | 交互方式 |
|------|---------|
| 验证门禁 | 验证完成后触发置信度更新 |
| Ralph Loop | 每轮完成后更新（+2%） |
| Divergent Explorer | 探索完成后更新（+0%，但影响 completion） |
| Replan Limit | confidence_plateau 触发终止条件 |
| 交付总结 | 最终置信度作为交付质量指标之一 |
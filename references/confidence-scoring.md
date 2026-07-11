# Confidence Scoring — 置信度评分系统 (v2.1)

## 概述

每次验证后更新，跟踪任务完成的可信度。解决 Agent"看起来快完成，实际上还有大坑"的问题。

**v2.1 新增**: evidence_strength 维度，强制区分解"我认为完成"和"我证明完成"。

## 评分结构

```yaml
confidence_score:
  completion: 0-100%      # 任务完成度（主观）
  confidence: 0-100%      # 完成可信度（主观信心）
  evidence_strength: 0-100  # 证据强度（客观）
  risk: "low|medium|high"   # 剩余风险
  trend: "up|flat|down"     # 置信度趋势
  last_updated: "ISO-8601"
```

## 证据强度评估维度

| 维度 | 分值 | 说明 |
|------|------|------|
| 有测试输出 | 0-40 | 测试命令执行成功，结果明确（通过率） |
| 有运行日志 | 0-30 | 程序实际运行过，有 stdout/stderr |
| 有用户验证 | 0-30 | 用户手动检查通过或明确确认 |
| **总分** | **0-100** | 三项相加，反映客观完成度 |

**评分逻辑**:
- 有测试但通过率<80% → 测试得分 = 通过率 * 40
- 有运行日志（任何输出）→ 30 分，无 → 0 分
- 用户说"好了"、"pass" → 30 分；模糊回应"应该可以" → 10 分；无反馈 → 0 分

## 计分规则

| 事件 | completion 变化 | confidence 变化 | evidence_strength 变化 | risk | 备注 |
|------|----------------|----------------|---------------------|------|------|
| 验证通过 + 无回归 | +5% | +5% | 按实际评估 | — | 正常推进 |
| 验证通过 + 有回归 | +5% | -10% | 不变 | 升一级 | 虽然完成了但可能有副作用 |
| Ralph Loop 修复 | +5% | +2% | 不变 | — | 重试后修复，可信度略增 |
| Ralph Loop 3轮全败 | +0% | -15% | 不变 | 升一级 | 需要换策略 |
| Divergent 探索 | +0% | +0% | 不变 | 设为 high | 探索阶段，不确定性最高 |
| Divergent 成功 | +10% | +5% | 根据新路径评估 | 降一级 | 新路径可行 |
| 子代理返回 empty/error | +0% | -20% | 不变 | 升两级 | 严重问题 |
| 用户介入确认 | +0% | +10% | 根据用户反馈调整 | 降一级 | 人工确认增加可信度 |
| 完成所有 WBS 任务 | 100% | 按累计值 | 按累计值 | 按累计值 | 最终值 |

## 关键区别

| 指标 | 含义 | 来源 | 可操纵性 |
|------|------|------|---------|
| **completion** | 我认为完成了多少 | LLM 主观评估 | 高（容易高估） |
| **confidence** | 我对完成度的信心 | LLM 主观信心 | 中 |
| **evidence_strength** | 我有多少客观证据证明 | 验证输出客观评估 | 低（必须有实际测试/运行/用户反馈） |

**v2.1 核心**: 即使 `completion=90%, confidence=85%`，如果 `evidence_strength=25`，也应该警惕幻觉。

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

## 与 State Compression 的协作

- **Hot zone**: latest confidence score + evidence_strength
- **Warm zone**: recent confidence updates (last 5 entries)
- **Cold zone**: historical confidence trends (archived)

## 记录位置

- 每次更新写入 `stm-ledger.md` 的 `## 置信度评分` 表格
- 可选写入 `Mutation Log` 的 `confidence-update` 行
- 最终交付总结中包含最终置信度和证据强度

## 与其它组件的协作

| 组件 | 交互方式 |
|------|---------|
| 验证门禁 | 验证完成后触发 confidence_score_update，同时调用 evidence_strength_assessor |
| Ralph Loop | 每轮完成后更新（+2% confidence） |
| Divergent Explorer | 探索完成后更新（+0% confidence，但 completion 可能跳变） |
| Replan Limit | confidence_plateau 触发终止条件 |
| 交付总结 | 最终置信度和 evidence_strength 作为交付质量双重指标 |
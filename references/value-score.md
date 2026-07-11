# Value Score — 投入产出评估 (v3.0)

## 问题

STM 目前只关注"能不能完成"，不关心"值不值得完成"。

Agent 可能会选择：

- 方案 A: 2 小时，风险低，收益提升 5%
- 方案 B: 20 小时，风险高，收益提升 5%

盲目执行 B，造成资源浪费。

## 评估维度

```yaml
value_score: 0-100

components:
  impact: 0-50      # 业务影响
  effort: 0-30      # 预计工时（反向）
  risk: 0-20        # 失败风险（反向）
```

### Impact（影响）

- 评估业务价值提升程度
- 来源：
  - 用户明确说明（如"这个 bug 导致每日损失 10 万"）
  - 领域知识（如"认证模块重构可提升安全性 30%"）
  - 默认假设：所有需求 impact=25（未知情况下中性）

### Effort（投入）

- 基于 `task_tier` 和 WBS 任务数估算
- 评分 = `min(30, 30 - (estimated_hours * 2))`
- 示例：
  - 预估 2 小时 → 30 - 4 = 26 分
  - 预估 20 小时 → 30 - 40 = 0 分（封顶 0）

### Risk（风险）

- 基于 `risk` 评估（low/medium/high）和 `confidence` 水平
- 评分：
  - low risk & confidence>70 → 20 分
  - medium risk & confidence~50 → 10 分
  - high risk & confidence<30 → 0 分

## 计算公式

```python
def calculate_value_score(impact, effort_score, risk_score):
    return impact + effort_score + risk_score
```

## 使用时机

在 **Phase 0: Adaptive Mode & Value Assessment** 阶段：

1. 用户提交需求
2. `value_assessor` 分析多个潜在方案（如果存在）
3. 输出：

```json
{
  "options": [
    {
      "description": "方案 A: 最小改动",
      "impact": 20,
      "effort": "2h",
      "risk": "low",
      "value_score": 64
    },
    {
      "description": "方案 B: 全面重构",
      "impact": 30,
      "effort": "20h",
      "risk": "high",
      "value_score": 42
    }
  ],
  "recommendation": "方案 A 性价比更高，建议优先执行"
}
```

4. 用户确认方案或调整

## 集成到 StrategicMap

StrategicMap 增加顶层字段：

```json
{
  "goal": "...",
  "value_score": 64,
  "value_assessment": {
    "options_considered": 2,
    "recommended_option": "方案 A"
  },
  ...
}
```

## 决策辅助

- 如果 `value_score < 40`，建议：
  - 与用户重新确认需求必要性
  - 寻找更小范围的 MVP 方案
  - 考虑暂缓或取消

- 如果多个方案相近，优先选 `effort` 小的

## 示例

```
需求: "把所有错误日志发邮件通知"
方案 A: 用 sendmail (2h, risk=low) → value_score=61
方案 B: 接入第三方告警平台 (8h, risk=medium) → value_score=58

推荐方案 A（简单有效）
```

---

**相关**: `presets/strategic-prompts.yaml` (value_assessor prompt), `SKILL.md` (workflow)
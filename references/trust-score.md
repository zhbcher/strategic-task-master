# Trust Score — Agent 预测准确率评分 (v3.0)

## 问题

Agent 经常过度乐观：

- 预估 30 分钟，实际 3 小时
- 预估 90% 完成，实际还有大量未验证工作

系统需要量化 **"这个 Agent 的自评是否可信"**。

## 评分维度

```yaml
trust_score: 0-100

based_on:
  estimate_deviation: 0-40    # 时间预估偏差
  failure_rate: 0-30          # 历史失败率
  rollback_count: 0-30        # 回滚次数
```

### 1. Estimate Deviation（预估偏差）

- 每个任务记录 `estimated_minutes` 和 `actual_minutes`
- 偏差率 = `|actual - estimated| / estimated`
- 评分：
  - 偏差 < 20% → 40 分
  - 偏差 20-50% → 20 分
  - 偏差 50-100% → 10 分
  - 偏差 > 100% → 0 分
- 取最近 5 个已完成任务的平均值

### 2. Failure Rate（失败率）

- 计算最近 10 个任务中 `status=blocked` 或 `status=failed` 的比例
- 评分 = `(1 - failure_rate) * 30`
- 示例：失败率 30% → (1-0.3)*30 = 21 分

### 3. Rollback Count（回滚次数）

- 统计最近 10 个任务中触发的 `rollback` 次数
- 每次回滚扣 3 分，上限扣 30 分
- 示例：回滚 5 次 → 扣 15 分

## 计算示例

```
最近5任务预估偏差: [10%, 30%, 80%, 5%, 50%] → 平均 35% → 得分: 15/40
最近10任务失败率: 3/10 = 30% → 得分: 21/30
最近10任务回滚: 4次 → 扣 12/30 → 得分: 18/30

Total trust_score = 15 + 21 + 18 = 54/100
```

## 使用场景

- **Confidence vs Trust**:
  - `confidence=90%` (Agent 自评)
  - `trust_score=54%` (历史表现)
  - → 系统警示：不要盲目相信当前信心

- **决策辅助**:
  - 如果 `trust_score < 40`，建议：
    - 增加验证频率
    - 缩短任务粒度
    - 引入人工检查点

- **用户界面**:
  - Delivery Summary 中显示 `Agent 可信度: 54/100`
  - 低分时提示："该 Agent 预测偏差较大，建议谨慎交付"

## 记录位置

- 在 `## 置信度评分` 表格中新增 `trust_score` 列
- 在 `## 交付总结` 中显示最终 trust_score

## 更新频率

- 每次任务完成后重新计算
- 使用滑动窗口（最近 5-10 个任务）

## 与其它指标的关系

| 指标 | 关系 | 说明 |
|------|------|------|
| confidence | 独立 | 当前任务的信心，不直接受 trust_score 影响 |
| evidence_strength | 负相关 | trust_score 低时，evidence_strength 可能也偏低 |
| completion | 无直接关系 | 完成度高但 trust_score 低 → 可能是侥幸完成 |

---

**相关**: `templates/stm-ledger.md`, `scripts/verify-stm-ledger.sh`
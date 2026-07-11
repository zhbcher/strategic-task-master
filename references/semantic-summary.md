# Semantic Summary — 语义摘要层 (v3.0)

## 问题

当前 State Compression 的 Warm 区仍保存大量原始记录：

- 最近 10 次 Heartbeat
- 最近 5 次 Mutation

这些记录过于详细，**信息密度低**。对于长期运行的任务，Warm 区会累积数百条条目，虽然不注入上下文，但落盘文件仍然庞大，且不利于快速审计。

## 解决方案：语义摘要

不保留"每次心跳的 detail"，而是定期生成**聚合统计**和**模式识别**。

## 摘要内容

### Verification Summary（验证摘要）

```yaml
verification_summary:
  window: "last_10_checks"
  total: 23
  passed: 20
  failed: 3
  pass_rate: 87%
  recurring_failures:
    - "authentication timeout": 2
    - "missing env var": 1
  last_failure: "2026-07-10 17:30"
```

### Mutation Summary（变更摘要）

```yaml
mutation_summary:
  window: "last_5_mutations"
  total: 5
  types:
    ralph-retry: 3
    insert: 1
    skip: 1
  replan_count: 2  # 包含 strategic-replan
  major_direction_changes: 1
```

### Confidence Trend（置信度趋势）

```yaml
confidence_trend:
  window: "last_5_updates"
  start: { completion: 20, confidence: 60, evidence: 30 }
  end:   { completion: 70, confidence: 45, evidence: 50 }
  trend: "down"   # up|flat|down
  plateau_detected: false
```

### Trust Score Evolution（可信度演变）

```yaml
trust_score_evolution:
  window: "last_5_tasks"
  values: [62, 58, 55, 60, 54]
  average: 57.8
  trend: "down"
```

## 实施

`state_compressor` 组件新增 `generate_semantic_summary` 函数：

1. 每隔 `N` 次 Heartbeat（如 10 次）触发一次摘要生成
2. 读取 Warm 区原始记录（最近 M 条，如 20 条）
3. 调用 `semantic_summarizer` prompt 生成上述结构化摘要
4. 将摘要写入 `## 语义摘要` 区块
5. **可选**：原始记录迁移到 Cold 区归档

## 配置

在 `stm-ledger.md` 元数据中：

```yaml
semantic_summary:
  enabled: true
  window_size: 10   # 每 10 次心跳生成一次摘要
  retention: "summary_only"  # 保留摘要，原始迁移到冷区
```

## 与 State Compression 的关系

```
Hot: 当前任务 + 最近 3 次验证 (原始 detail)
Warm: 最近摘要 (semantic summary) + 最近 5 次 mutation 概要
Cold: 原始日志归档 + 已完成任务
```

## 好处

- Warm 区大小下降 80% 以上（从数百条记录压缩为 4 个 summary 块）
- 快速审计：一目了然看到趋势、高频问题、可信度变化
- 上下文注入更精简：Hot 区 + Warm 区摘要 总体可控在 2000 chars 内

## 示例输出 (在 ledger 中)

```markdown
## 语义摘要

### 最近 10 次验证
- 通过率: 87% (20/23)
- 常见失败: authentication timeout (2次)
- 置信度趋势: 下降 (60 → 45)

### 最近 5 次变更
- 重规划 2 次
- 方向大改 1 次
- 类型分布: ralph-retry (3), insert (1), skip (1)
```

---

**相关**: `templates/stm-ledger.md` (新增 `## 语义摘要` 区块), `scripts/inject-stm-context.py` (集成摘要到 Warm 区)
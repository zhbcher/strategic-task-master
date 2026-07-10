# Strategic Feedback Loop — 双向反馈通道

## 问题

当前 STM 只有 `战略 → WBS → 执行 → 验证` 单向流。真实场景中，子代理在执行时可能发现战略假设错误——这个信号需要向上传递。

## 反馈通道

```
子代理执行 → 发现战略假设错误
  │
  └→ 在 evidence 列附加 strategic_feedback
      │
      ▼
  Todo Enforcement 阶段
      │
      ├→ 扫描所有 strategic_feedback 非空行
      │
      └→ 非空 → 主 Agent 执行防偏航校验:
               ├─ 反馈是否有效？
               ├─ 假设错误是否致命？
               └─ 需要战略调整吗？
                  │
                  └→ 需要 → 记录到 Strategic Mutation Log
```

## 反馈格式

子代理在 evidence 中使用以下格式：

```
## Strategic Feedback

- **假设**: 原战略假设 Milestone 2 使用 Redis
- **发现**: 数据模型需要 JOIN 查询，Redis 不适合
- **建议**: 切换为 PostgreSQL + 物化视图
- **严重度**: MEDIUM
- **证据**: 测试发现 Redis 需要 3 次 round-trip，PG 1 次 JOIN
```

## 严重度等级

| 等级 | 含义 | 处理规则 |
|------|------|---------|
| LOW | 建议优化，不改变方向 | 记录到 Strategic Mutation Log，继续执行 |
| MEDIUM | 后续需调整，当前可继续 | 触发 Anti-Drift 检查，当前 Milestone 完成后评估 |
| HIGH | 必须暂停当前 Milestone | 立即暂停，触发 Strategic Replan |

## WBS 列定义

`docs/spm/ledger.md` 中新增 `Strategic Feedback` 列：

```markdown
| ID | ... | Evidence | Status | Strategic Feedback |
| 3  | ... | curl→189ms | done  | "发现 Redis 不适合:
       建议切换为 PostgreSQL" |
```

## 铁律

- 所有 Strategic Feedback 必须有主 Agent 评估记录
- 评估记录写入 Strategic Mutation Log
- HIGH 严重度反馈必须在 1 轮对话内处理
- 不允许子代理的反馈"石沉大海"
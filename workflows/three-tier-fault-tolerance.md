# Three-Tier Fault Tolerance — 三级容错

> STM 融合核心。将 LTM 的战术级重试与 SN 的战略级重构衔接为完整闭环 + 衰减链路。

## 完整触发链

```
执行 → L1: 验证门禁 (IDENTIFY→RUN→READ→VERIFY)
  │
  ├── PASS → Heartbeat → 扫描 Strategic Feedback → 下一任务
  │
  └── FAIL → 进入 L2

L2: Ralph Loop Round 1 (Strategy A: 精准定位修复)
  ├── PASS → Heartbeat → 下一任务
  └── FAIL → L2 Round 2 (Strategy B: 回滚换方案)
              ├── PASS → 下一任务
              └── FAIL → L2 Round 3 (Strategy C: 拆分子任务)
                          ├── PASS → 下一任务
                          └── FAIL → L3

L3: Divergent Explorer (高维探索, 仅输入1行摘要)
  ├── 成功 → 快照 → 重写 WBS → 重启执行
  └── 失败 → L2 Decoupled

L2 Decoupled: 降级 Ralph Loop (只做验证+只读补丁, 不引入新方案)
  ├── 通过 → 继续执行
  └── 失败 → 上报用户决策
```

## 上下文传递规则

| 方向 | 传什么 | 不传什么 |
|------|--------|---------|
| L2 → L3 | `failed_milestone_id` + `error_summary`（1 行） | 所有实现细节、代码行 |
| L3 → L2(Decoupled) | `divergent_failed: true` + 当前代码状态 | 3 条路径的具体内容 |
| L3 每次触发 | WBS 全量快照到 `ledger-{ts}.md` | 不删除原台账 |

## 判定矩阵

见 `references/fault-tolerance-matrix.md`。

## 衰减链路设计理由

如果没有 L2 Decoupled，Divergent Explorer 首次失败就会直接上报用户，这意味着：

1. 用户需要介入的次数增加了一倍
2. 实际上 Divergent 失败后，还有"只读修复"这个选项没试过
3. 只读修复虽然不能改变架构，但能把当前代码"修到能跑"

L2 Decoupled 的目标：用最低成本让当前代码通过验证门禁，而不是引入新方案。
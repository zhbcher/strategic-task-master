# Divergent Exploration — 高维探索 (SN Phase 3)

## 概述

当 Ralph Loop 3 轮战术重试全部失败时，说明当前路径在战略上是死胡同。Divergent Explorer 通过"最远点采样"原则，生成底层逻辑完全不同的替代方案。

## 触发条件

- Ralph Loop Round 3 失败后
- 触发前自动备份 WBS 台账（见 workflows/strategic-replan-snapshot.md）

## 上下文污染防护（关键）

**输入限制**: Divergent Explorer 只接收两样东西：
1. `failed_milestone_id` — 哪个里程碑失败了
2. `error_summary` — 1 行摘要（如"数据库查询优化：索引、缓存、异步3种方案均失败"）

**不传**：具体实现细节、代码行、失败日志。防止发散思维被污染。

## 执行流程

```
1. 读取输入: failed_milestone_id + error_summary
2. 注入 Phase 3 [DIVERGENT_EXPLORATION] System Prompt
3. LLM 输出 3 条备选路径
4. 校验: 每条路径的底层逻辑必须不同
   - 如果两条路径本质相同 → 要求重新生成
5. 主 Agent 选择最优路径（结合 anti_drift_rules 判断）
6. 执行 strategic-replan:
   - cp ledger.md ledger-{ts}-before-replan.md
   - git stash (代码快照)
   - 重写 StrategicMap
   - 重写 WBS 台账
   - Hash Attestation
```

## 输出格式

每条路径包含：

```json
{
  "path_title": "用物化视图替代实时查询",
  "fundamental_logic": "将运行时计算转为预计算存储",
  "expected_risk": "数据延迟 5min，不能用于实时场景",
  "confidence": 8
}
```

## 成功标准

- 生成 3 条路径的底层逻辑互不相同 ✅
- 至少 1 条路径不违反 anti_drift_rules ✅
- 新路径未在 Ralph Loop 中被尝试过 ✅

## 失败处理

如果 Divergent Explorer 也失败（3 条路径都验证失败）：
→ 进入 L2 Decoupled（降级 Ralph Loop）→ 只做验证+只读修复 → 不引入新方案
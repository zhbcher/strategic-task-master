---
name: "strategic-task-master"
description: "融合StraTA战略导航与LTM工程管控的工业级长程任务终极方案。双层规划+三级容错+衰减链路。"
---

# Strategic Task Master (STM) — 战略任务主控

> 融合 StrategicNavigator（StraTA 战略领航员）的**认知层**与 long-task-manager（LTM）的**工程层**，构建工业级、无坚不摧的长程任务终极方案。
>
> **核心理念**: SN 是"战略大脑"（方向偏航、死胡同探索），LTM 是"工程铁腕"（任务拆解、质量验证、持久化、重试）。两者融合 = 1 + 1 > 2。

## 核心架构

| 层 | 组件 | 职责 |
|----|------|------|
| 战略层 (SN) | 全局战略生成器、防偏航校验器、高维探索器、战略反馈处理器 | 做正确的事 |
| 工程层 (LTM) | WBS 台账、子代理调度、验证门禁、计划突变、Heartbeat | 正确地做事 |

**接口契约**: 战略层输出 `StrategicMap`（JSON）→ 工程层生成 `docs/spm/ledger.md`（Markdown）。子代理通过 evidence 中的 `strategic_feedback` 向上反馈。

## 三级容错（含衰减链路）

```
L1: 验证门禁 (IDENTIFY→RUN→READ→VERIFY) → 通过则下一任务
  └→ 失败 → L2: Ralph Loop A→B→C (3轮)
              └→ 全败 → L3: Divergent Explorer (高维探索, 输入仅传1行摘要)
                          ├→ 成功 → 重写 WBS
                          └→ 失败 → L2 Decoupled: 降级修复(只读补丁级)
                                      └→ 仍失败 → 上报用户
```

## 完整工作流

- **Phase 0**: SN 生成 StrategicMap → 用户确认
- **Phase 1**: 扩展 Milestone 为 WBS 任务 → Hash Attestation
- **Phase 2**: 子代理执行 → 验证门禁 → 三级容错 → 反馈扫描 → 防偏航
- **Phase 3**: 7 阶段验证矩阵 → Delivery Summary → 用户决策

## 铁律

1. 战略先行 — 任何长任务前必须先输出 StrategicMap
2. 验证不撒谎 — 无当次验证命令输出不能 claim 完成
3. 容错不降级 — Ralph Loop 3 轮失败必须尝试高维探索
4. 异步独立 — 子代理隔离执行
5. 全量留痕 — 所有突变记录到审计日志
6. 物理持久化 — 战略和 WBS 写入物理文件
7. 战略上下文不压缩 — 加入 compaction 白名单
8. 反馈必须闭环 — Strategic Feedback 必须有评估记录
9. 快照不可删除 — strategic-replan 前的快照保留到交付

## 参考

- `templates/stm-ledger.md` — WBS 台账模板
- `references/strategic-planning.md` — SN Phase 1
- `references/anti-drift-monitoring.md` — SN Phase 2
- `references/divergent-exploration.md` — SN Phase 3
- `references/strategic-feedback-loop.md` — 双向反馈
- `references/fault-tolerance-matrix.md` — 容错边界
- `references/ralph-loop.md` — 战术重试
- `workflows/three-tier-fault-tolerance.md` — 三级容错
- `workflows/strategic-replan-snapshot.md` — 快照回滚
- `scripts/init-strategic-ledger.sh` — 初始化台账
- `scripts/inject-stm-context.py` — Hook 注入
- `scripts/verify-stm-ledger.sh` — 完整性验证
- `presets/strategic-prompts.yaml` — Prompt 模板
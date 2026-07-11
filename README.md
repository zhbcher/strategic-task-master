# Strategic Task Master (STM) v3.0

> 工业级长程任务 Agent Operating System。从"任务管理器"进化为"决策系统"。

[![Version](https://img.shields.io/badge/STM-v3.0-blue)](https://github.com/zhbcher/strategic-task-master)
[![License](https://img.shields.io/badge/License-MIT-green)](LICENSE)

## ✨ 核心特性 (v3.0)

- ✅ **动态模式升级** — tiny → normal → strategic 按需自动切换
- ✅ **配置档位** — lean/standard/enterprise 一键配置，避免参数爆炸
- ✅ **故障分类器** — execution/environment/dependency/architecture/terminal 五类
- ✅ **三级容错 + 终止条件** — Ralph Loop → Divergent Explorer → Decoupled，max 限制
- ✅ **回滚策略** — Task / Milestone / Strategic 三级可逆操作
- ✅ **信任评分** — 基于预估偏差、失败率、回滚次数动态计算 Agent 可信度
- ✅ **价值评估** — 投入产出比分析，避免资源浪费
- ✅ **里程碑依赖图** — 关键路径、并行分析，支撑 SubAgent 调度
- ✅ **语义摘要** — Warm 区聚合统计，进一步压缩状态，信息密度提升
- ✅ **状态压缩** — Hot/Warm/Cold + Semantic Summary，防止上下文爆炸

## 📁 目录结构

```
strategic-task-master/
├── SKILL.md                    # 技能定义 (v3.0)
├── README.md                   # 本文件
├── presets/
│   └── strategic-prompts.yaml  # Prompt 模板（含 value_assessor, mode_escalation, rollback, trust_score, semantic_summary）
├── references/
│   ├── anti-drift-monitoring.md
│   ├── confidence-scoring.md
│   ├── divergent-exploration.md
│   ├── fault-tolerance-matrix.md
│   ├── milestone-dependencies.md   # v3.0 新增
│   ├── mode-escalation.md          # v3.0 新增
│   ├── rollback-strategy.md        # v3.0 新增
│   ├── semantic-summary.md         # v3.0 新增
│   ├── state-compression.md
│   ├── terminal-failure.md         # v3.0 新增
│   ├── trust-score.md              # v3.0 新增
│   ├── value-score.md              # v3.0 新增
│   ├── ralph-loop.md
│   ├── strategic-feedback-loop.md
│   └── strategic-planning.md
├── scripts/
│   ├── attest-ledger.sh
│   ├── init-strategic-ledger.sh   # 支持 --profile 参数
│   ├── inject-stm-context.py      # State Compression + Semantic Summary
│   ├── verify-stm-ledger.sh       # v3.0 增强验证
│   └── (rollback-*.sh 待实现)
├── templates/
│   └── stm-ledger.md              # v3.0 增加：里程碑依赖、回滚计划、value_score、trust_score
└── workflows/
    ├── strategic-replan-snapshot.md
    ├── subagent-driven-execution.md
    ├── three-tier-fault-tolerance.md  # v3.0 包含 terminal 和 rollback
    └── verification-before-completion.md
```

## 🚀 快速开始

### 1. 选择配置档位

```bash
# lean: 小项目，最小开销
bash scripts/init-strategic-ledger.sh "My Project" docs/spm --profile=lean --adaptive-mode=auto

# standard: 默认，推荐
bash scripts/init-strategic-ledger.sh "My Project" docs/spm --profile=standard --adaptive-mode=auto

# enterprise: 大项目，全功能
bash scripts/init-strategic-ledger.sh "My Project" docs/spm --profile=enterprise --adaptive-mode=auto
```

### 2. 验证台账

```bash
bash scripts/verify-stm-ledger.sh docs/spm/ledger.md
```

### 3. 配置 OpenClaw Hook

```json
{
  "hooks": {
    "preToolUse": [
      {
        "command": "python3 skills/strategic-task-master/scripts/inject-stm-context.py",
        "maxChars": 1500
      }
    ]
  }
}
```

重启网关。

## 🧠 核心概念

### Profile Presets

| Profile | 适用场景 | adaptive_mode | cost_budget | max_replan | max_divergent |
|---------|---------|---------------|-------------|------------|---------------|
| **lean** | 单文件 <15min | auto | low | 2 | 0 |
| **standard** | 多文件 <2h | auto | medium | 3 | 1 |
| **enterprise** | 系统重构 >2h | auto | high | 5 | 2 |

### Mode Escalation

任务运行时自动调整模式：

- `tiny → normal`: 文件 >3 或 时间 >30min
- `normal → strategic`: replan >=2 或 架构问题
- `strategic → normal`: confidence 暴跌或用户简化

### Trust Score

量化 Agent 预测可靠性（0-100）：

```python
trust_score = estimate_deviation(0-40) + failure_rate(0-30) + rollback_penalty(0-30)
```

低 trust_score (如 35) 表示当前 confidence 不可全信。

### Value Score

评估任务性价比：

```yaml
value_score = impact(0-50) + effort_score(0-30) + risk_score(0-20)
```

value_score < 40 → 建议重新评估需求或寻找 MVP 方案。

### Milestone Dependencies

里程碑依赖图支持：

- 拓扑排序 → 自动确定执行顺序
- 关键路径分析 → 识别瓶颈
- 并行度最大化 → 分配给多个子代理

### Rollback Strategy

三级回滚：

- **Task**: 撤销本任务文件修改
- **Milestone**: 恢复到里程碑快照
- **Strategic**: 恢复到上一版 StrategicMap

触发条件：confidence_drop >30、regression、strategic_feedback 指根本错误。

### Terminal Failure

某些失败本质不可恢复：

- API 不存在、许可证禁止、第三方服务下线
- 分类为 `terminal` → 立即停止，不进入容错循环

### Semantic Summary

Warm 区不再存原始记录，而是聚合：

```yaml
verification_summary: { passed:20, failed:3, recurring:"auth timeout" }
mutation_summary: { replan:2, direction_changes:1 }
confidence_trend: { from:60, to:45, trend:"down" }
```

上下文更紧凑，审计更高效。

## 🛠️ 故障排查

| 问题 | 解决方案 |
|------|---------|
| 模式不升级 | 检查 mode_escalation 条件是否满足，手动触发 `mode_recommendation` |
| trust_score 持续低 | 提高任务粒度，减少单任务复杂度 |
| value_score 低但必须做 | 在 StrategicMap 中说明强制原因 |
| rollback 失败 | 确保快照存在，检查 scripts/rollback-*.sh 权限 |
| 上下文溢出 | 检查 Hot 区大小，调整 state_compression 参数 |

## 📜 工作流示例

### 小型任务 (lean profile)

1. 用户: "修 typo"
2. init 使用 `--profile=lean --adaptive-mode=tiny`
3. 跳过 StrategicMap，直接单任务 WBS
4. 执行 → 验证 → 完成
5. 无容错、无回滚、无摘要

### 中型任务 (standard profile)

1. 用户: "重构登录模块"
2. init 使用 `--profile=standard`
3. auto 选择 `normal` 或 `strategic`
4. 生成 StrategicMap（含 milestones 依赖）
5. Value Assessment 选最小方案 (value_score=62)
6. 执行中遇到死胡同 → Divergent → 成功
7. 更新 trust_score (58→54)
8. 交付

### 大型任务 (enterprise profile)

1. 用户: "迁移整个认证系统"
2. init 使用 `--profile=enterprise`
3. auto 选择 `strategic`
4. StrategicMap 包含 6 个里程碑，depends_on 形成关键路径
5. 发现第三方 API 下线 → terminal failure → 立即停止，上报
6. 避免 20 小时无效工作

## 🤝 贡献

欢迎提交 Issue 和 Pull Request。

## 📚 参考

- [STM v2 → v3 升级指南](references/mode-escalation.md)
- [Fault Tolerance Matrix](references/fault-tolerance-matrix.md)
- [Trust Score Calculation](references/trust-score.md)
- [Value Assessment](references/value-score.md)
- [Rollback Strategy](references/rollback-strategy.md)
- [Milestone Dependencies](references/milestone-dependencies.md)
- [Semantic Summary](references/semantic-summary.md)
- [Terminal Failure](references/terminal-failure.md)

## 📄 许可

MIT © 2026 Strategic Task Master Contributors.
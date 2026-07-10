# Strategic Task Master (STM)

> 融合 StrategicNavigator（StraTA 战略领航员）的**认知层**与 long-task-manager（LTM）的**工程层**，构建工业级、无坚不摧的长程任务终极方案。

[![Version](https://img.shields.io/badge/STM-v2.1-blue)](https://github.com/zhbcher/strategic-task-master)
[![License](https://img.shields.io/badge/License-MIT-green)](LICENSE)

## ✨ 核心特性 (v2.1)

- ✅ **自适应模式** — tiny/normal/strategic 三档，避免"规划 > 执行"
- ✅ **任务复杂度分级** — S/M/L/XL 与 adaptive_mode 联动
- ✅ **故障分类器** — execution/environment/dependency/architecture 差异化处理
- ✅ **结构化 StrategicMap** — 固定 JSON Schema，跨模型一致
- ✅ **证据强度评估** — 客观证明完成度，而非主观声称
- ✅ **置信度评分** — completion + confidence + evidence_strength 三维评估
- ✅ **状态压缩** — Hot/Warm/Cold 分区，防止上下文爆炸
- ✅ **Divergent 触发收紧** — ralph_failed >=3 AND confidence<40 AND architecture
- ✅ **硬熔断机制** — max_replan=3, max_divergent=1, max_execution_cycles=20, plan_frozen
- ✅ **三级容错** — 验证门禁 → Ralph Loop → Divergent Explorer → Decoupled

## 📁 目录结构

```
strategic-task-master/
├── SKILL.md                    # 技能定义（v2.1）
├── README.md                   # 本文件
├── presets/
│   └── strategic-prompts.yaml  # Prompt 模板（含 state_compressor、evidence_strength_assessor）
├── references/
│   ├── anti-drift-monitoring.md
│   ├── confidence-scoring.md      # v2.1 置信度评分
│   ├── divergent-exploration.md   # v2.1 触发条件
│   ├── fault-tolerance-matrix.md  # v2.1 故障分类器 + 硬熔断 + State Compression
│   ├── ralph-loop.md
│   ├── state-compression.md       # v2.1 状态压缩策略
│   ├── strategic-feedback-loop.md
│   └── strategic-planning.md
├── scripts/
│   ├── attest-ledger.sh
│   ├── init-strategic-ledger.sh   # v2.1: 支持自适应模式参数 [project] [output] [mode]
│   ├── inject-stm-context.py      # v2.1: State Compression 实现
│   └── verify-stm-ledger.sh       # v2.1: 增加 evidence_strength、frozen、state 检查
├── templates/
│   └── stm-ledger.md              # v2.1: 增加 evidence_strength 列、plan_frozen、task_tier
└── workflows/
    ├── strategic-replan-snapshot.md
    ├── subagent-driven-execution.md
    ├── three-tier-fault-tolerance.md  # v2.1 完整流程
    └── verification-before-completion.md
```

## 🚀 快速开始

### 1. 初始化 WBS 台账

```bash
# strategic 模式（完整 STM）
bash scripts/init-strategic-ledger.sh "My Project" docs/spm strategic

# normal 模式（简版，跳过 StrategicMap）
bash scripts/init-strategic-ledger.sh "My Project" docs/spm normal

# tiny 模式（单任务，最小开销）
bash scripts/init-strategic-ledger.sh "My Project" docs/spm tiny
```

### 2. 哈希认证（可选）

```bash
bash scripts/attest-ledger.sh docs/spm/ledger.md
```

### 3. 验证台账

```bash
bash scripts/verify-stm-ledger.sh docs/spm/ledger.md
```

### 4. 配置 OpenClaw Hook（自动注入 Hot 区上下文）

在 `~/.openclaw/openclaw.json` 中添加:

```json
{
  "hooks": {
    "preToolUse": [
      {
        "command": "python3 skills/strategic-task-manager/scripts/inject-stm-context.py",
        "maxChars": 1500
      }
    ]
  }
}
```

重启网关后，STM 会在每次工具调用前自动注入 Hot 区上下文。

## 🧠 核心概念

### Adaptive Mode（自适应模式）

| 模式 | 适用场景 | StrategicMap | Divergent | State Compression |
|------|---------|--------------|-----------|-------------------|
| **tiny** | 单文件修改，<15min | ❌ 跳过 | ❌ 跳过 | ✅ |
| **normal** | 多文件改动，<60min | ❌ 跳过 | ❌ 跳过 | ✅ |
| **strategic** | 系统重构，>1h | ✅ 完整 | ✅ 条件触发 | ✅ |

自动判定基于输入长度、文件数、时间估算。用户可在 StrategicMap 中覆写 `adaptive_mode`。

### Task Tier（任务分级）

- **S** (tiny): 单文件，<15min
- **M** (normal): 多文件，<60min
- **L** (strategic): 系统重构，<4h
- **XL** (strategic): 全项目级，>4h

### Confidence Score（三维置信度）

| 维度 | 含义 | 范围 | 来源 |
|------|------|------|------|
| `completion` | 我认为完成了多少 | 0-100% | LLM 主观评估 |
| `confidence` | 我对完成度的信心 | 0-100% | LLM 主观信心 |
| `evidence_strength` | 客观证据强度 | 0-100 | 验证输出客观评估 |

**证据强度评估**：
- 有测试输出（通过率） → 0-40
- 有运行日志 → 0-30
- 有用户验证 → 0-30

当 `evidence_strength < 30` 时，即使 `completion` 和 `confidence` 高也应警惕幻觉。

### Fault Classifier（故障分类器）

| 类型 | 典型场景 | 策略 | 触发 Divergent 条件 |
|------|---------|------|-------------------|
| **execution** | 语法错误、测试失败 | Ralph Loop (A→B→C) | `ralph_failed>=3 AND confidence<40` |
| **environment** | 权限不足、网络不通 | 请求用户 | 不触发 |
| **dependency** | 依赖冲突、版本问题 | 重新规划 WBS (最多3次) | 3次方案失败后 |
| **architecture** | 方向错误、设计缺陷 | Divergent Explorer (跳过 Ralph) | 立即触发 |

### Hard Replan Limit（硬熔断）

```yaml
max_replan: 3
max_divergent: 1
max_execution_cycles: 20
plan_frozen: false
```

任一超限 → `plan_frozen = true` → 立即上报用户。

### State Compression（状态压缩）

- **Hot**（<=1500 chars，注入上下文）：当前任务、里程碑、最近验证、置信度、Strategic Context
- **Warm**（落盘不注入）：最近 5 次 Mutation、最近 10 次 Heartbeat
- **Cold**（归档）：已完成任务（>50 迁移）、历史快照

好处：Context 保持稳定，不随任务轮次线性增长。

## 🛠️ 故障排查

| 问题 | 解决方案 |
|------|---------|
| `inject-stm-context.py` 找不到 ledger | 确保工作目录为项目根，或传参 `ledger_path` |
| 验证失败 `plan_frozen` | 检查 `replan_count` 是否达到 3，若需继续需用户确认重置 |
| Divergent 频繁触发 | 检查 `confidence` 是否持续 < 40，可能需要调整 Ralph 策略 |
| Context 大小超限 | 检查 Hot 区内容，确保 <= 1500 chars；适当压缩 Warm 区历史 |

## 📜 工作流示例

### 典型长任务流

1. 用户输入: "重构用户认证模块"
2. `adaptive_mode_selector` → `strategic` + `L`
3. `phase1_strategy_map` → 输出 StrategicMap（JSON）
4. 用户确认 → 写入 `## 战略上下文`
5. LTM 展开 WBS（2-5 子任务）
6. 子代理执行 → 验证门禁 → 故障分类器 → 按类型处理
7. 每次验证后：
   - `confidence_score_update` 计算三维评分
   - `evidence_strength_assessor` 评估证据
   - `state_compressor` 维护 Hot 区
   - 检查 Hard Replan Limit
8. 交付前：生成 Delivery Summary（含 evidence_strength 总分、strategic_debt）

### 短任务流（tiny 模式）

1. 用户输入: "修 typo 在某文件"
2. `adaptive_mode_selector` → `tiny` + `S`
3. 跳过 StrategicMap
4. 直接生成单任务 WBS
5. 执行 → 验证 → 完成
6. 无 Divergent，无状态压缩考虑（任务太快）

## 🤝 贡献

欢迎提交 Issue 和 Pull Request。

## 📚 参考

- [STM v1 → v2 升级指南](references/strategic-planning.md)
- [Fault Tolerance Matrix](references/fault-tolerance-matrix.md)
- [Confidence Scoring](references/confidence-scoring.md)
- [State Compression](references/state-compression.md)

## 📄 许可

MIT © 2026 Strategic Task Master Contributors.
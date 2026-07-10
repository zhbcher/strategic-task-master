# Strategic Task Master (STM)

融合 StrategicNavigator（StraTA 战略领航员）的**认知层**与 long-task-manager（LTM）的**工程层**，构建工业级、无坚不摧的长程任务终极方案。

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

## 铁律

1. **战略先行** — 任何长任务前必须先输出 StrategicMap
2. **验证不撒谎** — 无当次验证命令输出不能 claim 完成
3. **容错不降级** — Ralph Loop 3 轮失败必须尝试高维探索
4. **异步独立** — 子代理隔离执行
5. **全量留痕** — 所有突变记录到审计日志
6. **物理持久化** — 战略和 WBS 写入物理文件
7. **战略上下文不压缩** — 加入 compaction 白名单
8. **反馈必须闭环** — Strategic Feedback 必须有评估记录
9. **快照不可删除** — strategic-replan 前的快照保留到交付

## 快速开始

### 1. 初始化战略级 WBS 台账

```bash
bash scripts/init-strategic-ledger.sh "项目名称" [output_path]
# 默认生成: docs/spm/ledger.md
```

### 2. 哈希认证

```bash
bash scripts/attest-ledger.sh docs/spm/ledger.md
# 生成: docs/spm/ledger.md.sha256
```

### 3. 完整性验证

```bash
bash scripts/verify-stm-ledger.sh docs/spm/ledger.md
```

### 4. 配置 OpenClaw Hook（可选）

在 `~/.openclaw/openclaw.json` 中配置 preToolUse hook：

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

### 5. 重启网关

```bash
openclaw gateway restart
```

## 目录结构

```
strategic-task-master/
├── SKILL.md                           # 技能定义
├── presets/strategic-prompts.yaml     # Prompt 模板
├── references/
│   ├── anti-drift-monitoring.md       # 防偏航监控
│   ├── divergent-exploration.md       # 高维探索
│   ├── fault-tolerance-matrix.md      # 容错边界
│   ├── ralph-loop.md                  # 战术重试
│   ├── strategic-feedback-loop.md     # 双向反馈
│   └── strategic-planning.md          # SN Phase 1
├── scripts/
│   ├── attest-ledger.sh               # 哈希认证
│   ├── init-strategic-ledger.sh       # 初始化台账
│   ├── inject-stm-context.py          # Hook 注入
│   └── verify-stm-ledger.sh           # 完整性验证
├── templates/stm-ledger.md            # WBS 台账模板
└── workflows/
    ├── strategic-replan-snapshot.md   # 快照回滚
    ├── subagent-driven-execution.md   # 子代理执行
    ├── three-tier-fault-tolerance.md  # 三级容错
    └── verification-before-completion.md # 完成前验证
```

## License

MIT

# State Compression — 状态压缩策略 (v2.1)

## 问题背景

STM 累积的元数据（StrategicMap, Ledger, Mutation Log, Confidence, Feedback, Snapshot 等）在长任务中会线性增长，导致：

- Context window 80% 用于历史状态，仅 20% 用于实际任务
- 注入内容越来越臃肿，推理效率下降
- 类似 AutoGPT、BabyAGI、CrewAI 的“上下文爆炸”死法

## 解决方案：三层分区

将状态数据分为 **Hot**、**Warm**、**Cold** 三个层级，分别处理：

| 分区 | 内容 | 用途 | 大小控制 |
|------|------|------|---------|
| **Hot** | 当前任务、当前里程碑、最近 3 次验证、置信度、Strategic Context（strategic 模式） | 注入 preToolUse 上下文 | <= 1500 chars |
| **Warm** | 最近 5 次 Mutation、最近 10 次 Heartbeat | 落盘审计，不注入 | 无硬限制，但定期清理 |
| **Cold** | 已完成任务（>50 个时迁移）、历史快照 | 归档存储，几乎不访问 | 无限制 |

## 实现要点

### inject-stm-context.py（v2.1 重构）

脚本只读取 Hot 区内容，构造注入文本：

```python
def state_compression_policy(content):
    hot_parts = []
    # Active State
    hot_parts.append(extract_active_state(content))
    # Strategic Context (仅 strategic 模式)
    if adaptive_mode == 'strategic':
        hot_parts.append(extract_strategic_context(content))
    # Confidence Score
    confidence = extract_confidence_score(content)
    if confidence:
        hot_parts.append(f"📊 Confidence: {confidence['completion']} / {confidence['confidence']}")
    # Recent Verifications (last 3)
    verifications = extract_verifications(content, limit=3)
    if verifications:
        hot_parts.append("🔍 Recent Verifications")
        for v in verifications:
            hot_parts.append(f"- {v['time']}: {v['active']} → {v['completed']}")

    hot_text = "\n\n".join(hot_parts)
    if len(hot_text) > MAX_CHARS:
        hot_text = hot_text[:MAX_CHARS-50] + "... [truncated]"
    return hot_text
```

### 压缩策略与 cost_budget 联动

| cost_budget | Hot | Warm | Cold |
|------------|-----|------|------|
| **low** | 仅当前任务 + 置信度 | 禁用（为空） | 无归档 |
| **medium** | 当前任务 + 最近 2 验证 | 最近 3 次 Mutation | 无归档 |
| **high** | 完整 Hot | 完整 Warm | 启用归档（>50 任务迁移） |

### 归档迁移策略

当 `WBS 任务分解` 中 `status=done` 的行数 > 50 时，自动将最早完成的 20 行移动到 `## 归档记录 (Archived)` 区块，并压缩 Cold 数据为 `archive/YYYY-MM/` 子目录。

迁移由 `scripts/verify-stm-ledger.sh --compact` 触发，或手动执行。

## 监控指标

| 指标 | 目标 | 检查频率 |
|------|------|---------|
| Hot 区字符数 | <= 1500 | 每次注入 |
| Context 增长率 | < 10% per 10 tasks | 每 10 任务 |
| Warm 区记录数 | < 100 条 | 每日 |
| Cold 归档大小 | 无限制（但定期清理） | 每月 |

## 与其它组件的协作

- **Confidence Score**: 最新评分始终在 Hot 区
- **Verification Gate**: 每次验证后更新 Hot 区
- **Ralph Loop**: 每轮后更新 Warm 区（mutation + heartbeat）
- **Divergent Explorer**: 成功后写入 Warm 区，失败不记录（避免噪音）
- **Hard Replan Limit**: replan_count 在 Hot 区显示

## 迁移指南（从 v2 升级）

v2 没有分区概念，所有数据混在 Ledger 中。升级到 v2.1 后：

1. 运行 `scripts/inject-stm-context.py` 会自动按新逻辑提取 Hot 区
2. `verify-stm-ledger.sh` 会检查 Warm/Cold 使用情况
3. 无需手动迁移，除非已完成任务 > 50 个，可运行 `scripts/compact-ledger.sh`（待实现）

## 常见问题

**Q:  Warm 区数据如何查看？**  
A: 直接打开 `docs/spm/ledger.md`，`## 计划变更记录` 和 `## 心跳日志` 即为 Warm 区。

**Q:  Cold 归档会丢失吗？**  
A: 不会。归档后仍在 `ledger.md` 中，但折叠在 `## 归档记录` 下；也可配置 `archive/` 目录存储历史快照。

**Q:  State Compression 会影响审计完整性吗？**  
A: 不会。所有数据均保留在磁盘，只是上下文注入时选择性读取。审计时直接查阅 ledger 文件即可。

---

**相关**: `templates/stm-ledger.md`, `scripts/inject-stm-context.py`, `workflows/three-tier-fault-tolerance.md`
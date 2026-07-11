# Adaptive Mode Escalation — 动态模式升级与降级 (v3.0)

## 问题

固定 `adaptive_mode` 在任务开始时决定，无法适应任务演化：

```text
tiny (修按钮) → normal (涉及权限) → strategic (认证模块重构)
```

如果任务开始时选择 `tiny`，后续即使任务扩大也不会升级，导致规划不足。

## 解决方案：模式升级引擎

在 Phase 2（Evaluation）中，SN 评估是否需要**动态提升或降低**模式。

### 升级规则

```yaml
mode_escalation:
  tiny -> normal:
    - touched_files > 3            # 涉及文件数超过 3
    - estimated_time > 30 minutes  # 预估时间超 30 分钟
    - detected_architecture_issue  # 发现架构问题

  normal -> strategic:
    - replan_count >= 2             # 重规划 2 次以上
    - touched_milestones > 1       # 涉及多个里程碑
    - confidence_plateau_detected  # 置信度平台期

  normal -> strategic:
    - architecture_issue_severe    # 严重架构问题（如性能不达标、安全漏洞）
```

### 降级规则

```yaml
mode_downgrade:
  strategic -> normal:
    - confidence_drop > 50         # 信心暴跌
    - user_requested_simplify      # 用户要求简化
    - plan_frozen_true             # 计划冻结

  normal -> tiny:
    - 任务实际缩小（early termination）
```

## 实现

在 `phase2_evaluation` prompt 中增加：

```yaml
inputs:
  - current_mode: "tiny|normal|strategic"
  - metrics:
      touched_files: 12
      replan_count: 2
      confidence_trend: "down"
      # ...

output:
  status: "PROCEED|DRIFT|BLOCKED"
  mode_recommendation:
    escalate_to: "normal|strategic"
    reason: "因为重规划已达2次，需要完整StrategicMap"
  confidence_update: { ... }
```

## 执行

1. SN 输出 `mode_recommendation.escalate_to`
2. LTM 检查：
   - 如果 `escalate_to` 高于当前模式 → 触发 `strategic-replan`
   - 如果 `downgrade_to` 低于当前模式 → 重新评估是否需要简化 WBS
3. 模式切换后，更新 `## 元数据` 中的 `adaptive_mode` 和 `task_tier`

## 限制

- 最大升级次数：每个任务最多升级 1 次（防止频繁切换）
- 降级不限制，但降级后通常意味着范围缩小
- 模式切换会触发 confidence 重置（+0 或 -10）

## 示例

```
任务: "修一个按钮" (tiny模式启动)
↓
发现涉及权限系统 → touched_files=8
↓
Phase2 Evaluation 检测到 escalation 条件
↓
升级到 normal 模式
↓
生成简版 StrategicMap ( goal + constraints + milestones )
↓
继续执行
```

---

**相关**: `presets/strategic-prompts.yaml` (phase2_evaluation), `templates/stm-ledger.md` (metadata)
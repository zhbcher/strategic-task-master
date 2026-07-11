# Fault Tolerance Matrix — 容错边界矩阵（含故障分类器）v2.1

## 故障分类器 (Failure Classifier)

每次失败先分类，再决定策略。替代原来的扁平三级容错。

```python
# STM 故障分类器
FAILURE_SIGNATURES = {
    'execution': [
        'syntax_error', 'compile_error', 'type_error',
        'test_fail', 'build_fail', 'lint_fail',
        'import_error', 'runtime_error',
    ],
    'environment': [
        'permission_denied', 'network_unreachable', 'dns_fail',
        'port_in_use', 'disk_full', 'timeout',
        'invalid_api_key', 'insufficient_balance',
        'content_policy_violation',
    ],
    'dependency': [
        'version_conflict', 'missing_dependency', 'peer_dep_mismatch',
        'deprecated_api', 'incompatible_interface',
    ],
    'architecture': [
        'design_dead_end', 'wrong_approach', 'fundamental_flaw',
        'cannot_meet_requirements', 'performance_unacceptable',
    ],
}

def classify_failure(error_message: str, error_type: str = None) -> str:
    if error_type and error_type in FAILURE_SIGNATURES:
        return error_type
    error_lower = error_message.lower()
    for category, signatures in FAILURE_SIGNATURES.items():
        for sig in signatures:
            if sig.replace('_', ' ') in error_lower or sig in error_lower:
                return category
    return 'execution'
```

## 分级策略（v2.1 触发条件收紧）

| 故障类型 | 首选策略 | 升级条件 | 升级目标 | 示例 |
|---------|---------|---------|---------|------|
| **execution** | Ralph Loop A→B→C | 3 轮全败 **且** confidence < 40 | Divergent Explorer | 语法错误、测试失败、类型错误 |
| **environment** | 请求用户介入 | 用户无响应或拒绝 | 上报用户（不重试） | 权限不足、API key 无效、网络不通 |
| **dependency** | 重新规划 WBS | 3 次方案不行 | Divergent Explorer | 依赖冲突、版本不兼容、库缺失 |
| **architecture** | Divergent Explorer（**跳过 Ralph**） | 探索失败 | L2 Decoupled → 上报用户 | 方向错了、设计缺陷、死胡同 |

**v2.1 关键变化**:
- Divergent Explorer 的触发门槛提高：`ralph_failed >= 3 AND confidence < 40`（仅 execution 类型）
- architecture 类型直接进入 Divergent，不经过 Ralph Loop
- 避免 95% 可通过 Ralph 解决的问题过早进入高成本探索

## 故障分类判定流程

```
失败事件
  │
  ├─ 有明确 error_type 字段？
  │     ├─ 是 → 直接命中分类
  │     └─ 否 → 关键词匹配 error_message
  │
  ├─ 匹配 execution  → Ralph Loop
  │                └→ 3轮全败且 confidence<40 → Divergent
  ├─ 匹配 environment → 请求用户
  │                └→ 用户无响应 → 上报
  ├─ 匹配 dependency  → 重新规划 WBS
  │                └→ 3次方案不行 → Divergent
  └─ 匹配 architecture → Divergent Explorer (直接进入)
                       ├→ 成功 → 重写WBS + 更新置信度
                       └→ 失败 → L2 Decoupled → 上报用户
```

## 容错计数器

| 容错机制 | 最大重试 | 重试策略 | 重置时机 |
|---------|---------|---------|---------|
| Ralph Loop | 3 轮 | A→B→C 策略轮换 | 新任务验证 |
| 重新规划（dependency） | 3 次 | 每次换方案 | 任务完成或阻塞 |
| Divergent Explorer | 1 次 | 生成 3 条路径，选最优 | N/A |
| L2 Decoupled | 1 次 | 只读补丁修复 | N/A |

## 硬性重规划终止条件 (Hard Replan Limit v2.1)

```yaml
replan_policy:
  max_replan: 3            # 硬上限
  max_divergent: 1         # 最多一次 Divergent Explorer
  max_token_budget: 25%    # 上下文预算（可选）
  max_execution_cycles: 20 # 单任务最多执行轮次

if exceeded:
  - freeze_plan: true      # 设置 ledger 中 "计划冻结": true
  - escalate to user immediately
  - 用户确认后可重置计数或另开新 ledger
```

**熔断检查点**:
- 每次 `strategic-replan` 后检查 `replan_count >= 3`
- 每次 `divergent_exploration` 后检查 `divergent_count >= 1`
- 任一超限 → 冻结 → 上报用户

## 状态压缩与上下文控制 (State Compression v2.1)

```yaml
state_policy:
  hot:   # 注入上下文 (max 1500 chars)
    - 当前任务
    - 当前里程碑
    - 最近3次验证 + confidence
    - Strategic Context (strategic 模式)
  warm:  # 仅落盘，不注入
    - 最近5次 Mutation
    - 最近10次 Heartbeat
  cold:  # 归档
    - 已完成任务 (>50个时迁移)
    - 历史快照
```

`inject-stm-context.py` 只读取 Hot 区。Warm/Cold 数据保留在磁盘审计，不进入上下文。

## 协作边界

| 失败类型 | 当前处理 | 升级条件 | 升级目标 |
|---------|---------|---------|---------|
| provider error (rate_limit/timeout/overloaded) | Model Fallback（换模型，最多 3 次） | 3 次 fallback 全失败 | Ralph Loop（战术层——换模型后代码可能不兼容） |
| 验证失败（test/build/lint fail） | 故障分类器 → 匹配 execution → Ralph Loop | 3 轮全败 **且** confidence<40 | Divergent Explorer |
| 代码写完但逻辑错误不可修 | 故障分类器 → 匹配 architecture → **直接** Divergent Explorer | 高维探索 3 条路径也失败 | L2 Decoupled（降级只读修复，再失败上报用户） |
| 子代理返回空/error | 空响应检测 + Model Fallback（最多 2 次） | 2 次 fallback 仍空 | 标记 blocked（silent_failure），不是战略问题，不进入 Divergent |
| 内容政策违反 / 无效 API key | 故障分类器 → 匹配 environment → 上报用户 | — | 不进入任何容错机制 |
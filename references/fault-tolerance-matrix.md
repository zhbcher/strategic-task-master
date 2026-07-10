# Fault Tolerance Matrix — 容错边界矩阵

## 协作边界

| 失败类型 | 当前处理 | 升级条件 | 升级目标 |
|---------|---------|---------|---------|
| provider error (rate_limit/timeout/overloaded) | Model Fallback（换模型，最多 3 次） | 3 次 fallback 全失败 | Ralph Loop（战术层——换模型后代码可能不兼容） |
| 验证失败（test/build/lint fail） | Ralph Loop A→B→C（最多 3 轮） | 3 轮全败 + 不确定是否是战略问题 | Divergent Explorer（战略层——高维探索） |
| 代码写完但逻辑错误不可修 | Divergent Explorer（高维探索） | 高维探索 3 条路径也失败 | L2 Decoupled（降级只读修复，再失败上报用户） |
| 子代理返回空/error | 空响应检测 + Model Fallback（最多 2 次） | 2 次 fallback 仍空 | 标记 blocked（silent_failure），不是战略问题，不进入 Divergent |
| 内容政策违反 / 无效 API key | 不可重试，立即上报 | — | 不进入任何容错机制 |

## 判定函数

```python
# STM 容错边界判定
def determine_fault_tier(error_type: str, retry_count: int) -> str:
    """
    返回: 'model_fallback' | 'ralph_loop' | 'divergent_explorer' | 'decoupled' | 'escalate'
    """

    # Provider/网络错误 → Model Fallback
    if error_type in ['rate_limit', 'timeout', 'overloaded',
                      'bad_gateway', 'service_unavailable',
                      'connection_error', 'internal_error']:
        return 'model_fallback' if retry_count < 3 else 'ralph_loop'

    # 验证失败 → Ralph Loop
    if error_type in ['test_fail', 'build_fail', 'lint_fail',
                      'type_error', 'security_fail']:
        return 'ralph_loop' if retry_count < 3 else 'divergent_explorer'

    # 高维探索也失败 → 降级
    if error_type == 'divergent_failed':
        return 'decoupled'

    # 不可重试
    if error_type in ['invalid_api_key', 'insufficient_balance',
                      'content_policy_violation']:
        return 'escalate'

    # 默认识别不了的也上报
    return 'escalate'
```

## 容错计数器

| 容错机制 | 最大重试 | 重试策略 | 重置时机 |
|---------|---------|---------|---------|
| Model Fallback | 3 次 | 切换 fallback chain 中的下一个模型 | 新任务 dispatch |
| Ralph Loop | 3 轮 | A→B→C 策略轮换 | 新任务验证 |
| Divergent Explorer | 1 次 | 生成 3 条路径，选最优 | N/A (触发即决定) |
| L2 Decoupled | 1 次 | 只读补丁修复，不引入新方案 | N/A (最后一次尝试) |
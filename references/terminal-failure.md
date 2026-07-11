# Terminal Failure — 不可恢复故障 (v3.0)

## 问题背景

不是所有失败都值得重试。有些失败是**任务不可完成**的：

- 用户要求的 API 不存在或已下线
- 许可证禁止修改某部分代码
- 第三方服务永久关闭
- 法规限制导致方案不可行
- 硬件能力不足

这些失败如果进入 Ralph Loop 或 Divergent Explorer，会浪费大量资源却永远无法成功。

## 故障分类器扩展

在 v2.1 基础上，增加 `terminal` 类型：

```python
FAILURE_SIGNATURES = {
    # ... 已有 execution, environment, dependency, architecture
    'terminal': [
        'api_not_found',
        'license_forbidden',
        'third_party_shutdown',
        'unsupported_region',
        'legal_restriction',
        'impossible_requirement',
        'resource_unavailable',
    ],
}
```

## 处理策略

| 故障类型 | 策略 | 升级 | 备注 |
|---------|------|------|------|
| **terminal** | 立即停止 | 无 | 标记 `blocked - terminal`，直接上报用户 |

**不进入任何容错机制**：
- 不执行 Ralph Loop
- 不触发 Divergent Explorer
- 不重新规划 WBS

## 触发条件

当 `failure_classifier` 返回 `failure_type: terminal` 时，立即：

1. 设置当前任务状态为 `blocked`
2. 记录原因到 `Evidence` 列，注明 `terminal: <reason>`
3. 冻结任务（不进行后续重试）
4. 上报用户，提供不可恢复的原因和可能的替代建议（如有）

## 示例

```
用户需求：调用已下线的第三方 API
↓
子代理调用失败
↓
故障分类器检测到 "third_party_shutdown"
↓
立即停止，上报：
  "该 API 已下线，任务无法完成。建议：寻找替代服务或修改需求。"
```

## 与其它故障类型的对比

| 类型 | 是否有希望 | 处理路径 | 最终出口 |
|------|-----------|---------|---------|
| execution | 有（代码问题） | Ralph Loop → Divergent | 成功 / 上报 |
| environment | 有（外部条件） | 请求用户介入 | 成功 / 上报 |
| dependency | 有（依赖问题） | 重新规划 WBS → Divergent | 成功 / 上报 |
| architecture | 有（方向问题） | Divergent Explorer | 成功 / 上报 |
| **terminal** | **无** | **立即停止** | **上报** |

## 配置

在 `stm-ledger.md` 的 `## 元数据` 中可设置：

```yaml
terminal_detection:
  enabled: true
  escalate_immediately: true
```

## 与 Confidence 的关系

- Terminal failure 不计入 `confidence` 下降（因为不是能力问题）
- 但 `trust_score` 会受影响（如果是因为信息缺失导致的 terminal，说明 Agent 前期调研不足）

---

**相关**: `references/fault-tolerance-matrix.md`, `workflows/three-tier-fault-tolerance.md`
# Milestone Dependencies — 里程碑依赖图 (v3.0)

## 问题

当前 StrategicMap 中 `milestones` 只是线性列表，无法表达：

- Milestone C 依赖 A 和 B 都完成
- Milestone D 和 E 可并行
- 关键路径分析

## Schema 扩展

```json
{
  "milestones": [
    {
      "id": 1,
      "title": "设计",
      "depends_on": [],
      "parallel_with": []
    },
    {
      "id": 2,
      "title": "实现核心",
      "depends_on": [1],
      "parallel_with": []
    },
    {
      "id": 3,
      "title": "测试",
      "depends_on": [2],
      "parallel_with": []
    },
    {
      "id": 4,
      "title": "文档",
      "depends_on": [1],
      "parallel_with": [2]  // 可与实现核心并行
    }
  ]
}
```

### 字段说明

| 字段 | 含义 | 示例 |
|------|------|------|
| `id` | 里程碑唯一标识 | 1, 2, 3... |
| `depends_on` | 本里程碑开始前必须完成的里程碑 ID 列表 | `[1, 2]` |
| `parallel_with` | 可与本里程碑并行执行的其他里程碑 ID 列表 | `[3, 4]` |

## 拓扑排序

在 WBS 展开前，对 milestones 进行拓扑排序，确定执行顺序。

```python
def topological_sort(milestones):
    # 构建依赖图
    graph = {m['id']: m['depends_on'] for m in milestones}
    # Kahn 算法
    # ...
    return sorted_ids
```

## 关键路径分析

计算最长路径（总耗时最长）：

```python
def critical_path(milestones, estimated_durations):
    # estimated_durations: {id: hours}
    # 使用动态规划
    # 返回: 关键路径 ID 列表
```

关键路径上的里程碑延迟将拖慢整个项目。

## 并行优化

最大化并行度：

- 对于 `parallel_with` 声明的里程碑，分配独立子代理同时执行
- WBS 任务展开时，将可并行的任务标记为 `parallel: true`

## 在 WBS 中的应用

每个 WBS 任务关联到 `milestone_id`。依赖图自动推导任务间的执行顺序约束。

示例：

```markdown
| ID | 任务名称 | 依赖 | Milestone |
|----|---------|------|-----------|
| 1  | 设计 UI | -    | 1         |
| 2  | 编码 UI | 1    | 2         |
| 3  | 写文档 | 1    | 4         |  // 可与 2 并行
```

## 验证

`verify-stm-ledger.sh` 增加检查：

- 检查 `depends_on` 引用的 milestone 是否存在
- 检查循环依赖（A→B→A）
- 检查所有里程碑是否可达（从无依赖的起点开始）

## 约束

- 最多 8 个里程碑（防止图爆炸）
- 每个里程碑 `depends_on` 不超过 3 个
- 不允许跨里程碑循环依赖

## 示例输出

```
拓扑顺序: 1 → 2 → 4 → 3
关键路径: 1 → 2 → 3 (总时长 20h)
最大并行度: 2 (任务 2 和 4 可同时进行)
```

---

**相关**: `templates/stm-ledger.md` (Milestone 列), `presets/strategic-prompts.yaml` (phase1_strategy_map 输出格式)
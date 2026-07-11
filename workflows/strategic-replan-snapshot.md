# Strategic Replan Snapshot — 战略重规划快照与回滚

## 触发条件

L3 Divergent Explorer 成功生成新路径，即将重写 WBS 台账时。

## 快照步骤

```bash
# 1. 备份当前台账（时间戳命名）
cp docs/spm/ledger.md docs/spm/ledger-{YYYY-MM-DD-HHMM}-before-replan.md

# 2. 保存当前工作区代码
git stash push -m "STM strategic-replan: pre-replan snapshot at {timestamp}"

# 3. 记录 Strategic Mutation Log
# | {timestamp} | strategic-replan | 全表 | Ralph Loop 3轮 + Divergent | 重写台账 |

# 4. 重写 StrategicMap（从 Divergent 输出的 3 条路径中选最优）

# 5. 重写 WBS 台账
# 原任务行标记 skipped（原因: strategic-replan 新旧路径)
# 新任务行根据新战略生成

# 6. 更新 Active State
# Previous attempt saved: docs/spm/ledger-{ts}-before-replan.md

# 7. 重新 Hash Attestation
bash scripts/attest-ledger.sh docs/spm/ledger.md
```

## 回滚步骤

```bash
# 1. 停止当前执行

# 2. 找到最近一次快照
ls -t docs/spm/ledger-*-before-replan.md | head -1

# 3. 恢复台账
cp docs/spm/ledger-{ts}-before-replan.md docs/spm/ledger.md

# 4. 恢复代码
git stash pop

# 5. 记录回滚到 Mutation Log
# | {timestamp} | rollback | 全表 | 新战略失败，恢复原始 | - |

# 6. 重新 Hash Attestation

# 7. 继续执行原战略
```

## 审计留存

每次 strategic-replan 后，以下文件必须保留到项目交付：

- `docs/spm/ledger-{ts}-before-replan.md` — 原始台账快照
- `docs/spm/ledger.md` — 当前台账（含 Mutation Log）
- `git stash list` 中的 stash 记录（代码快照）

## 铁律

- 快照不可删除（保留到项目交付）
- 回滚时必须恢复台账 + 代码（两者一致性必须保证）
- 每次 strategic-replan 后自动运行 attest-ledger.sh
- 同一项目最多保留 5 份快照，超出则删除最旧的
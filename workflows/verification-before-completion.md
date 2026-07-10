# Verification Before Completion — 完成前验证

> 继承自 long-task-manager。无当次会话的验证命令输出不能 claim 完成。

## Gate Function（5 步）

任何任务标记 `done` 前，必须执行：

```
1. IDENTIFY: 什么命令能证明这个 claim？
   - "tests pass" → `npm test`
   - "API returns correct data" → `curl <url>`
   - "build succeeds" → `npm run build`

2. RUN: 完整执行该命令（当次会话，不能使用上一次输出）

3. READ: 读取全部输出，检查 exit code

4. VERIFY: 输出确实支持你的 claim？
   - exit code = 0
   - 测试通过数 > 0
   - API 返回预期 JSON

5. ONLY THEN: 更新 WBS status=done + evidence
```

## Eval Delta

每个任务完成后、标记 done 之前，做执行前后对比：

```
📊 Eval Delta — Task [ID]

Baseline:  [N] tests | [X]% coverage
Current:   [M] tests | [Y]% coverage
────────────────────────────────────
Delta:     +[M-N] tests | +/-[Y-X]% coverage
```

## STM 增强

与原 LTM 相比，验证门禁新增以下战略检查：

1. 子代理输出的 [STATUS] 标记是否一致
2. Strategic Feedback 列是否非空（非空 → 触发反馈流程）

## 验证证据格式

```markdown
Task 3: 实现 JWT 中间件 — DONE

Verification: npm test
Result: 8/8 tests passed, exit 0
Coverage: 85%

Strategic Feedback: (无)
Status: PROCEED
```

## 常见验证命令

| 任务类型 | 验证命令 | 预期输出 |
|---------|---------|---------|
| API 实现 | `curl -s <url>` | HTTP 200 + JSON |
| 单元测试 | `npm test` | "PASS" |
| 构建 | `npm run build` | exit 0 |
| 类型检查 | `npm run type-check` | "No errors" |
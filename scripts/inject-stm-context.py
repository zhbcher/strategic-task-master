#!/usr/bin/env python3
"""
inject-stm-context.py — 注入 WBS 上下文 + 战略上下文
在 OpenClaw preToolUse Hook 中使用。

继承自 long-task-manager/scripts/inject-wbs-context.py，
新增战略上下文和 Strategic Feedback 注入。
"""

import sys
import re
from pathlib import Path

def read_ledger(ledger_path="docs/spm/ledger.md"):
    try:
        with open(ledger_path, 'r', encoding='utf-8') as f:
            return f.read()
    except FileNotFoundError:
        return None

def extract_strategic_context(content):
    """提取 ## 战略上下文 部分"""
    match = re.search(
        r'## 战略上下文.*?\n(.*?)(?=##|\Z)',
        content, re.DOTALL
    )
    if match:
        text = match.group(1).strip()
        # 限制长度，避免超过 maxChars
        lines = text.split('\n')
        if len(lines) > 10:
            lines = lines[:10] + ['...']
        return '\n'.join(lines)
    return "No strategic context"

def extract_active_state(content):
    """提取 Active State 部分"""
    match = re.search(
        r'## 当前执行状态.*?\n(.*?)(?=##|\Z)',
        content, re.DOTALL
    )
    if match:
        return match.group(1).strip()
    return "No active state"

def extract_strategic_feedback(content):
    """从 WBS 表格中提取当前任务的 Strategic Feedback 列"""
    # 从 Active State 找当前任务
    active = extract_active_state(content)
    task_match = re.search(r'当前任务[：:]\s*(.+)', active)
    if not task_match:
        return ""

    current_task = task_match.group(1).strip()

    # 在 WBS 表格中找该任务行
    lines = content.split('\n')
    in_table = False
    for line in lines:
        if re.match(r'^\|\s*ID\s*\|', line.strip()):
            in_table = True
            continue
        if in_table and line.strip().startswith('|'):
            cells = [c.strip() for c in line.split('|')]
            # 第 9 列（index 8）是 Strategic Feedback
            if len(cells) >= 9 and cells[1].strip() == current_task:
                feedback = cells[8].strip()
                if feedback and feedback != '-':
                    return feedback
    return ""

def extract_heartbeat_last(content):
    """提取最近一条 Heartbeat"""
    lines = content.split('\n')
    in_table = False
    last_line = ""
    for line in lines:
        if re.match(r'\|\s*(时间|Time)\s*\|', line.strip()):
            in_table = True
            continue
        if in_table and line.strip().startswith('|'):
            if line.strip().replace('|', '').replace('-', '').strip():
                last_line = line
        elif in_table and not line.strip().startswith('|'):
            break
    if last_line:
        parts = [p.strip() for p in last_line.split('|')]
        if len(parts) >= 5:
            return f"Last: {parts[1]} | Active: {parts[2]} | Completed: {parts[3]}"
    return "No heartbeat"

def main():
    ledger_path = "docs/spm/ledger.md"
    if len(sys.argv) > 1:
        ledger_path = sys.argv[1]

    content = read_ledger(ledger_path)
    if not content:
        print("STM Context: [Ledger not found]")
        sys.exit(0)

    strategic = extract_strategic_context(content)
    wbs_state = extract_active_state(content)
    feedback = extract_strategic_feedback(content)
    heartbeat = extract_heartbeat_last(content)

    output = f"""STM CONTEXT INJECTION:

🎯 Strategic Context
{strategic}

📋 Active State
{wbs_state}

💬 Strategic Feedback
{feedback if feedback else 'No feedback'}

🕐 {heartbeat}

🔗 Full Ledger: docs/spm/ledger.md"""

    max_chars = 2000
    if len(output) > max_chars:
        output = output[:max_chars - 3] + "..."

    print(output)

if __name__ == "__main__":
    main()
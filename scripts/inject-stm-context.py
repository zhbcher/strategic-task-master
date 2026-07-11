#!/usr/bin/env python3
"""
inject-stm-context.py — STM v2.1 上下文注入（Hot/Warm/Cold 分区）
在 OpenClaw preToolUse Hook 中使用。

State Compression 策略：
- Hot: 当前任务 + 当前里程碑 + 最近3次验证 + 置信度曲线 → 注入上下文
- Warm: 最近5次Mutation + 最近10次Heartbeat → 仅落盘，不注入
- Cold: 历史快照、已完成任务 → 归档到 archive/，完全不接触
"""

import sys
import re
from pathlib import Path
from datetime import datetime, timedelta

LEDGER_DEFAULT = "docs/spm/ledger.md"
MAX_CHARS = 1500  # 注入上下文字符上限

def read_ledger(ledger_path=None):
    path = Path(ledger_path or LEDGER_DEFAULT)
    if not path.exists():
        return None
    return path.read_text(encoding='utf-8')

def parse_table_rows(content, section_title):
    """解析指定 section 后的表格行（直到下一个 ##）"""
    section_pat = re.compile(
        rf'^##\s+{re.escape(section_title)}.*?\n(.*?)(?=^##|\Z)',
        re.DOTALL | re.MULTILINE
    )
    m = section_pat.search(content)
    if not m:
        return []
    sec = m.group(1)
    rows = []
    in_table = False
    for line in sec.split('\n'):
        if re.match(r'^\|\s*---', line.strip()):
            in_table = True
            continue
        if in_table and line.strip().startswith('|'):
            # 分割表格单元格，去除首尾 |
            cells = [c.strip() for c in line.strip().split('|')]
            # 去掉第一个和最后一个空元素（来自首尾 |）
            if cells and cells[0] == '':
                cells = cells[1:]
            if cells and cells[-1] == '':
                cells = cells[:-1]
            rows.append(cells)
        elif in_table and not line.strip().startswith('|'):
            break
    return rows

def extract_metadata(content):
    """提取元数据（adaptive_mode, cost_budget, replan_count）"""
    meta = {}
    m = re.search(r'\*\*自适应模式\*\*:\s*\[([^\]]+)\]', content)
    if m:
        meta['adaptive_mode'] = m.group(1).strip()
    m = re.search(r'\*\*成本预算\*\*:\s*\[([^\]]+)\]', content)
    if m:
        meta['cost_budget'] = m.group(1).strip()
    m = re.search(r'\*\*重规划计数\*\*:\s*\[(\d+)/3\]', content)
    if m:
        meta['replan_count'] = int(m.group(1))
    return meta

def extract_active_state(content):
    """提取当前执行状态"""
    section_pat = re.compile(r'## 当前执行状态.*?\n(.*?)(?=##|\Z)', re.DOTALL | re.MULTILINE)
    m = section_pat.search(content)
    if m:
        return m.group(1).strip()
    return ""

def extract_current_task(active_state):
    """从 Active State 解析当前任务"""
    m = re.search(r'当前任务[：:]\s*(.+?)(?:\n|$)', active_state)
    if m:
        return m.group(1).strip()
    return None

def extract_confidence_score(content):
    """提取置信度评分表格（最近一条）"""
    rows = parse_table_rows(content, "置信度评分")
    if rows:
        # 最后一行是最新记录
        cells = rows[-1]
        if len(cells) >= 5:
            return {
                'time': cells[0],
                'completion': cells[1],
                'confidence': cells[2],
                'risk': cells[3],
                'trend': cells[4]
            }
    return None

def extract_verifications(content, limit=3):
    """从心跳日志提取最近验证记录（模拟）"""
    rows = parse_table_rows(content, "心跳日志")
    recent = rows[-limit:] if len(rows) >= limit else rows
    result = []
    for r in recent:
        if len(r) >= 4:
            result.append({
                'time': r[0],
                'active': r[1],
                'completed': r[2],
                'evidence': r[3]
            })
    return result

def state_compression_policy(content):
    """
    根据 cost_budget 和 adaptive_mode 决定注入内容。
    返回 (hot_context, warm_info, cold_info)
    """
    meta = extract_metadata(content)
    adaptive = meta.get('adaptive_mode', 'normal')
    budget = meta.get('cost_budget', 'medium')

    # 计算各分区内容
    hot_parts = []
    warm_info = []
    cold_info = []

    # HOT: 必含
    active_state = extract_active_state(content)
    if active_state:
        hot_parts.append("📋 Active State\n" + active_state)

    strategic_ctx = ""
    if adaptive == 'strategic':
        # 仅 strategic 模式有战略上下文
        sect_pat = re.compile(r'## 战略上下文.*?\n(.*?)(?=##|\Z)', re.DOTALL | re.MULTILINE)
        m = sect_pat.search(content)
        if m:
            strategic_ctx = m.group(1).strip()
            if strategic_ctx:
                hot_parts.append("🎯 Strategic Context\n" + strategic_ctx[:500])

    confidence = extract_confidence_score(content)
    if confidence:
        hot_parts.append(f"📊 Confidence: {confidence['completion']} / {confidence['confidence']} ({confidence['risk']})")

    recent_verifications = extract_verifications(content, limit=3)
    if recent_verifications:
        hot_parts.append("🔍 Recent Verifications")
        for v in recent_verifications:
            hot_parts.append(f"- {v['time']}: {v['active']} → {v['completed']}")

    # WARM: 仅用于统计，不注入
    mutation_rows = parse_table_rows(content, "计划变更记录")
    warm_info.append(f"Mutation Log entries: {len(mutation_rows)}")
    heartbeat_rows = parse_table_rows(content, "心跳日志")
    warm_info.append(f"Heartbeat entries: {len(heartbeat_rows)}")

    # COLD: 已完成任务数量
    wbs_rows = parse_table_rows(content, "WBS 任务分解")
    done_count = sum(1 for r in wbs_rows if len(r) >= 7 and r[6].strip() == 'done')
    cold_info.append(f"Completed WBS tasks: {done_count}")

    # 合并 HOT 内容并截断
    hot_text = "\n\n".join(hot_parts)
    if len(hot_text) > MAX_CHARS:
        hot_text = hot_text[:MAX_CHARS - 50] + "\n... [truncated]"

    return hot_text, warm_info, cold_info

def main():
    ledger_path = sys.argv[1] if len(sys.argv) > 1 else LEDGER_DEFAULT
    content = read_ledger(ledger_path)
    if not content:
        print("STM Context: [Ledger not found]")
        sys.exit(0)

    hot, warm_info, cold_info = state_compression_policy(content)

    output = """=== STM v2.1 Context Injection (Hot Zone) ===

""" + hot

    # 附加 Warm/Cold 统计（仅用于调试，不计入上下文）
    if warm_info or cold_info:
        output += "\n\n[State Compression Stats]\n"
        for w in warm_info:
            output += f"- {w}\n"
        for c in cold_info:
            output += f"- {c}\n"

    print(output)

if __name__ == "__main__":
    main()

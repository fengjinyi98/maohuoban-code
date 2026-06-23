#!/usr/bin/env python3
"""
代码量统计工具 统计三端源码规模并追加到 docs/code-stats.md

核心职责：
- 扫描 iOS / Rust / Web 运营端三个模块的源码文件
- 计算文件数与总行数
- 对比上一次快照，产出 Δ 增量
- 以 markdown 表格形式追加到报告文件，最新快照置顶
"""

from __future__ import annotations

import json
import re
import subprocess
from collections import defaultdict
from datetime import datetime, date as date_type
from pathlib import Path

# 脚本位于 scripts/，上一级即项目根目录
ROOT = Path(__file__).resolve().parent.parent
OUT_DIR = ROOT / "code-stats"
REPORT = OUT_DIR / "code-stats.md"

# 三端扫描配置：展示名 / 根目录 / 源码扩展名 / 需跳过的路径片段
MODULES = [
    {
        "key": "ios",
        "name": "iOS (Swift)",
        "dir": "maohuoban",
        "suffixes": {".swift"},
        "exclude_parts": {"DerivedData", "Pods", ".build"},
    },
    {
        "key": "rust",
        "name": "Rust (后端)",
        "dir": "maohuoban-rust",
        "suffixes": {".rs"},
        "exclude_parts": {"target"},
    },
    {
        "key": "web",
        "name": "Web (HIS系统)",
        "dir": "maohuoban-his-web",
        "suffixes": {".ts", ".tsx", ".js", ".jsx", ".vue", ".css", ".scss", ".html"},
        "exclude_parts": {"node_modules", "dist", "build", ".next"},
    },
]

# 历史区起点标记，脚本靠它定位已有快照范围
HISTORY_MARKER = "<!-- HISTORY -->"
LAST_STATS_RE = re.compile(r"<!-- LAST_STATS:\s*(\{.*?\})\s*-->", re.S)

HEADER = f"""# 代码量进度追踪

运行 `python3 scripts/code_stats.py` 会在下方追加一次快照，包含三端文件数、行数以及相较上次的增量（Δ）。最新快照在最上方。

---

{HISTORY_MARKER}
"""


def iter_source_files(base: Path, suffixes: set[str], exclude_parts: set[str]):
    """按扩展名与排除目录遍历模块源码文件，跳过隐藏目录"""
    if not base.exists():
        return
    for p in base.rglob("*"):
        if not p.is_file() or p.suffix not in suffixes:
            continue
        parts = p.relative_to(base).parts
        if any(seg.startswith(".") for seg in parts):
            continue
        if any(seg in exclude_parts for seg in parts):
            continue
        yield p


def count_lines(path: Path) -> int:
    """按换行符计数，读取失败回退为 0 避免整批统计中断"""
    try:
        with path.open("rb") as f:
            return sum(1 for _ in f)
    except OSError:
        return 0


def collect_stats() -> dict[str, dict[str, int]]:
    """聚合每个模块的文件数与总行数"""
    result: dict[str, dict[str, int]] = {}
    for mod in MODULES:
        base = ROOT / mod["dir"]
        files = lines = 0
        for p in iter_source_files(base, mod["suffixes"], mod["exclude_parts"]):
            files += 1
            lines += count_lines(p)
        result[mod["key"]] = {"files": files, "lines": lines}
    return result


# Git 短统计解析正则
_SHORTSTAT_RE = re.compile(
    r"(?P<files>\d+)\s+files?\s+changed"
    r"(?:,\s+(?P<adds>\d+)\s+insertions?\(\+\))?"
    r"(?:,\s+(?P<dels>\d+)\s+deletions?\(\-\))?"
)


def collect_git_history() -> dict:
    """采集仓库 Git 提交历史，输出按日聚合的提交数与增删行数"""
    if not (ROOT / ".git").exists():
        return {"totalCommits": 0, "totalAdditions": 0, "totalDeletions": 0,
                "firstCommitDate": "", "lastCommitDate": "", "daily": [], "weekly": []}

    # 一次性获取格式化日志：日期行 + shortstat
    proc = subprocess.run(
        ["git", "log", "--all", "--format=%ad", "--date=short", "--shortstat"],
        capture_output=True, text=True, cwd=str(ROOT),
    )
    daily_commits: dict[str, int] = defaultdict(int)
    daily_adds: dict[str, int] = defaultdict(int)
    daily_dels: dict[str, int] = defaultdict(int)
    current_date = ""
    for line in proc.stdout.splitlines():
        line = line.strip()
        if not line:
            continue
        if line[:2] == "20" and len(line) == 10:  # YYYY-MM-DD
            current_date = line
            daily_commits[current_date] += 1
        elif "changed" in line and current_date:
            m = _SHORTSTAT_RE.search(line)
            if m:
                daily_adds[current_date] += int(m.group("adds") or 0)
                daily_dels[current_date] += int(m.group("dels") or 0)

    if not daily_commits:
        return {"totalCommits": 0, "totalAdditions": 0, "totalDeletions": 0,
                "firstCommitDate": "", "lastCommitDate": "", "daily": [], "weekly": []}

    sorted_dates = sorted(daily_commits.keys())
    daily = [
        {"date": d, "commits": daily_commits[d],
         "additions": daily_adds[d], "deletions": daily_dels[d]}
        for d in sorted_dates
    ]
    total_commits = sum(d["commits"] for d in daily)
    total_adds = sum(d["additions"] for d in daily)
    total_dels = sum(d["deletions"] for d in daily)

    # 按周聚合
    weekly_map: dict[str, dict[str, int]] = defaultdict(
        lambda: {"commits": 0, "additions": 0, "deletions": 0})
    for d in daily:
        iso = date_type.fromisoformat(d["date"]).isocalendar()
        wk = f"{iso[0]}-W{iso[1]:02d}"
        weekly_map[wk]["commits"] += d["commits"]
        weekly_map[wk]["additions"] += d["additions"]
        weekly_map[wk]["deletions"] += d["deletions"]
    weekly = [
        {"week": w, **v} for w, v in sorted(weekly_map.items())
    ]

    return {
        "totalCommits": total_commits,
        "totalAdditions": total_adds,
        "totalDeletions": total_dels,
        "firstCommitDate": sorted_dates[0],
        "lastCommitDate": sorted_dates[-1],
        "daily": daily,
        "weekly": weekly,
    }


def load_last_stats() -> dict | None:
    """从已有报告尾部的 LAST_STATS 注释解析上次快照，用于 Δ 计算"""
    if not REPORT.exists():
        return None
    match = LAST_STATS_RE.search(REPORT.read_text(encoding="utf-8"))
    if not match:
        return None
    try:
        return json.loads(match.group(1))
    except json.JSONDecodeError:
        return None


def format_delta(value: int) -> str:
    """Δ 格式化：零显示 0，其它带正负号加千分位"""
    if value == 0:
        return "0"
    sign = "+" if value > 0 else ""
    return f"{sign}{value:,}"


def render_section(now: datetime, current: dict, previous: dict | None) -> str:
    """生成单次快照小节：时间标题 + 三端行 + 合计行"""
    rows = [
        f"## {now.strftime('%Y-%m-%d %H:%M:%S')}",
        "",
        "| 模块 | 文件数 | Δ 文件 | 行数 | Δ 行数 |",
        "|------|-------:|-------:|-----:|-------:|",
    ]
    total_files = total_lines = prev_files = prev_lines = 0

    for mod in MODULES:
        k = mod["key"]
        f = current[k]["files"]
        l = current[k]["lines"]
        total_files += f
        total_lines += l
        if previous and k in previous:
            df = f - previous[k]["files"]
            dl = l - previous[k]["lines"]
            prev_files += previous[k]["files"]
            prev_lines += previous[k]["lines"]
            df_s, dl_s = format_delta(df), format_delta(dl)
        else:
            df_s = dl_s = "—"
        rows.append(f"| {mod['name']} | {f} | {df_s} | {l:,} | {dl_s} |")

    if previous:
        tdf_s = format_delta(total_files - prev_files)
        tdl_s = format_delta(total_lines - prev_lines)
    else:
        tdf_s = tdl_s = "—"
    rows.append(
        f"| **合计** | **{total_files}** | **{tdf_s}** | **{total_lines:,}** | **{tdl_s}** |"
    )
    rows.append("")
    return "\n".join(rows)


JSON_REPORT = OUT_DIR / "code-stats.json"
HTML_REPORT = OUT_DIR / "code-stats.html"

def extract_history(text: str) -> str:
    """取 HISTORY marker 之后、LAST_STATS 之前的历史快照内容"""
    if HISTORY_MARKER not in text:
        return ""
    tail = text.split(HISTORY_MARKER, 1)[1]
    tail = LAST_STATS_RE.sub("", tail)
    return tail.strip()


def parse_history_to_json(history_text: str, current: dict, now: datetime) -> list:
    """解析 Markdown 历史记录为结构化 JSON"""
    snapshots = []
    # 添加当前快照
    snapshots.append({
        "timestamp": now.strftime('%Y-%m-%d %H:%M:%S'),
        "stats": current
    })
    
    # 简单的正则解析历史表格
    # ## 2026-04-23 10:10:56
    # ...
    # | iOS (Swift) | 575 | +11 | 57,712 | +1,400 |
    sections = history_text.split("## ")
    for section in sections:
        if not section.strip(): continue
        lines = section.split("\n")
        ts = lines[0].strip()
        stats = {}
        for line in lines:
            if "|" not in line or "模块" in line or "---" in line or "合计" in line:
                continue
            parts = [p.strip() for p in line.split("|") if p.strip()]
            if len(parts) >= 4:
                name = parts[0]
                files = int(parts[1].replace(",", ""))
                code_lines = int(parts[3].replace(",", ""))
                
                # 映射回到 key
                key = None
                if "iOS" in name: key = "ios"
                elif "Rust" in name: key = "rust"
                elif "Web" in name: key = "web"
                
                if key:
                    stats[key] = {"files": files, "lines": code_lines}
        if stats:
            snapshots.append({"timestamp": ts, "stats": stats})
    
    return snapshots

def write_report(new_section: str, current: dict, now: datetime, git_history: dict) -> None:
    """重写报告文件：固定 header + 最新快照 + 旧历史 + LAST_STATS 注释，并输出 JSON 和注入 HTML"""
    history = ""
    if REPORT.exists():
        history = extract_history(REPORT.read_text(encoding="utf-8"))

    blob = json.dumps(current, ensure_ascii=False, sort_keys=True)
    parts = [HEADER, "", new_section]
    if history:
        parts.append(history)
        parts.append("")
    parts.append(f"<!-- LAST_STATS: {blob} -->")

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    REPORT.write_text("\n".join(parts) + "\n", encoding="utf-8")

    # 生成 JSON 数据（包含快照历史与 Git 历史）
    snapshots = parse_history_to_json(history, current, now)
    full_data = {
        "snapshots": snapshots,
        "gitHistory": git_history,
    }
    json_data = json.dumps(full_data, ensure_ascii=False, indent=2)
    snapshots_json = json.dumps(snapshots, ensure_ascii=False, indent=2)
    git_json = json.dumps(git_history, ensure_ascii=False, indent=2)

    # 写入 JSON 报告
    JSON_REPORT.write_text(json_data, encoding="utf-8")

    # 注入 HTML 报告 (解决 file:// 协议下的跨域问题)
    if HTML_REPORT.exists():
        content = HTML_REPORT.read_text(encoding="utf-8")
        # 注入代码快照数据
        snap_pattern = r"const snapshotsData = .*?; // DATA_INJECTION_PLACEHOLDER"
        snap_injection = f"const snapshotsData = {snapshots_json}; // DATA_INJECTION_PLACEHOLDER"
        if re.search(snap_pattern, content, re.DOTALL):
            content = re.sub(snap_pattern, snap_injection, content, flags=re.DOTALL)
        # 注入 Git 历史数据
        git_pattern = r"const gitHistoryData = .*?; // GIT_INJECTION_PLACEHOLDER"
        git_injection = f"const gitHistoryData = {git_json}; // GIT_INJECTION_PLACEHOLDER"
        if re.search(git_pattern, content, re.DOTALL):
            content = re.sub(git_pattern, git_injection, content, flags=re.DOTALL)
        HTML_REPORT.write_text(content, encoding="utf-8")
        print(f"已更新 {HTML_REPORT.relative_to(ROOT)} (数据注入成功)")


def main() -> None:
    current = collect_stats()
    git_history = collect_git_history()
    previous = load_last_stats()
    now = datetime.now()
    section = render_section(now, current, previous)
    write_report(section, current, now, git_history)
    print(f"已更新 {REPORT.relative_to(ROOT)}\n")
    print(f"已更新 {JSON_REPORT.relative_to(ROOT)}\n")
    print(section)


if __name__ == "__main__":
    main()

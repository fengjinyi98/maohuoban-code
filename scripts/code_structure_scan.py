#!/usr/bin/env python3
"""
code_structure_scan 目录与文件规则扫描工具

核心职责：
- 扫描仓库代码文件的硬阈值、目录平铺和多类型候选
- 将存量结构问题固化为可审计基线
- 对后续新增或扩大的结构违规输出可验证失败
"""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from collections import defaultdict
from datetime import datetime
from pathlib import Path
from typing import Iterable

ROOT = Path(__file__).resolve().parent.parent
CODE_SUFFIXES = {".swift", ".rs", ".ts", ".tsx", ".js", ".jsx", ".go", ".kt", ".java", ".py"}
HARD_LINE_LIMITS = {".swift": 400, ".rs": 500}
GUIDELINE_LINE_LIMITS = {".swift": 250, ".rs": 300}
REPORT_SOURCE = "docs/engineering/code-structure/03_目录与文件规则全仓扫描报告.md"
DEFAULT_EXEMPTIONS = Path("docs/engineering/code-structure/code-structure-exemptions.json")


def run_git(args: list[str]) -> list[str]:
    """run_git 执行 git 列表命令

    核心职责：
    - 统一读取 git 输出
    - 支持 NUL 分隔路径解析
    """

    completed = subprocess.run(
        ["git", *args],
        cwd=ROOT,
        check=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    return [item.decode("utf-8") for item in completed.stdout.split(b"\0") if item]


def list_code_paths() -> list[Path]:
    """list_code_paths 获取纳入扫描的代码文件

    核心职责：
    - 覆盖 git 追踪文件
    - 覆盖未忽略未追踪文件
    """

    tracked = run_git(["ls-files", "-z"])
    untracked = run_git(["ls-files", "--others", "--exclude-standard", "-z"])
    paths = sorted(set(tracked + untracked))
    return [
        ROOT / path
        for path in paths
        if Path(path).suffix in CODE_SUFFIXES and (ROOT / path).is_file()
    ]


def count_lines(path: Path) -> int:
    """count_lines 统计文件行数

    核心职责：
    - 使用二进制读取避免编码错误中断扫描
    - 保持与 wc -l 接近的行数语义
    """

    try:
        with path.open("rb") as handle:
            return sum(1 for _ in handle)
    except OSError:
        return 0


def read_text(path: Path) -> str:
    """read_text 读取源码文本

    核心职责：
    - 允许编码异常替换
    - 保障多类型候选扫描不中断
    """

    try:
        return path.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return ""


SWIFT_DECLARATION_RE = re.compile(
    r"^(?:public|open|internal|private|fileprivate|final|\s)*\s*(struct|class|enum|actor|protocol)\s+([A-Za-z_][A-Za-z0-9_]*)"
)
RUST_DECLARATION_RE = re.compile(
    r"^(?:pub(?:\([^)]*\))?\s+)(struct|enum|trait|type)\s+([A-Za-z_][A-Za-z0-9_]*)"
)
TYPESCRIPT_DECLARATION_RE = re.compile(
    r"^(?:export\s+)?(?:default\s+)?(?:abstract\s+)?(class|interface|type|enum)\s+([A-Za-z_][A-Za-z0-9_]*)"
)
JAVA_KOTLIN_DECLARATION_RE = re.compile(
    r"^(?:public|private|protected|internal|open|final|data|sealed|abstract|\s)*\s*(class|interface|enum|object|record)\s+([A-Za-z_][A-Za-z0-9_]*)"
)
PYTHON_DECLARATION_RE = re.compile(r"^(class)\s+([A-Za-z_][A-Za-z0-9_]*)")


def primary_type_count(path: Path) -> int:
    """primary_type_count 统计顶层主要类型数量

    核心职责：
    - 识别 Swift 顶层类型
    - 识别 Rust 公开顶层类型
    """

    pattern = declaration_pattern(path.suffix)
    if pattern is None:
        return 0
    names: set[str] = set()
    for line in read_text(path).splitlines():
        if line[:1].isspace():
            continue
        match = pattern.match(line)
        if match:
            names.add(match.group(2))
    return len(names)


def declaration_pattern(suffix: str) -> re.Pattern[str] | None:
    """declaration_pattern 选择语言顶层类型识别规则

    核心职责：
    - 覆盖当前扫描报告中的主要语言
    - 对脚本类语言保持保守候选识别
    """

    if suffix == ".swift":
        return SWIFT_DECLARATION_RE
    if suffix == ".rs":
        return RUST_DECLARATION_RE
    if suffix in {".ts", ".tsx", ".js", ".jsx"}:
        return TYPESCRIPT_DECLARATION_RE
    if suffix in {".java", ".kt"}:
        return JAVA_KOTLIN_DECLARATION_RE
    if suffix == ".py":
        return PYTHON_DECLARATION_RE
    return None


def relative_path(path: Path) -> str:
    """relative_path 生成稳定仓库相对路径"""

    return path.relative_to(ROOT).as_posix()


def collect_code_files() -> list[dict[str, int | str]]:
    """collect_code_files 聚合代码文件扫描输入"""

    files: list[dict[str, int | str]] = []
    for path in list_code_paths():
        rel = relative_path(path)
        directory = str(Path(rel).parent)
        files.append({
            "path": rel,
            "directory": directory if directory != "." else ".",
            "suffix": path.suffix,
            "line_count": count_lines(path),
            "primary_type_count": primary_type_count(path),
        })
    return files


def load_exemptions(path: Path | None = None) -> dict[str, set[str]]:
    """load_exemptions 读取治理豁免清单

    核心职责：
    - 将已审计的存量结构项从活动违规中移除
    - 保持新增或扩大的豁免项仍由基线比对阻断
    """

    exemption_path = ROOT / (path or DEFAULT_EXEMPTIONS)
    if not exemption_path.exists():
        return {
            "flat_directories": set(),
            "hard_line_files": set(),
            "multi_type_files": set(),
        }
    payload = json.loads(exemption_path.read_text(encoding="utf-8"))
    return {
        "flat_directories": set(payload.get("flat_directories", {})),
        "hard_line_files": set(payload.get("hard_line_files", {})),
        "multi_type_files": set(payload.get("multi_type_files", {})),
    }


def scan(exemptions_path: Path | None = None) -> dict[str, int | dict[str, dict[str, int | str | list[str]]]]:
    """scan 执行目录与文件规则扫描"""

    exemptions = load_exemptions(exemptions_path)
    files = collect_code_files()
    by_dir: dict[str, list[str]] = defaultdict(list)
    hard_line_files: dict[str, dict[str, int | str]] = {}
    guideline_line_files: dict[str, dict[str, int | str]] = {}
    multi_type_files: dict[str, dict[str, int | str]] = {}

    for code_file in files:
        path = str(code_file["path"])
        suffix = str(code_file["suffix"])
        line_count = int(code_file["line_count"])
        primary_count = int(code_file["primary_type_count"])
        by_dir[str(code_file["directory"])].append(path)
        hard_limit = HARD_LINE_LIMITS.get(suffix)
        guideline_limit = GUIDELINE_LINE_LIMITS.get(suffix)
        if hard_limit and line_count > hard_limit:
            hard_line_files[path] = {
                "suffix": suffix,
                "line_count": line_count,
                "limit": hard_limit,
            }
        elif guideline_limit and line_count > guideline_limit:
            guideline_line_files[path] = {
                "suffix": suffix,
                "line_count": line_count,
                "limit": guideline_limit,
            }
        if primary_count > 1:
            multi_type_files[path] = {
                "suffix": suffix,
                "line_count": line_count,
                "primary_type_count": primary_count,
            }

    all_flat_directories = {
        directory: {"file_count": len(paths), "files": sorted(paths)}
        for directory, paths in sorted(by_dir.items())
        if len(paths) > 3
    }
    flat_directories = {
        directory: item
        for directory, item in all_flat_directories.items()
        if directory not in exemptions["flat_directories"]
    }
    exempted_flat_directories = {
        directory: item
        for directory, item in all_flat_directories.items()
        if directory in exemptions["flat_directories"]
    }
    active_hard_line_files = {
        path: item
        for path, item in hard_line_files.items()
        if path not in exemptions["hard_line_files"]
    }
    exempted_hard_line_files = {
        path: item
        for path, item in hard_line_files.items()
        if path in exemptions["hard_line_files"]
    }
    active_multi_type_files = {
        path: item
        for path, item in multi_type_files.items()
        if path not in exemptions["multi_type_files"]
    }
    exempted_multi_type_files = {
        path: item
        for path, item in multi_type_files.items()
        if path in exemptions["multi_type_files"]
    }
    return {
        "code_file_count": len(files),
        "hard_line_files": dict(sorted(active_hard_line_files.items())),
        "exempted_hard_line_files": dict(sorted(exempted_hard_line_files.items())),
        "guideline_line_files": dict(sorted(guideline_line_files.items())),
        "flat_directories": flat_directories,
        "exempted_flat_directories": exempted_flat_directories,
        "multi_type_files": dict(sorted(active_multi_type_files.items())),
        "exempted_multi_type_files": dict(sorted(exempted_multi_type_files.items())),
    }


def load_baseline(path: Path) -> dict:
    """load_baseline 读取存量治理基线"""

    return json.loads(path.read_text(encoding="utf-8"))


def baseline_payload(result: dict) -> dict:
    """baseline_payload 生成可审计基线 JSON"""

    return {
        "version": 1,
        "generated_at": datetime.now().isoformat(timespec="seconds"),
        "source_report": REPORT_SOURCE,
        "policy": {
            "flat_directory_direct_code_file_limit": 3,
            "swift_hard_line_limit": 400,
            "rust_hard_line_limit": 500,
            "governance": "存量问题进入基线，新增或扩大的违规由扫描器阻断。",
        },
        "scan": result,
    }


def compare_with_baseline(result: dict, baseline: dict) -> list[str]:
    """compare_with_baseline 比对新增或扩大的结构违规"""

    messages: list[str] = []
    base_scan = baseline["scan"]
    base_hard = base_scan.get("hard_line_files", {})
    for path, current in result["hard_line_files"].items():
        previous = base_hard.get(path)
        if previous is None:
            messages.append(f"新增硬阈值文件：{path} 当前 {current['line_count']} 行")
        elif int(current["line_count"]) > int(previous["line_count"]):
            messages.append(
                f"硬阈值文件继续增长：{path} {previous['line_count']} -> {current['line_count']} 行"
            )

    base_flat = base_scan.get("flat_directories", {})
    for directory, current in result["flat_directories"].items():
        previous = base_flat.get(directory)
        current_files = set(current["files"])
        if previous is None:
            messages.append(f"新增平铺超限目录：{directory} 当前 {current['file_count']} 个代码文件")
            continue
        previous_files = set(previous.get("files", []))
        added_files = sorted(current_files - previous_files)
        if added_files:
            messages.append(
                f"平铺超限目录新增直接代码文件：{directory} 新增 {len(added_files)} 个："
                + ", ".join(added_files[:5])
            )

    base_multi = base_scan.get("multi_type_files", {})
    for path, current in result["multi_type_files"].items():
        previous = base_multi.get(path)
        if previous is None:
            messages.append(f"新增多类型候选文件：{path} 当前 {current['primary_type_count']} 个类型")
        elif int(current["primary_type_count"]) > int(previous["primary_type_count"]):
            messages.append(
                f"多类型候选继续增长：{path} {previous['primary_type_count']} -> {current['primary_type_count']} 个类型"
            )

    base_exempted_hard = base_scan.get("exempted_hard_line_files", {})
    for path, current in result.get("exempted_hard_line_files", {}).items():
        previous = base_exempted_hard.get(path)
        if previous is None:
            messages.append(f"新增硬阈值豁免文件：{path} 当前 {current['line_count']} 行")
        elif int(current["line_count"]) > int(previous["line_count"]):
            messages.append(
                f"硬阈值豁免文件继续增长：{path} {previous['line_count']} -> {current['line_count']} 行"
            )

    base_exempted_flat = base_scan.get("exempted_flat_directories", {})
    for directory, current in result.get("exempted_flat_directories", {}).items():
        previous = base_exempted_flat.get(directory)
        if previous is None:
            messages.append(f"新增平铺目录豁免：{directory} 当前 {current['file_count']} 个代码文件")
            continue
        previous_files = set(previous.get("files", []))
        current_files = set(current["files"])
        added_files = sorted(current_files - previous_files)
        if added_files:
            messages.append(
                f"平铺豁免目录新增直接代码文件：{directory} 新增 {len(added_files)} 个："
                + ", ".join(added_files[:5])
            )

    base_exempted_multi = base_scan.get("exempted_multi_type_files", {})
    for path, current in result.get("exempted_multi_type_files", {}).items():
        previous = base_exempted_multi.get(path)
        if previous is None:
            messages.append(f"新增多类型豁免文件：{path} 当前 {current['primary_type_count']} 个类型")
        elif int(current["primary_type_count"]) > int(previous["primary_type_count"]):
            messages.append(
                f"多类型豁免文件继续增长：{path} {previous['primary_type_count']} -> {current['primary_type_count']} 个类型"
            )
    return messages


def write_json(path: Path, payload: dict) -> None:
    """write_json 写入稳定 JSON 文件"""

    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def render_report(result: dict, baseline_path: Path | None, regressions: Iterable[str]) -> str:
    """render_report 渲染治理扫描报告"""

    regression_rows = list(regressions)
    flat_file_total = sum(int(item["file_count"]) for item in result["flat_directories"].values())
    exempted_flat_file_total = sum(
        int(item["file_count"]) for item in result.get("exempted_flat_directories", {}).values()
    )
    baseline_display = "未使用"
    if baseline_path:
        resolved_baseline = baseline_path if baseline_path.is_absolute() else ROOT / baseline_path
        baseline_display = resolved_baseline.relative_to(ROOT).as_posix()
    rows = [
        "# 目录与文件规则治理扫描结果",
        "",
        f"- 扫描时间：{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}",
        f"- 扫描根目录：`{ROOT}`",
        f"- 存量基线：`{baseline_display}`",
        "",
        "## 1. 当前全仓结构状态",
        "",
        "| 项 | 数量 |",
        "|---|---:|",
        f"| 代码文件总数 | {result['code_file_count']} |",
        f"| 活动硬阈值文件 | {len(result['hard_line_files'])} |",
        f"| 已审计硬阈值豁免文件 | {len(result.get('exempted_hard_line_files', {}))} |",
        f"| 建议阈值文件 | {len(result['guideline_line_files'])} |",
        f"| 活动平铺超限目录 | {len(result['flat_directories'])} |",
        f"| 活动平铺涉及文件 | {flat_file_total} |",
        f"| 已审计平铺豁免目录 | {len(result.get('exempted_flat_directories', {}))} |",
        f"| 已审计平铺豁免涉及文件 | {exempted_flat_file_total} |",
        f"| 活动多类型候选文件 | {len(result['multi_type_files'])} |",
        f"| 已审计多类型豁免文件 | {len(result.get('exempted_multi_type_files', {}))} |",
        "",
        "## 2. 相对基线结果",
        "",
    ]
    if regression_rows:
        rows.extend(["| 结果 | 说明 |", "|---|---|"])
        rows.extend(f"| 失败 | {message} |" for message in regression_rows)
    else:
        rows.append("相对存量基线无新增或扩大的结构违规。")

    rows.extend(
        [
            "",
            "## 3. 治理口径",
            "",
            "- 当前存量违规由基线文件审计承接，后续新增或扩大的违规由本脚本阻断。",
            "- 已审计豁免项记录在 `docs/engineering/code-structure/code-structure-exemptions.json`，豁免目录新增直接代码文件、豁免文件继续增长或新增多类型豁免均会失败。",
            "- 业务代码迁移、页面拆分、Rust 模块拆分仍按独立小切片推进，并在对应切片执行构建或测试。",
            "- 本扫描器不修改业务代码，不改变运行时逻辑和功能行为。",
            "",
        ]
    )
    return "\n".join(rows)


def parse_args() -> argparse.Namespace:
    """parse_args 解析命令行参数"""

    parser = argparse.ArgumentParser(description="扫描目录与文件规则并比对存量治理基线")
    parser.add_argument("--write-baseline", type=Path, help="写入当前扫描结果作为存量基线")
    parser.add_argument("--baseline", type=Path, help="读取基线并阻断新增或扩大的结构违规")
    parser.add_argument("--report", type=Path, help="写入 markdown 扫描结果")
    parser.add_argument("--exemptions", type=Path, help="读取已审计结构豁免清单")
    return parser.parse_args()


def main() -> int:
    """main 命令行入口"""

    args = parse_args()
    result = scan(args.exemptions)
    regressions: list[str] = []

    baseline_path = args.baseline or args.write_baseline
    if args.write_baseline:
        write_json(args.write_baseline, baseline_payload(result))
    elif args.baseline:
        regressions = compare_with_baseline(result, load_baseline(args.baseline))

    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(render_report(result, baseline_path, regressions), encoding="utf-8")

    if regressions:
        for message in regressions:
            print(message, file=sys.stderr)
        return 1

    print("目录与文件规则扫描通过：相对基线无新增或扩大的结构违规。")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

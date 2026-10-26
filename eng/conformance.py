#!/usr/bin/env python3
"""NeNe Wire の規約検査（CNF-001〜CNF-023）。

docs/QUALITY_GATES.md 第 2 節の規則を、Python 3 の標準ライブラリだけで検査する。
違反は「規則 ID パス:行: 説明」の形で出し、1 件でもあれば終了コード 1 を返す。

移植元: NeNe Gambit eng/conformance.py（コミット 64b82ec）。CNF-013・CNF-014・CNF-005 の拡張と CNF-021〜CNF-023 は
このリポジトリの Phase 0 の実測から足した（ADR 0001・ADR 0003）。

    python3 eng/conformance.py [--root DIR] [--today YYYY-MM-DD]

検出語の一部は、この検査器自身や文書が違反として拾われないよう、文字列を分割して組み立てている。
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import re
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path

RULE_FAMILIES = ("ARC", "SWF", "QLT", "CNF", "GIT")
RULE_ID = re.compile(r"\b(?:ARC|SWF|QLT|CNF|GIT)-\d{3}\b")
STATES = ("active", "planned", "不能", "不採用")
SKIP_DIRS = {".git", ".build", ".tools", ".swiftpm", "__pycache__"}
GRAPH_FILE = Path("docs/architecture/module-graph.txt")
ALLOWLIST_FILE = Path("eng/dependency-allowlist.txt")
CONFIG_FILES = {".swiftlint.yml": "--config .swiftlint.yml", ".swift-format": "--configuration .swift-format"}
CONFIG_NAMES = {".swiftlint.yml", ".swiftlint.yaml", ".swift-format"}
CANONICAL_SETTINGS = ('.treatAllWarnings(as: .error)', '.enableUpcomingFeature("ExistentialAny")')
WAIVER_FIELDS = ("Status", "Rule", "Issue", "Owner", "Created", "Expires", "Scope")


@dataclass(frozen=True)
class Violation:
    rule: str
    path: str
    line: int
    message: str

    def render(self) -> str:
        return f"{self.rule} {self.path}:{self.line}: {self.message}"


@dataclass(frozen=True)
class GraphTarget:
    name: str
    kind: str
    deps: tuple[str, ...]
    std: tuple[str, ...]
    composition_root: bool
    unsafe_allowed: bool
    spawn_allowed: bool


@dataclass(frozen=True)
class PackageTarget:
    name: str
    kind: str
    deps: tuple[str, ...]
    settings: tuple[str, ...]
    body: str
    line: int


@dataclass(frozen=True)
class SwiftFile:
    rel: str
    raw: str
    code: str  # コメントと文字列リテラルを空白に置き換えた本文（行と桁は保つ）
    target: str | None


class Context:
    def __init__(self, root: Path, today: dt.date) -> None:
        self.root = root
        self.today = today

    def read(self, rel: Path | str) -> str:
        return (self.root / rel).read_text(encoding="utf-8")

    def exists(self, rel: Path | str) -> bool:
        return (self.root / rel).exists()

    def files(self) -> list[Path]:
        """git が追跡するか追跡し得るファイル（.gitignore と exclude に従う）。git の木でなければ全走査する。"""
        listed = subprocess.run(["git", "-C", str(self.root), "ls-files", "-z", "--cached", "--others", "--exclude-standard"],
                                capture_output=True, text=True)
        if listed.returncode == 0 and (self.root / ".git").exists():
            names = sorted({Path(n) for n in listed.stdout.split("\0") if n})
            return [n for n in names if (self.root / n).is_file()]
        found: list[Path] = []
        for path in sorted(self.root.rglob("*")):
            rel = path.relative_to(self.root)
            if any(part in SKIP_DIRS for part in rel.parts) or not path.is_file():
                continue
            found.append(rel)
        return found

    def swift_files(self) -> list[SwiftFile]:
        result = []
        for rel in self.files():
            if rel.suffix != ".swift":
                continue
            raw = self.read(rel)
            target = rel.parts[1] if len(rel.parts) >= 3 and rel.parts[0] in ("Sources", "Tests") else None
            result.append(SwiftFile(str(rel), raw, strip_swift(raw), target))
        return result


# ---------------------------------------------------------------- 字句


def strip_swift(src: str, keep_strings: bool = False) -> str:
    """コメントと（既定では）文字列リテラルを空白にする。文字列補間 \\( ... ) の中はコードとして残す。"""
    out = list(src)
    n = len(src)

    def blank(a: int, b: int) -> None:
        for k in range(a, min(b, n)):
            if out[k] != "\n":
                out[k] = " "

    def code(i: int, stop_at_paren: bool) -> int:
        depth = 0
        while i < n:
            c = src[i]
            if src.startswith("//", i):
                j = src.find("\n", i)
                j = n if j < 0 else j
                blank(i, j)
                i = j
            elif src.startswith("/*", i):
                j, level = i + 2, 1
                while j < n and level:
                    if src.startswith("/*", j):
                        level, j = level + 1, j + 2
                    elif src.startswith("*/", j):
                        level, j = level - 1, j + 2
                    else:
                        j += 1
                blank(i, j)
                i = j
            elif c == "#" and re.match(r'#+"', src[i:]):
                i = raw_string(i)
            elif c == '"':
                i = string(i)
            elif stop_at_paren and c == "(":
                depth += 1
                i += 1
            elif stop_at_paren and c == ")":
                if depth == 0:
                    return i + 1
                depth -= 1
                i += 1
            else:
                i += 1
        return i

    def string(i: int) -> int:
        multi = src.startswith('"""', i)
        delim = '"""' if multi else '"'
        start = i
        i += len(delim)
        while i < n:
            if src[i] == "\\" and i + 1 < n and src[i + 1] == "(":
                if not keep_strings:
                    blank(start, i + 2)
                i = code(i + 2, True)
                start = i - 1
            elif src[i] == "\\":
                i += 2
            elif src.startswith(delim, i):
                if not keep_strings:
                    blank(start, i + len(delim))
                return i + len(delim)
            elif src[i] == "\n" and not multi:
                break
            else:
                i += 1
        if not keep_strings:
            blank(start, i)
        return i

    def raw_string(i: int) -> int:
        hashes = len(re.match(r"#+", src[i:]).group(0))
        multi = src.startswith('"""', i + hashes)
        end = ('"""' if multi else '"') + "#" * hashes
        j = src.find(end, i + hashes + (3 if multi else 1))
        j = n if j < 0 else j + len(end)
        if not keep_strings:
            blank(i, j)
        return j

    code(0, False)
    return "".join(out)


def line_of(text: str, index: int) -> int:
    return text.count("\n", 0, index) + 1


def balanced(text: str, open_index: int) -> tuple[str, int]:
    """text[open_index] が開き括弧のとき、対応する閉じ括弧までの中身と閉じ位置を返す。"""
    pairs = {"(": ")", "[": "]", "{": "}"}
    opener = text[open_index]
    closer = pairs[opener]
    depth = 0
    for k in range(open_index, len(text)):
        if text[k] == opener:
            depth += 1
        elif text[k] == closer:
            depth -= 1
            if depth == 0:
                return text[open_index + 1:k], k
    return text[open_index + 1:], len(text)


def split_top(text: str) -> list[str]:
    items, depth, cur = [], 0, []
    for c in text:
        if c in "([{":
            depth += 1
        elif c in ")]}":
            depth -= 1
        if c == "," and depth == 0:
            items.append("".join(cur))
            cur = []
        else:
            cur.append(c)
    items.append("".join(cur))
    return [" ".join(i.split()) for i in items if i.strip()]


def scan(sf: SwiftFile, pattern: re.Pattern[str], rule: str, message: str) -> list[Violation]:
    return [Violation(rule, sf.rel, line_of(sf.code, m.start()), message) for m in pattern.finditer(sf.code)]


def call_lacks_using(sf: SwiftFile, name: str, rule: str, message: str) -> list[Violation]:
    found = []
    for m in re.finditer(rf"(?<![\w]){name}\s*\(", sf.code):
        inner, _ = balanced(sf.code, m.end() - 1)
        if "using:" not in inner:
            found.append(Violation(rule, sf.rel, line_of(sf.code, m.start()), message))
    return found


# ---------------------------------------------------------------- グラフと manifest


def load_graph(ctx: Context) -> tuple[dict[str, GraphTarget], list[Violation]]:
    targets: dict[str, GraphTarget] = {}
    problems: list[Violation] = []
    if not ctx.exists(GRAPH_FILE):
        return targets, [Violation("CNF-010", str(GRAPH_FILE), 1, "依存グラフの正本が無い")]
    for no, line in enumerate(ctx.read(GRAPH_FILE).splitlines(), 1):
        body = line.split("#", 1)[0].strip()
        if not body:
            continue
        name, *pairs = body.split()
        fields = dict(p.split("=", 1) for p in pairs if "=" in p)
        if set(fields) - {"kind", "deps", "std", "role", "unsafe", "spawn"} or "kind" not in fields:
            problems.append(Violation("CNF-010", str(GRAPH_FILE), no, f"読めない行: {body}"))
            continue
        targets[name] = GraphTarget(
            name=name,
            kind=fields["kind"],
            deps=tuple(d for d in fields.get("deps", "").split(",") if d),
            std=tuple(s for s in fields.get("std", "").split(",") if s),
            composition_root=fields.get("role") == "composition-root",
            unsafe_allowed=fields.get("unsafe") == "allowed",
            spawn_allowed=fields.get("spawn") == "allowed",
        )
    return targets, problems


def load_package(ctx: Context) -> tuple[str, list[PackageTarget]]:
    raw = strip_swift(ctx.read("Package.swift"), keep_strings=True)
    kinds = {"target": "library", "executableTarget": "executable", "testTarget": "test"}
    found = []
    for m in re.finditer(r"\.(target|executableTarget|testTarget)\s*\(", raw):
        body, _ = balanced(raw, m.end() - 1)
        name = re.search(r'name:\s*"([^"]+)"', body)
        deps_m = re.search(r"dependencies:\s*\[", body)
        deps_body = balanced(body, deps_m.end() - 1)[0] if deps_m else ""
        set_m = re.search(r"swiftSettings:\s*\[", body)
        settings = tuple(split_top(balanced(body, set_m.end() - 1)[0])) if set_m else ()
        found.append(PackageTarget(
            name=name.group(1) if name else "?",
            kind=kinds[m.group(1)],
            deps=tuple(split_top(deps_body)),
            settings=settings,
            body=body,
            line=line_of(raw, m.start()),
        ))
    return raw, found


# ---------------------------------------------------------------- 規則

BANNED_SUFFIXES = ("Manager", "Helper", "Util", "Utils", "Common")
BANNED_DIRS = {"utils", "helpers", "managers", "misc", "common"}
TYPE_DECL = re.compile(r"\b(?:class|struct|enum|protocol|actor|typealias)\s+([A-Za-z_]\w*)")


def cnf001(ctx: Context) -> list[Violation]:
    """総称名の禁止（SWF-010）。"""
    found = []
    for sf in ctx.swift_files():
        for m in TYPE_DECL.finditer(sf.code):
            if m.group(1).endswith(BANNED_SUFFIXES):
                found.append(Violation("CNF-001", sf.rel, line_of(sf.code, m.start()), f"総称名の型 {m.group(1)}"))
        for part in Path(sf.rel).parts[:-1]:
            if part.lower() in BANNED_DIRS:
                found.append(Violation("CNF-001", sf.rel, 1, f"総称名のディレクトリ {part}"))
    if ctx.exists("Package.swift"):
        for t in load_package(ctx)[1]:
            if t.name.lower() in BANNED_DIRS or t.name.endswith(BANNED_SUFFIXES):
                found.append(Violation("CNF-001", "Package.swift", t.line, f"総称名の target {t.name}"))
    return found


TOP_DECL = re.compile(
    r"^\s*(?:@\w+(?:\([^)]*\))?\s+)*(?:(?:public|package|internal|fileprivate|private|final|indirect|nonisolated)\s+)*"
    r"(?:class|struct|enum|protocol|actor)\s+([A-Za-z_]\w*)"
)


def cnf002(ctx: Context) -> list[Violation]:
    """1 ファイル 1 主要宣言・ファイル名＝型名（SWF-011）。"""
    found = []
    for sf in ctx.swift_files():
        if sf.rel == "Package.swift":
            continue
        depth, decls = 0, []
        for no, line in enumerate(sf.code.splitlines(), 1):
            m = TOP_DECL.match(line)
            if depth == 0 and m:
                decls.append((no, m.group(1)))
            depth += line.count("{") - line.count("}")
        stem = Path(sf.rel).stem
        if len(decls) > 1:
            names = ", ".join(n for _, n in decls)
            found.append(Violation("CNF-002", sf.rel, decls[1][0], f"主要宣言が {len(decls)} 個ある: {names}"))
        elif len(decls) == 1 and decls[0][1] != stem:
            found.append(Violation("CNF-002", sf.rel, decls[0][0], f"ファイル名 {stem} と型名 {decls[0][1]} が違う"))
    return found


WAIVER_LINE = re.compile(r"^\s*//\s*Waiver:\s*(WVR-\d{4})\s*$")
LINT_TOOL = "swift" + "lint"
FORMAT_IGNORE = "swift-format" + "-ignore"


def cnf003(ctx: Context) -> list[Violation]:
    """抑制は行単位で waiver を伴うものだけ（SWF-015）。"""
    found = []
    waivers = {w["id"]: w for w in load_waivers(ctx)[0]}
    disable = re.compile(LINT_TOOL + r":(disable|enable)(:next|:this|:previous)?\s*([\w\s]*)")
    for sf in ctx.swift_files():
        lines = sf.raw.splitlines()
        for no, line in enumerate(lines, 1):
            if FORMAT_IGNORE in line:
                found.append(Violation("CNF-003", sf.rel, no, "swift-format の抑制は waiver があっても使えない"))
            for m in disable.finditer(line):
                verb, scope, rules = m.group(1), m.group(2), m.group(3).split()
                if verb == "enable" or scope not in (":next", ":this"):
                    found.append(Violation("CNF-003", sf.rel, no, "範囲の抑制（disable / enable）は使えない。:next か :this だけ"))
                    continue
                if not rules or "all" in rules:
                    found.append(Violation("CNF-003", sf.rel, no, "抑制する規則を名指しする（all は使えない）"))
                    continue
                prev = WAIVER_LINE.match(lines[no - 2]) if no >= 2 else None
                waiver = waivers.get(prev.group(1)) if prev else None
                if waiver is None:
                    found.append(Violation("CNF-003", sf.rel, no, "直前行に有効な // Waiver: WVR-NNNN が無い"))
                elif waiver["Status"] != "active" or not waiver["Scope"].split("#", 1)[0] == sf.rel:
                    found.append(Violation("CNF-003", sf.rel, no, f"{waiver['id']} は active でないか、Scope がこのファイルでない"))
        found += scan(sf, re.compile(r"@(?:diagnose|warn)\s*\("), "CNF-003", "@diagnose / @warn による警告の抑制")
        for m in re.finditer(r"@available\s*\(", sf.code):
            inner, _ = balanced(sf.code, m.end() - 1)
            if "deprecated" in inner:
                found.append(Violation("CNF-003", sf.rel, line_of(sf.code, m.start()), "@available(..., deprecated) は非推奨の警告を隠す"))
    return found


def load_waivers(ctx: Context) -> tuple[list[dict[str, str]], list[Violation]]:
    waivers, problems = [], []
    folder = ctx.root / "docs/waivers"
    if not folder.is_dir():
        return waivers, problems
    for path in sorted(folder.glob("*.md")):
        rel = str(path.relative_to(ctx.root))
        if path.name in ("README.md", "0000-template.md"):
            continue
        m = re.fullmatch(r"(WVR-\d{4})-[a-z0-9-]+\.md", path.name)
        if not m:
            problems.append(Violation("CNF-004", rel, 1, "waiver の名前は WVR-NNNN-short-kebab-title.md"))
            continue
        text = path.read_text(encoding="utf-8")
        fields = {"id": m.group(1)}
        for field in WAIVER_FIELDS:
            fm = re.search(rf"^- {field}:\s*`?([^`\n]+?)`?\s*$", text, re.M)
            if fm is None:
                problems.append(Violation("CNF-004", rel, 1, f"必須項目 {field} が無い"))
            else:
                fields[field] = fm.group(1)
        if all(f in fields for f in WAIVER_FIELDS):
            waivers.append(fields)
    return waivers, problems


def cnf004(ctx: Context) -> list[Violation]:
    """waiver 台帳の整合と期限（SWF-015）。"""
    waivers, found = load_waivers(ctx)
    index_path = "docs/waivers/README.md"
    index = ctx.read(index_path) if ctx.exists(index_path) else ""
    listed = set(re.findall(r"^\| (WVR-\d{4}) \|", index, re.M))
    for w in waivers:
        rel = f"docs/waivers/{w['id']}"
        if w["Status"] not in ("proposed", "active", "expired", "removed"):
            found.append(Violation("CNF-004", rel, 1, f"Status が不正: {w['Status']}"))
        try:
            expires = dt.date.fromisoformat(w["Expires"])
        except ValueError:
            found.append(Violation("CNF-004", rel, 1, f"Expires が日付でない: {w['Expires']}"))
            continue
        if w["Status"] == "active" and expires < ctx.today:
            found.append(Violation("CNF-004", rel, 1, f"期限切れの waiver（{w['Expires']}）"))
        if w["Status"] == "active" and w["id"] not in listed:
            found.append(Violation("CNF-004", index_path, 1, f"{w['id']} が索引に無い"))
    known = {w["id"] for w in waivers}
    for wid in sorted(listed - known):
        found.append(Violation("CNF-004", index_path, 1, f"索引の {wid} に台帳のファイルが無い"))
    return found


BASE_WORD = "base" + "line"
GATE_WEAKENERS = (
    "--" + BASE_WORD,
    "--write-" + BASE_WORD,
    "-suppress-" + "warnings",
    "-no-warnings-" + "as-errors",
    "continue-on-" + "error",
    "|| " + "true",
    "set " + "+e",
)
IGNORABLE = {".build/", ".tools/", ".swiftpm/", ".release/", "__pycache__/"}
FORMAT_ALLOWED_KEYS = {"version", "indentation", "lineLength"}
LINT_FORBIDDEN_KEYS = ("excluded", "included", "disabled_rules", "opt_in_rules", BASE_WORD, "warning_threshold")


def gate_path_files(ctx: Context) -> list[Path]:
    """ゲートの経路を構成するファイル（Makefile・CI・フック・シェル・道具の設定・manifest）。"""
    picked = []
    for rel in ctx.files():
        s = str(rel)
        if (s in ("Makefile", "Package.swift", ".swiftlint.yml", ".swift-format")
                or s.startswith((".github/workflows/", ".githooks/"))
                or (s.startswith("eng/") and rel.suffix == ".sh")):
            picked.append(rel)
    return picked


def cnf005(ctx: Context) -> list[Violation]:
    """baseline とゲート無力化の禁止（QLT-003）。"""
    found = []
    for rel in ctx.files():
        if BASE_WORD in rel.name.lower():
            found.append(Violation("CNF-005", str(rel), 1, f"名前に {BASE_WORD} を含むファイル"))
    for rel in gate_path_files(ctx):
        for no, line in enumerate(ctx.read(rel).splitlines(), 1):
            for word in GATE_WEAKENERS:
                if word in line:
                    found.append(Violation("CNF-005", str(rel), no, f"ゲートを弱める記述 {word!r}"))
    if ctx.exists(".gitignore"):
        for no, line in enumerate(ctx.read(".gitignore").splitlines(), 1):
            if line.strip() and line.strip() not in IGNORABLE:
                found.append(Violation("CNF-005", ".gitignore", no, f"検査の対象から外れる無視の指定 {line.strip()!r}（生成物の置き場だけを無視する）"))
    if ctx.exists(".swiftlint.yml"):
        text = ctx.read(".swiftlint.yml")
        for no, line in enumerate(text.splitlines(), 1):
            key = re.match(r"^([A-Za-z_]+)\s*:", line)
            if key and key.group(1) in LINT_FORBIDDEN_KEYS:
                found.append(Violation("CNF-005", ".swiftlint.yml", no, f"SwiftLint の設定 {key.group(1)} は使えない"))
        if not re.search(r"^strict:\s*true\s*$", text, re.M):
            found.append(Violation("CNF-005", ".swiftlint.yml", 1, "strict: true が無い"))
    if ctx.exists(".swift-format"):
        try:
            keys = set(json.loads(ctx.read(".swift-format")))
        except (ValueError, TypeError):
            keys = {"（JSON として読めない）"}
        for key in sorted(keys - FORMAT_ALLOWED_KEYS):
            found.append(Violation("CNF-005", ".swift-format", 1, f"swift-format の設定 {key} は使えない（規則の無効化はリポジトリ全体の抑制になる・M8-j）"))
    return found


DEF_HEADING = re.compile(r"^### ((?:ARC|SWF|QLT|CNF|GIT)-\d{3}) — ", re.M)
CNF_ROW = re.compile(r"^\| `(CNF-\d{3})` \|[^|]*\|[^|]*\| (\S+) \|", re.M)
ENFORCED = re.compile(r"^- 機械強制: \*\*(\S+?)\*\*", re.M)


def cnf006(ctx: Context) -> list[Violation]:
    """文書整合（ADR 0001）: 定義・マトリクス・本文の状態・参照・証明行。"""
    found: list[Violation] = []
    definitions: dict[str, tuple[str, int]] = {}
    body_state: dict[str, str] = {}
    docs = sorted(p.relative_to(ctx.root) for p in (ctx.root / "docs").glob("*.md"))
    for rel in docs:
        text = ctx.read(rel)
        heads = list(DEF_HEADING.finditer(text))
        for k, m in enumerate(heads):
            rid = m.group(1)
            if rid in definitions:
                found.append(Violation("CNF-006", str(rel), line_of(text, m.start()), f"{rid} の定義が重複（先: {definitions[rid][0]}）"))
            definitions[rid] = (str(rel), line_of(text, m.start()))
            end = heads[k + 1].start() if k + 1 < len(heads) else len(text)
            section = re.split(r"^## ", text[m.end():end], maxsplit=1, flags=re.M)[0]
            states = ENFORCED.findall(section)
            if len(states) != 1:
                found.append(Violation("CNF-006", str(rel), line_of(text, m.start()), f"{rid} の「機械強制」行は 1 つ（{len(states)} 個ある）"))
            else:
                body_state[rid] = states[0]
        for m in CNF_ROW.finditer(text):
            rid = m.group(1)
            if rid in definitions:
                found.append(Violation("CNF-006", str(rel), line_of(text, m.start()), f"{rid} の定義が重複"))
            definitions[rid] = (str(rel), line_of(text, m.start()))
            body_state[rid] = m.group(2)
    gates = "docs/QUALITY_GATES.md"
    matrix: dict[str, str] = {}
    if ctx.exists(gates):
        text = ctx.read(gates)
        part = re.search(r"^## 3\. 強制マトリクス\n(.*?)(?=^## )", text, re.M | re.S)
        rows = part.group(1) if part else ""
        offset = line_of(text, part.start(1)) - 1 if part else 0
        for no, line in enumerate(rows.splitlines(), offset + 1):
            m = re.match(r"^\| ((?:ARC|SWF|QLT|CNF|GIT)-\d{3}) \| ([^|]+?) \|", line)
            if not m:
                continue
            rid, state = m.group(1), m.group(2)
            if rid in matrix:
                found.append(Violation("CNF-006", gates, no, f"{rid} のマトリクス行が重複"))
            matrix[rid] = state
            if state not in STATES:
                found.append(Violation("CNF-006", gates, no, f"{rid} の状態 {state} は active / planned / 不能 / 不採用 のどれでもない"))
            if rid not in definitions:
                found.append(Violation("CNF-006", gates, no, f"マトリクスの {rid} に本文の定義が無い"))
    for rid, (rel, no) in sorted(definitions.items()):
        if rid not in matrix:
            found.append(Violation("CNF-006", rel, no, f"{rid} にマトリクスの行が無い"))
        elif rid in body_state and body_state[rid] != matrix[rid]:
            found.append(Violation("CNF-006", rel, no, f"{rid} の状態が本文（{body_state[rid]}）とマトリクス（{matrix[rid]}）で違う"))
    proofs_path = "docs/quality/gate-proofs.md"
    proofs = ctx.read(proofs_path) if ctx.exists(proofs_path) else ""
    rows = {m.group(1): m.group(2) for m in re.finditer(r"^\| ((?:ARC|SWF|QLT|CNF|GIT)-\d{3}) \|(.*)$", proofs, re.M)}
    for rid, state in sorted(matrix.items()):
        if state != "active":
            continue
        if rid not in rows:
            found.append(Violation("CNF-006", gates, 1, f"active の {rid} に gate-proofs の証明行（| {rid} |）が無い"))
        elif proof_evidence(rows[rid]) in ("", "未実測"):
            found.append(Violation("CNF-006", proofs_path, 1, f"active の {rid} の証明行に実測が書かれていない（空の行は証明ではない）"))
    for rel in reference_files(ctx):
        text = ctx.read(rel)
        for m in RULE_ID.finditer(text):
            if m.group(0) not in definitions:
                found.append(Violation("CNF-006", str(rel), line_of(text, m.start()), f"未定義の規則 ID {m.group(0)}"))
    return found


def proof_evidence(rest: str) -> str:
    """証明行の `| 規則 |` より後ろから、最後の列（実測）を取り出す。"""
    cells = rest.rstrip().rstrip("|").split("|")
    return cells[-1].strip() if len(cells) >= 3 else ""


def reference_files(ctx: Context) -> list[Path]:
    picked = []
    for rel in ctx.files():
        s = str(rel)
        if s.startswith("eng/tests/") or rel.suffix not in (".md", ".swift", ".py", ".yml", ".sh", ".txt", ""):
            continue
        picked.append(rel)
    return picked


def cnf007(ctx: Context) -> list[Violation]:
    """置いた検査設定が実際にゲートから読み込まれていること（QLT-007）。"""
    found = []
    for rel in ctx.files():
        if rel.name in CONFIG_NAMES and str(rel) not in CONFIG_FILES:
            found.append(Violation("CNF-007", str(rel), 1, "ゲートが読まない場所の検査設定（入れ子の設定は道具が勝手に拾う）"))
    makefile = ctx.read("Makefile") if ctx.exists("Makefile") else ""
    for name, flag in CONFIG_FILES.items():
        if not ctx.exists(name):
            found.append(Violation("CNF-007", name, 1, "検査設定が無い"))
        elif flag not in makefile:
            found.append(Violation("CNF-007", "Makefile", 1, f"{name} をゲートが明示的に渡していない（{flag}）"))
    if ctx.exists(".swiftlint.yml"):
        text = ctx.read(".swiftlint.yml")
        block = re.search(r"^only_rules:\n((?:\s+-.*\n?)+)", text, re.M)
        if block is None:
            found.append(Violation("CNF-007", ".swiftlint.yml", 1, "only_rules で規則を 1 つずつ名指しする"))
        else:
            start = line_of(text, block.start(1))
            for no, line in enumerate(block.group(1).splitlines(), start):
                if not RULE_ID.search(line.split("#", 1)[1] if "#" in line else ""):
                    found.append(Violation("CNF-007", ".swiftlint.yml", no, "有効にした規則に規則 ID のコメント（# SWF-NNN）が無い"))
    return found


TODO_WORDS = "TO" + "DO", "FIX" + "ME"


def cnf008(ctx: Context) -> list[Violation]:
    """TODO / FIXME には Issue 番号。"""
    found = []
    pattern = re.compile(r"\b(" + "|".join(TODO_WORDS) + r")\b(?!\s*\(#\d+\))")
    for rel in ctx.files():
        s = str(rel)
        if rel.suffix == ".swift" or rel in gate_path_files(ctx) or (s.startswith("eng/") and not s.startswith("eng/tests/")):
            for no, line in enumerate(ctx.read(rel).splitlines(), 1):
                if pattern.search(line) and rel.name != "conformance.py":
                    found.append(Violation("CNF-008", s, no, "TODO / FIXME の直後に (#Issue番号) が無い"))
    return found


def cnf009(ctx: Context) -> list[Violation]:
    """manifest の警告設定・依存の許可制（QLT-002 / QLT-011）。"""
    if not ctx.exists("Package.swift"):
        return [Violation("CNF-009", "Package.swift", 1, "Package.swift が無い")]
    raw, targets = load_package(ctx)
    found = []
    for word, why in (("unsafeFlags", "unsafeFlags はコンパイラの指定を素通しする"),
                      ("treatWarning(", "警告群ごとの重大度の変更"),
                      ("as: .warning", "警告を警告のまま残す指定"),
                      ("plugins:", "ビルド時のコード生成（SWF-009）"),
                      ("cSettings", "C の設定"), ("linkerSettings", "リンカの設定")):
        for m in re.finditer(re.escape(word), raw):
            found.append(Violation("CNF-009", "Package.swift", line_of(raw, m.start()), f"使えない manifest の指定: {why}"))
    if not re.search(r"swiftLanguageModes:\s*\[\s*\.v6\s*\]", raw):
        found.append(Violation("CNF-009", "Package.swift", 1, "swiftLanguageModes: [.v6] が無い"))
    allowed = set()
    if ctx.exists(ALLOWLIST_FILE):
        allowed = {ln.strip() for ln in ctx.read(ALLOWLIST_FILE).splitlines() if ln.strip() and not ln.startswith("#")}
    for m in re.finditer(r"\.package\s*\(", raw):
        body, _ = balanced(raw, m.end() - 1)
        url = re.search(r'url:\s*"([^"]+)"', body)
        if not url or url.group(1) not in allowed:
            found.append(Violation("CNF-009", "Package.swift", line_of(raw, m.start()), "許可リストに無い外部パッケージ"))
    for t in targets:
        settings = set(t.settings)
        for need in CANONICAL_SETTINGS:
            if need not in settings:
                found.append(Violation("CNF-009", "Package.swift", t.line, f"target {t.name} に {need} が無い"))
        for s in settings - set(CANONICAL_SETTINGS):
            if not re.fullmatch(r'\.enableUpcomingFeature\("\w+"\)', s):
                found.append(Violation("CNF-009", "Package.swift", t.line, f"target {t.name} の使えない swiftSettings: {s}"))
        for key in ("path:", "exclude:", "sources:", "resources:"):
            if re.search(rf"\b{key}", t.body):
                found.append(Violation("CNF-009", "Package.swift", t.line, f"target {t.name} の {key} はディレクトリの対応を崩す"))
        for d in t.deps:
            if not re.fullmatch(r'"[\w-]+"', d):
                found.append(Violation("CNF-009", "Package.swift", t.line, f"target {t.name} の依存は target 名の文字列だけ: {d}"))
    return found


def cnf010(ctx: Context) -> list[Violation]:
    """SwiftPM の target グラフと依存グラフの正本の一致（ARC-002）。"""
    graph, found = load_graph(ctx)
    gfile = str(GRAPH_FILE)
    for g in graph.values():
        for d in g.deps:
            if d not in graph:
                found.append(Violation("CNF-010", gfile, 1, f"{g.name} の依存 {d} がグラフに無い"))
    state: dict[str, int] = {}

    def visit(name: str, trail: list[str]) -> None:
        if state.get(name) == 2 or name not in graph:
            return
        if state.get(name) == 1:
            found.append(Violation("CNF-010", gfile, 1, "グラフに循環: " + " -> ".join(trail + [name])))
            return
        state[name] = 1
        for d in graph[name].deps:
            visit(d, trail + [name])
        state[name] = 2

    for name in graph:
        visit(name, [])
    roots = [g.name for g in graph.values() if g.composition_root]
    if len(roots) > 1:
        found.append(Violation("CNF-010", gfile, 1, f"合成ルートが複数ある: {', '.join(roots)}"))
    if not ctx.exists("Package.swift"):
        return found
    for t in load_package(ctx)[1]:
        g = graph.get(t.name)
        if g is None:
            found.append(Violation("CNF-010", "Package.swift", t.line, f"target {t.name} が依存グラフの正本に無い"))
            continue
        if g.kind != t.kind:
            found.append(Violation("CNF-010", "Package.swift", t.line, f"target {t.name} の種類 {t.kind} が正本（{g.kind}）と違う"))
        declared = {d.strip('"') for d in t.deps}
        if declared != set(g.deps):
            extra = ", ".join(sorted(declared - set(g.deps))) or "なし"
            missing = ", ".join(sorted(set(g.deps) - declared)) or "なし"
            found.append(Violation("CNF-010", "Package.swift", t.line, f"target {t.name} の依存が正本と違う（余分: {extra} / 不足: {missing}）"))
    return found


IMPORT = re.compile(r"^\s*(?:@\w+\s+)*import\s+(?:(?:typealias|struct|class|enum|protocol|let|var|func)\s+)?([A-Za-z_]\w*)", re.M)


def cnf011(ctx: Context) -> list[Violation]:
    """target ごとの import 許可リスト（ARC-003 / SWF-014 / SWF-016）。"""
    graph, _ = load_graph(ctx)
    found = []
    for sf in ctx.swift_files():
        if sf.rel == "Package.swift" or not sf.rel.startswith(("Sources/", "Tests/")):
            continue
        g = graph.get(sf.target or "")
        if g is None:
            found.append(Violation("CNF-011", sf.rel, 1, f"依存グラフの正本に無い target のディレクトリ {sf.target}"))
            continue
        allowed = set(g.deps) | set(g.std)
        for m in IMPORT.finditer(sf.code):
            if m.group(1) not in allowed:
                found.append(Violation("CNF-011", sf.rel, line_of(sf.code, m.start()), f"{g.name} は {m.group(1)} を import できない"))
    return found


DETERMINISM = re.compile(
    r"\b(SystemRandomNumberGenerator|ContinuousClock|SuspendingClock|CommandLine|ProcessInfo|Date|Locale|TimeZone|"
    r"DispatchTime|DispatchWallTime|getenv|setenv|environ|clock_gettime|gettimeofday|arc4random\w*)\b|(?<![\w.])time\s*\("
)


def non_root(ctx: Context) -> list[tuple[SwiftFile, GraphTarget]]:
    graph, _ = load_graph(ctx)
    return [(sf, graph[sf.target]) for sf in ctx.swift_files() if sf.target in graph and not graph[sf.target].composition_root]


def cnf012(ctx: Context) -> list[Violation]:
    """時刻・乱数・環境・プロセス状態は合成ルートだけ（ARC-007）。"""
    found = []
    for sf, _ in non_root(ctx):
        found += scan(sf, DETERMINISM, "CNF-012", "時刻・乱数・環境・プロセス状態は合成ルートだけが読む")
        for name in ("random", "randomElement", "shuffled", "shuffle"):
            found += call_lacks_using(sf, rf"\.?{name}", "CNF-012", f"{name}(...) は using: で乱数源を受け取る")
    return found


CATCH_ALL = re.compile(r"^\s*(?:default\s*:|@unknown\s+default\b)", re.M)
CASE_LABEL = re.compile(r"^[ \t]*case\b", re.M)
IDENT = re.compile(r"[A-Za-z_]\w*")


def case_items(code: str, start: int) -> list[str] | None:
    """`case` の直後から、switch のラベルの選択肢を最上位の `,` で分けて返す。ラベルでなければ（enum の case 宣言など）None。"""
    depth, i, last = 0, start, ""
    while i < len(code):
        ch = code[i]
        if ch in "([{":
            depth += 1
        elif ch in ")]}":
            depth -= 1
            if depth < 0:
                return None
        elif ch == ":" and depth == 0:
            return split_top(code[start:i])
        elif ch == "=" and depth == 0:
            return None
        elif ch == "\n" and depth == 0 and last != ",":
            return None
        if not ch.isspace():
            last = ch
        i += 1
    return None


def irrefutable(pattern: str, binding: bool = False) -> bool:
    """必ず一致するパターン（`_`・束縛・それだけを並べたタプル）か。`where` の付いたものは条件付きなので含めない。"""
    p = pattern.strip()
    if re.search(r"\bwhere\b", p):
        return False
    m = re.fullmatch(r"(?:let|var)\s+(.*)", p, re.S)
    if m:
        return irrefutable(m.group(1), True)
    if p == "_" or (binding and IDENT.fullmatch(p)):
        return True
    if p.startswith("(") and balanced(p, 0)[1] == len(p) - 1:
        inner = split_top(balanced(p, 0)[0])
        return bool(inner) and all(irrefutable(x, binding) for x in inner)
    return False


def cnf013(ctx: Context) -> list[Violation]:
    """網羅性検査を殺す全捕捉の禁止（SWF-002）。並べた選択肢の中の `_` と括弧で包んだ束縛も見る（M1-j・M1-k）。"""
    found = []
    message = "全捕捉（default / @unknown default / case _ / case let x / 括弧や並びに隠れた _ と束縛）は網羅性検査を殺す"
    for sf in ctx.swift_files():
        found += scan(sf, CATCH_ALL, "CNF-013", message)
        for m in CASE_LABEL.finditer(sf.code):
            items = case_items(sf.code, m.end())
            if items and any(irrefutable(item) for item in items):
                found.append(Violation("CNF-013", sf.rel, line_of(sf.code, m.start()), message))
    return found


UNSAFE = re.compile(r"(?i)\b(?:with)?unsafe\w*|@unchecked\b|\bUnmanaged\b")
MAGIC = re.compile(r"\bMirror\b|@_\w+|@preconcurrency\b|@dynamicMemberLookup|@dynamicCallable|#externalMacro|@attached|@freestanding|@objc\b|\bdlopen\b|\bdlsym\b")


def cnf014(ctx: Context) -> list[Violation]:
    """unsafe 系・リフレクション・マクロ（SWF-009）。unsafe 系は unsafe=allowed の target だけ。"""
    graph, _ = load_graph(ctx)
    found = []
    for sf in ctx.swift_files():
        g = graph.get(sf.target or "")
        if g is None or not g.unsafe_allowed:
            found += scan(sf, UNSAFE, "CNF-014", "unsafe 系の API は unsafe=allowed の target だけ")
        found += scan(sf, MAGIC, "CNF-014", "リフレクション・下線付き属性・@preconcurrency・マクロ・動的呼び出しは使えない")
    return found


def cnf015(ctx: Context) -> list[Violation]:
    """Codable の合成 init は唯一のファクトリを迂回する（SWF-007）。"""
    found = []
    for sf in ctx.swift_files():
        found += scan(sf, re.compile(r"\b(?:Codable|Decodable|Encodable)\b"), "CNF-015", "Codable / Decodable / Encodable は使えない")
    return found


PUBLIC_VAR = re.compile(r"^\s*(?:@\w+\s+)*public\s+(?:(?:static|final|nonisolated|lazy)\s+)*var\s+[^{\n]*$", re.M)


def cnf016(ctx: Context) -> list[Violation]:
    """公開の格納 var と open の禁止（SWF-003）。"""
    found = []
    for sf in ctx.swift_files():
        found += scan(sf, PUBLIC_VAR, "CNF-016", "public の格納 var は外から変更できる（let か private(set) にする）")
        found += scan(sf, re.compile(r"\bopen\s+(?:class|func|var|let|subscript)\b"), "CNF-016", "open は使えない")
    return found


PROCESS_IO = re.compile(r"(?<![\w.])(?:print|debugPrint|dump|readLine|exit|puts|fputs|printf)\s*\(|\bFileHandle\b")


def cnf017(ctx: Context) -> list[Violation]:
    """標準入出力への直書きと終了コードは合成ルートだけ（ARC-006）。"""
    found = []
    for sf, _ in non_root(ctx):
        found += scan(sf, PROCESS_IO, "CNF-017", "print / readLine / exit 等は合成ルートだけ")
    return found


def cnf018(ctx: Context) -> list[Violation]:
    """CI はゲートを 1 行呼ぶだけ・アクションは SHA 固定・token は contents: read（QLT-001 / QLT-005）。"""
    found = []
    workflows = [p for p in ctx.files() if str(p).startswith(".github/workflows/")]
    if not workflows:
        return [Violation("CNF-018", ".github/workflows", 1, "CI のワークフローが無い")]
    allowed_runs = {"eng/ci-require-ready.sh ${{ github.event.pull_request.draft }}", "eng/install-swift.sh",
                    "make check BASE=${{ github.event.pull_request.base.sha }}"}
    for rel in workflows:
        text = ctx.read(rel)
        s = str(rel)
        if not re.search(r"^permissions:\n  contents: read\n(?!  )", text, re.M):
            found.append(Violation("CNF-018", s, 1, "最上位の permissions は contents: read だけ"))
        if re.search(r":\s*write\b", text):
            found.append(Violation("CNF-018", s, 1, "書き込み権限を要求している"))
        for no, line in enumerate(text.splitlines(), 1):
            uses = re.match(r"^\s*(?:-\s*)?uses:\s*(\S+)", line)
            if uses and not re.fullmatch(r"[\w.-]+/[\w./-]+@[0-9a-f]{40}", uses.group(1)):
                found.append(Violation("CNF-018", s, no, f"アクションを commit SHA で固定していない: {uses.group(1)}"))
            if re.match(r"^\s*(?:-\s*)?if:", line):
                found.append(Violation("CNF-018", s, no, "if: は使えない（スキップされた必須 check は成功として数えられる）"))
            run = re.match(r"^\s*(?:-\s*)?run:\s*(.*)$", line)
            if run and run.group(1).strip() not in allowed_runs:
                found.append(Violation("CNF-018", s, no, f"CI で許す run はツールチェーン導入とゲートの 1 行だけ: {run.group(1).strip()}"))
    return found


def cnf019(ctx: Context) -> list[Violation]:
    """製品コードで例外を使わない（ARC-010 / SWF-005）。"""
    found = []
    for sf in ctx.swift_files():
        if sf.rel.startswith("Sources/"):
            found += scan(sf, re.compile(r"\b(?:throws|rethrows|throw|try|catch)\b"), "CNF-019", "期待される失敗は閉じた結果型で返す（throw / try / catch は使えない）")
    return found


def cnf020(ctx: Context) -> list[Violation]:
    """型を消す汎用の器の禁止（SWF-006）。"""
    found = []
    for sf in ctx.swift_files():
        found += scan(sf, re.compile(r"\b(?:Any|AnyObject|AnyHashable|AnyClass)\b"), "CNF-020", "Any / AnyObject / AnyHashable / AnyClass は使えない")
    return found


EXTENSION = re.compile(r"^[ \t]*(?:@\w+\s+)*(?:(?:public|package|internal|fileprivate|private)\s+)?extension\b[^{]*\{", re.M)
INIT_DECL = re.compile(
    r"^[ \t]*(?:@\w+(?:\([^)]*\))?\s+)*(?:(?:public|package|internal|fileprivate|private|convenience|required|nonisolated)\s+)*"
    r"init\s*[?!]?\s*[(<]", re.M
)


def cnf021(ctx: Context) -> list[Violation]:
    """init は型の本体にだけ書く（SWF-007）。別ファイルの extension の init は private init を経ずに格納プロパティを埋められる（M4-f）。"""
    found = []
    for sf in ctx.swift_files():
        for m in EXTENSION.finditer(sf.code):
            body, _ = balanced(sf.code, m.end() - 1)
            for d in INIT_DECL.finditer(body):
                found.append(Violation("CNF-021", sf.rel, line_of(sf.code, m.end() + d.start()), "extension に init を書かない（型の本体の唯一のファクトリを迂回できる）"))
    return found


CONCURRENCY = re.compile(
    r"\b(?:async|await|actor|Task|TaskGroup|ThrowingTaskGroup|Thread|DispatchQueue|DispatchGroup|DispatchSemaphore|OperationQueue|pthread_\w+)\b"
)


def cnf022(ctx: Context) -> list[Violation]:
    """並行性の形は 1 つ（SWF-013）。どの target でも async / Task / actor / スレッド / Dispatch を使わない（`Task.sleep` は時計も読む・M5-i）。"""
    found = []
    for sf in ctx.swift_files():
        found += scan(sf, CONCURRENCY, "CNF-022", "async / await / Task / actor / Thread / Dispatch は使えない（並行の形は合成ルートの 1 本のループだけ）")
    return found


SPAWN = re.compile(r"\b(?:posix_spawnp?|fork|vfork|exec[lv]p?e?|system|popen)\s*\(")


def cnf023(ctx: Context) -> list[Violation]:
    """外部プロセスの起動は spawn=allowed の target（Host）だけ（ADR 0004）。取得と翻訳の子プロセスを 1 か所に閉じ込める。"""
    graph, _ = load_graph(ctx)
    found = []
    for sf in ctx.swift_files():
        g = graph.get(sf.target or "")
        if g is None or not g.spawn_allowed:
            found += scan(sf, SPAWN, "CNF-023", "外部プロセスの起動（posix_spawn / fork / exec / system / popen）は spawn=allowed の target だけ")
    return found


CHECKS = (cnf001, cnf002, cnf003, cnf004, cnf005, cnf006, cnf007, cnf008, cnf009, cnf010,
          cnf011, cnf012, cnf013, cnf014, cnf015, cnf016, cnf017, cnf018, cnf019, cnf020,
          cnf021, cnf022, cnf023)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", default=str(Path(__file__).resolve().parent.parent))
    parser.add_argument("--today", default=None)
    args = parser.parse_args(argv)
    today = dt.date.fromisoformat(args.today) if args.today else dt.date.today()
    ctx = Context(Path(args.root), today)
    violations = sorted({v for check in CHECKS for v in check(ctx)}, key=lambda v: (v.rule, v.path, v.line, v.message))
    for v in violations:
        print(v.render())
    print(f"conformance: {len(CHECKS)} 規則・違反 {len(violations)} 件")
    return 1 if violations else 0


if __name__ == "__main__":
    sys.exit(main())

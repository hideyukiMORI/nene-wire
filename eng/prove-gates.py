#!/usr/bin/env python3
"""Phase 2: ゲートの negative proof（QLT-007）。docs/quality/gate-proofs.json に結果を書く。

作業木を一時ディレクトリへ複製し、証明ごとに最小の違反を 1 つだけ仕込んで `make check`（またはそれより狭いタスク）を回す。
「意図した規則 ID（または道具の規則名）で落ちること」を出力から確かめる。仕込まない複製（対照）では `make check` が
exit 0 になることも確かめる。作業木そのものには触れない。

違反を仕込むには Swift のソースが要るので、どの証明も同じ「足場」（依存グラフの正本どおりの 5 target・
規則に沿った最小のソース）を置いてから 1 か所だけ壊す。足場は証明のための一時物で、作業木には入れない。
作業木にある本物のソースはそのまま使い、足場は名前のぶつからない最小のファイルだけを足す（合成ルートの main.swift だけは置き換える）。
P09・P27 は本物の `Sources/NeNeWireRender/Cell.swift` の `public let glyph` を壊す。

移植元: NeNe Gambit eng/prove-gates.py（コミット 8c5b8f6 の足場の方式）。複製は git の一覧で作り、
このリポジトリで足した検査の証明（P55 以降）を足した（ADR 0003）。

    python3 eng/prove-gates.py [--only P01 P02 ...]
"""

from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from dataclasses import dataclass, field
from pathlib import Path
from typing import Callable

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "docs" / "quality" / "gate-proofs.json"
SETTINGS = 'swiftSettings: [.treatAllWarnings(as: .error), .enableUpcomingFeature("ExistentialAny")]'

TARGETS = {
    "NeNeWireCore": ("target", ""),
    "NeNeWireRender": ("target", '"NeNeWireCore"'),
    "NeNeWireTerminal": ("target", '"NeNeWireRender"'),
    "NeNeWireHost": ("target", '"NeNeWireCore"'),
    "nene-wire": ("executableTarget", '"NeNeWireCore", "NeNeWireRender", "NeNeWireTerminal", "NeNeWireHost"'),
    "NeNeWireCoreTests": ("testTarget", '"NeNeWireCore"'),
    "NeNeWireRenderTests": ("testTarget", '"NeNeWireCore", "NeNeWireRender"'),
    "NeNeWireTerminalTests": ("testTarget", '"NeNeWireRender", "NeNeWireTerminal"'),
    "NeNeWireHostTests": ("testTarget", '"NeNeWireCore", "NeNeWireHost"'),
}

SOURCES = {
    "Sources/NeNeWireCore/Square.swift": """\
/// 格子の位置。証明用の最小の型。
public struct Square: Hashable, Sendable {
    public let index: Int

    private init(index: Int) {
        self.index = index
    }

    /// 0〜63 の升を作る。範囲外なら nil。
    public static func make(_ index: Int) -> Square? {
        (0..<64).contains(index) ? Square(index: index) : nil
    }
}
""",
    "Sources/NeNeWireRender/Pick.swift": """\
import NeNeWireCore

/// 注入された乱数源から升を選ぶ。証明用の最小の型。
public enum Pick {
    /// 0..<count から 1 つ選ぶ。
    public static func square(count: Int, using generator: inout some RandomNumberGenerator) -> Square? {
        Square.make(Int.random(in: 0..<count, using: &generator))
    }
}
""",
    "Sources/NeNeWireTerminal/Screen.swift": """\
import Glibc

/// 端末の大きさを読む。unsafe 系 API を許す区画の証明用。
public enum Screen {
    /// 端末の桁数。読めなければ 0。
    public static func columns() -> Int {
        var size = winsize()
        let status = withUnsafeMutablePointer(to: &size) { pointer in
            ioctl(STDOUT_FILENO, UInt(TIOCGWINSZ), pointer)
        }
        return status == 0 ? Int(size.ws_col) : 0
    }
}
""",
    "Sources/NeNeWireHost/Child.swift": """\
import Glibc

/// 子プロセスを起動する。spawn=allowed の区画の証明用。
public enum Child {
    /// `/bin/true` を起動して pid を返す。起動できなければ -1。
    public static func start() -> Int32 {
        var pid: pid_t = 0
        guard let file = strdup("/bin/true") else {
            return -1
        }
        defer { free(file) }
        var argv: [UnsafeMutablePointer<CChar>?] = [file, nil]
        return posix_spawn(&pid, file, nil, nil, &argv, nil) == 0 ? pid : -1
    }
}
""",
    "Sources/nene-wire/main.swift": """\
import Glibc
import NeNeWireCore
import NeNeWireHost

let start = ContinuousClock.now
var generator = SystemRandomNumberGenerator()
let square = Square.make(Int.random(in: 0..<64, using: &generator))
let arguments = CommandLine.arguments.count
let home = getenv("HOME") != nil
print(square?.index ?? -1, arguments, home, Child.start(), ContinuousClock.now - start >= .zero)
""",
}


def package_swift(extra: dict[str, str] | None = None) -> str:
    """足場の Package.swift。extra は target 名 → 置き換える `.target(...)` の本文。"""
    lines = []
    for name, (kind, deps) in TARGETS.items():
        default = f'.{kind}(name: "{name}", dependencies: [{deps}], {SETTINGS})'
        lines.append((extra or {}).get(name, default))
    body = ",\n        ".join(lines)
    return (
        "// swift-tools-version: 6.2\n\nimport PackageDescription\n\nlet package = Package(\n"
        '    name: "NeNeWire",\n    targets: [\n        ' + body + "\n    ],\n"
        "    swiftLanguageModes: [.v6]\n)\n"
    )


@dataclass
class Proof:
    id: str
    rules: list[str]
    violation: str
    mutate: Callable[[Path], None]
    expect: str  # 出力に現れるべき正規表現（意図した規則 ID か道具の規則名）
    command: list[str] = field(default_factory=lambda: ["make", "check"])
    scaffold: bool = True
    expect_exit_zero: bool = False
    expect_all: list[str] = field(default_factory=list)  # 追加で、出力にすべて現れるべき正規表現


def write(root: Path, rel: str, text: str) -> None:
    path = root / rel
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")


def edit(root: Path, rel: str, old: str, new: str) -> None:
    path = root / rel
    text = path.read_text(encoding="utf-8")
    if old not in text:
        raise ValueError(f"{rel} に {old!r} が無い")
    path.write_text(text.replace(old, new, 1), encoding="utf-8")


def replace_line(root: Path, rel: str, pattern: str, new: str) -> None:
    path = root / rel
    text, count = re.subn(pattern, new, path.read_text(encoding="utf-8"), count=1, flags=re.M)
    if count != 1:
        raise ValueError(f"{rel} に {pattern!r} の行が無い")
    path.write_text(text, encoding="utf-8")


def core_file(name: str, text: str) -> Callable[[Path], None]:
    return lambda root: write(root, f"Sources/NeNeWireCore/{name}", text)


def nothing(root: Path) -> None:
    del root


def git_commit(root: Path, message: str, no_verify: bool) -> None:
    write(root, "docs/todo/note.md", "# 証明用\n")
    subprocess.run(["git", "-C", str(root), "add", "-A"], check=True, capture_output=True)
    cmd = ["git", "-C", str(root), "-c", "user.name=proof", "-c", "user.email=proof@example.invalid", "commit", "-q", "-m", message]
    if no_verify:
        cmd.insert(cmd.index("commit") + 1, "--no-verify")
    subprocess.run(cmd, check=True, capture_output=True)


SWITCH = """\
/// 色。証明用。
enum Side {
    case white
    case black
    case none
}

/// 色の値。
func value(of side: Side) -> Int {
    switch side {
    case .white:
        return 1
    case .black:
        return -1
    BODY
    }
}
"""

LINT_RULES = ["cyclomatic_complexity", "function_body_length", "function_parameter_count", "nesting", "file_length",
              "type_body_length", "force_unwrapping", "implicitly_unwrapped_optional", "discouraged_optional_boolean",
              "discouraged_optional_collection", "force_cast", "force_try", "large_tuple", "fallthrough", "superfluous_disable_command", "blanket_disable_command"]


def every_lint_rule() -> str:
    """有効にした SwiftLint の 16 規則それぞれの最小の違反を 1 ファイルに並べる（コンパイルは通る形）。"""
    lint = "swift" + "lint"
    body = ["/// 証明用。", "enum Probe {"]
    body += [f"    static let value{k} = {k}" for k in range(410)]
    body += ["", "    /// 証明用。", "    static func grade(_ v: Int) -> Int {"]
    body += [f"        if v == {k} {{\n            return {k}\n        }}" for k in range(11)]
    body += ["        return -1", "    }", "", "    /// 証明用。", "    static func long() -> Int {", "        var total = 0"]
    body += [f"        total += {k}" for k in range(61)]
    body += ["        return total", "    }", "",
             "    /// 証明用。", "    static func sum(_ a: Int, _ b: Int, _ c: Int, _ d: Int, _ e: Int) -> Int {", "        a + b + c + d + e", "    }", "",
             "    /// 証明用。", "    static func unwrap(_ v: Int?) -> Int {", "        v!", "    }", "",
             "    static let flag: Bool? = nil", "    static let list: [Int]? = nil", "",
             "    /// 証明用。", "    static func cast(_ v: Int) -> Int {", "        (v as Any) as! Int", "    }", "",
             "    /// 証明用。", "    static func risky() throws -> Int {", "        1", "    }", "",
             "    /// 証明用。", "    static func force() -> Int {", "        try! risky()", "    }", "",
             "    /// 証明用。", "    static func triple() -> (Int, Int, Int) {", "        (1, 2, 3)", "    }", "",
             "    /// 証明用。", "    static func fall(_ v: Int) -> Int {", "        var result = 0", "        switch v {", "        case 0:",
             "            result = 1", "            fallthrough", "        case 1:", "            result += 1", "        default:",
             "            result = 0", "        }", "        return result", "    }", "",
             "    /// 証明用。", "    struct Middle {", "        /// 証明用。", "        struct Inner {}", "    }", "", "    /// 証明用。",
             "    struct Holder {", "        var cache: Int!", "    }", "}", "", "let hidden = 1", "",
             f"// {lint}:disable:next force_cast", "let plain = hidden + 1", "", f"// {lint}:disable force_unwrapping", ""]
    return "\n".join(body)


PROOFS: list[Proof] = [
    Proof("P00", [], "対照: 足場だけ（違反なし）。合成ルートが時計・乱数・CommandLine・getenv・print を使い、Host が posix_spawn、Terminal が withUnsafe を使う",
          nothing, r"make check: 緑", expect_exit_zero=True),
    Proof("P00b", [], "対照: 足場を置かない作業木そのまま", nothing, r"make check: 緑", scaffold=False, expect_exit_zero=True),
    Proof("P01", ["ARC-002"], "Core が宣言していない Render を import する",
          core_file("Probe.swift", "import NeNeWireRender\n\n/// 証明用。\nenum Probe {}\n"), r"no such module 'NeNeWireRender'"),
    Proof("P02", ["ARC-002", "CNF-010", "QLT-006"], "Terminal が正本に無い Core への依存を宣言する（循環は作らない）",
          lambda r: write(r, "Package.swift", package_swift({"NeNeWireTerminal":
              f'.target(name: "NeNeWireTerminal", dependencies: ["NeNeWireRender", "NeNeWireCore"], {SETTINGS})'})),
          r"^CNF-010 Package\.swift"),
    Proof("P03", ["ARC-003", "CNF-011", "SWF-014", "QLT-006"], "Core が Foundation を import する",
          core_file("Probe.swift", "import Foundation\n\n/// 証明用。\nenum Probe {}\n"), r"^CNF-011 Sources/NeNeWireCore/Probe\.swift"),
    Proof("P04", ["ARC-007", "CNF-012"], "Render が using: の無い Int.random を呼ぶ",
          lambda r: edit(r, "Sources/NeNeWireRender/Pick.swift", "Int.random(in: 0..<count, using: &generator)",
                         "Int.random(in: 0..<count)"),
          r"^CNF-012 Sources/NeNeWireRender/Pick\.swift"),
    Proof("P05", ["ARC-007", "CNF-012"], "Core のテストが CommandLine.arguments を読む（テストにも禁止がかかる）",
          lambda r: write(r, "Tests/NeNeWireCoreTests/ProbeTests.swift",
                          "/// 証明用。\nenum ProbeTests {\n    static let count = CommandLine.arguments.count\n}\n"),
          r"^CNF-012 Tests/NeNeWireCoreTests/ProbeTests\.swift"),
    Proof("P06", ["SWF-002"], "enum に case を足し、switch を直さない",
          core_file("Side.swift", SWITCH.replace("    BODY\n", "")), r"error: switch must be exhaustive"),
    Proof("P07", ["SWF-002", "CNF-013"], "switch に default: を書く",
          core_file("Side.swift", SWITCH.replace("BODY", "default:\n        return 0")), r"^CNF-013 Sources/NeNeWireCore/Side\.swift"),
    Proof("P08", ["CNF-013"], "switch に case let other: を書く（default とも case _ とも書かない全捕捉）",
          core_file("Side.swift", SWITCH.replace("BODY", "case let other:\n        return other == .none ? 0 : 2")),
          r"^CNF-013 Sources/NeNeWireCore/Side\.swift"),
    Proof("P09", ["SWF-003", "CNF-016"], "公開の格納 var を置く",
          lambda r: edit(r, "Sources/NeNeWireRender/Cell.swift", "public let glyph", "public var glyph"),
          r"^CNF-016 Sources/NeNeWireRender/Cell\.swift"),
    Proof("P10", ["SWF-004"], "強制アンラップを書く",
          lambda r: edit(r, "Sources/nene-wire/main.swift", "square?.index ?? -1", "square!.index"),
          r"\(force_unwrapping\)"),
    Proof("P11", ["SWF-005", "CNF-019"], "製品コードに throws を書く",
          core_file("Probe.swift", "/// 証明用。\nenum Probe {\n    /// 証明用。\n    static func load() throws -> Int { 1 }\n}\n"),
          r"^CNF-019 Sources/NeNeWireCore/Probe\.swift"),
    Proof("P12", ["SWF-006", "CNF-020"], "Any を使う",
          core_file("Probe.swift", "/// 証明用。\nenum Probe {\n    /// 証明用。\n    static func box() -> Any { 1 }\n}\n"),
          r"^CNF-020 Sources/NeNeWireCore/Probe\.swift"),
    Proof("P13", ["SWF-006"], "要素 3 つのタプルを返す",
          core_file("Probe.swift", "/// 証明用。\nenum Probe {\n    /// 証明用。\n    static func triple() -> (Int, Int, Int) { (1, 2, 3) }\n}\n"),
          r"\(large_tuple\)"),
    Proof("P14", ["SWF-009", "CNF-014"], "Core で unsafeBitCast を使う",
          core_file("Probe.swift", "/// 証明用。\nenum Probe {\n    static let square = unsafeBitCast(99, to: Square.self)\n}\n"),
          r"^CNF-014 Sources/NeNeWireCore/Probe\.swift"),
    Proof("P15", ["SWF-010", "CNF-001"], "型を BoardHelper と名付ける",
          core_file("BoardHelper.swift", "/// 証明用。\nenum BoardHelper {}\n"), r"^CNF-001 Sources/NeNeWireCore/BoardHelper\.swift"),
    Proof("P16", ["SWF-011", "CNF-002"], "1 ファイルに最上位の型を 2 つ置く",
          core_file("Probe.swift", "/// 証明用。\nenum Probe {}\n\n/// 証明用。\nenum Other {}\n"), r"^CNF-002 Sources/NeNeWireCore/Probe\.swift"),
    Proof("P17", ["SWF-012"], "引数 5 つの関数を書く",
          core_file("Probe.swift", "/// 証明用。\nenum Probe {\n    /// 証明用。\n    static func sum(_ a: Int, _ b: Int, _ c: Int, _ d: Int, _ e: Int) -> Int {\n        a + b + c + d + e\n    }\n}\n"),
          r"\(function_parameter_count\)"),
    Proof("P18", ["SWF-012"], "循環的複雑度 11 の関数を書く（SwiftLint は if 11 個を 11 と数える）",
          core_file("Probe.swift", "/// 証明用。\nenum Probe {\n    /// 証明用。\n    static func grade(_ v: Int) -> Int {\n"
                    + "".join(f"        if v == {k} {{\n            return {k}\n        }}\n" for k in range(11))
                    + "        return -1\n    }\n}\n"),
          r"\(cyclomatic_complexity\)"),
    Proof("P19", ["SWF-015", "CNF-003"], "waiver 無しの swiftlint:disable:next で強制アンラップを抑制する",
          lambda r: edit(r, "Sources/nene-wire/main.swift", "print(square?.index ?? -1,",
                         "// " + "swift" + "lint:disable:next force_unwrapping\nprint(square!.index,"),
          r"^CNF-003 Sources/nene-wire/main\.swift"),
    Proof("P20", ["SWF-015", "CNF-003"], "@diagnose で非推奨の警告を消す",
          core_file("Probe.swift", "/// 証明用。\nenum Probe {\n    @available(*, deprecated)\n    static func old() -> Int { 1 }\n\n"
                    "    @diagnose(DeprecatedDeclaration, as: ignored)\n    static func use() -> Int { old() }\n}\n"),
          r"^CNF-003 Sources/NeNeWireCore/Probe\.swift"),
    Proof("P21", ["SWF-015", "CNF-004"], "期限切れの active な waiver を台帳と索引に置く",
          lambda r: (write(r, "docs/waivers/WVR-0001-proof.md",
                           "# WVR-0001: 証明用\n\n- Status: active\n- Rule: `SWF-004`\n- Issue: #1\n- Owner: hide\n"
                           "- Created: 2026-10-01\n- Expires: 2026-10-24\n- Scope: `Sources/nene-wire/main.swift`\n"),
                     edit(r, "docs/waivers/README.md", "| — | — | — | 有効な waiver は無い | — |",
                          "| WVR-0001 | SWF-004 | `Sources/nene-wire/main.swift` | 証明用 | 2026-10-24 |")),
          r"^CNF-004 docs/waivers/WVR-0001"),
    Proof("P22", ["SWF-016", "CNF-011"], "テストで XCTest を import する",
          lambda r: write(r, "Tests/NeNeWireCoreTests/ProbeTests.swift", "import XCTest\n\n/// 証明用。\nenum ProbeTests {}\n"),
          r"^CNF-011 Tests/NeNeWireCoreTests/ProbeTests\.swift"),
    Proof("P23", ["QLT-002", "CNF-009"], "target の警告設定を treatAllWarnings(as: .warning) に緩める（警告の出るコードは置かない。設定そのものを拒むこと）",
          lambda r: write(r, "Package.swift", package_swift({"NeNeWireCore":
              '.target(name: "NeNeWireCore", swiftSettings: [.treatAllWarnings(as: .warning), .enableUpcomingFeature("ExistentialAny")])'})),
          r"^CNF-009 Package\.swift"),
    Proof("P24", ["QLT-002"], "未使用のローカル定数を置く（警告がエラーになること）",
          core_file("Probe.swift", "/// 証明用。\nenum Probe {\n    /// 証明用。\n    static func run() -> Int {\n        let unused = 1\n        return 2\n    }\n}\n"),
          r"error: initialization of immutable value 'unused' was never used"),
    Proof("P25", ["QLT-003", "CNF-005"], "名前に baseline を含むファイルを置く",
          lambda r: write(r, "swiftlint-" + "base" + "line.json", "[]\n"), r"^CNF-005 swiftlint-"),
    Proof("P26", ["QLT-003", "CNF-005"], ".gitignore で Sources を検査から隠す",
          lambda r: (edit(r, ".gitignore", ".build/\n", ".build/\nSources/NeNeWireCore/Hidden.swift\n"),
                     write(r, "Sources/NeNeWireCore/Hidden.swift", "let x = 1\n")),
          r"^CNF-005 \.gitignore"),
    Proof("P27", ["QLT-004"], "インデントを 2 桁にする", lambda r: edit(r, "Sources/NeNeWireRender/Cell.swift",
          "    public let glyph", "  public let glyph"), r"\[Indentation\]"),
    Proof("P28", ["QLT-004", "CNF-007"], "Core のディレクトリに入れ子の .swiftlint.yml を置く",
          lambda r: write(r, "Sources/NeNeWireCore/.swiftlint.yml", "only_rules:\n  - force_cast # SWF-004\n"),
          r"^CNF-007 Sources/NeNeWireCore/\.swiftlint\.yml"),
    Proof("P29", ["CNF-007", "QLT-007"], "SourceKit が要る規則（statement_position）を有効にする（静的バイナリが黙って飛ばす）",
          lambda r: edit(r, ".swiftlint.yml", "  - blanket_disable_command # SWF-015\n",
                         "  - blanket_disable_command # SWF-015\n  - statement_position # SWF-012\n"),
          r"有効にした規則が実行されていない（CNF-007）"),
    Proof("P30", ["CNF-006"], "未定義の規則 ID を文書に書く",
          lambda r: edit(r, "docs/todo/current.md", "## 次の 1 手", UNDEFINED_ID + " を参照する。\n\n## 次の 1 手"),
          r"^CNF-006 docs/todo/current\.md"),
    Proof("P31", ["CNF-006"], "証明行の無い規則をマトリクスで active にする（本文も合わせて書き換える）",
          lambda r: (edit(r, "docs/QUALITY_GATES.md", "\n| QLT-008 | planned |", "\n| QLT-008 | active |"),
                     edit(r, "docs/QUALITY_GATES.md", "- 機械強制: **planned**（レビュー事項。テスト target", "- 機械強制: **active**（レビュー事項。テスト target")),
          r"^CNF-006 docs/QUALITY_GATES\.md:1: active の QLT-008"),
    Proof("P66", ["CNF-006"], "active の規則の証明行の実測を空にする（空の行は証明ではない）",
          lambda r: replace_line(r, "docs/quality/gate-proofs.md", r"^\| CNF-015 \|.*$", "| CNF-015 |  |  |  |"),
          r"^CNF-006 docs/quality/gate-proofs\.md:1: active の CNF-015 の証明行に実測が書かれていない"),
    Proof("P32", ["CNF-008"], "Issue 番号の無い作業メモ（" + "TO" + "DO）を書く",
          lambda r: edit(r, "Sources/NeNeWireCore/Square.swift", "/// 格子の位置。", "// " + "TO" + "DO あとで直す\n/// 格子の位置。"),
          r"^CNF-008 Sources/NeNeWireCore/Square\.swift"),
    Proof("P33", ["QLT-011", "CNF-009"], "許可リストに無い外部パッケージを manifest に書く（解決に行かせないため狭い検査で）",
          lambda r: edit(r, "Package.swift", "    targets: [",
                         '    dependencies: [.package(url: "https://github.com/example/wire-engine.git", exact: "1.0.0")],\n    targets: ['),
          r"^CNF-009 Package\.swift:\d+: 許可リストに無い外部パッケージ", command=["make", "conformance"]),
    Proof("P34", ["QLT-011"], "SwiftLint の lock の SHA-256 を 1 文字変え、道具を入れ直させる",
          lambda r: (edit(r, "eng/swiftlint.lock", "sha256=c", "sha256=d"), (r / ".tools").unlink()),
          r"(FAILED|did NOT match)", command=["make", "tools"]),
    Proof("P35", ["QLT-001", "CNF-018", "QLT-005"], "CI に make check 以外の run（swift build）を足す",
          lambda r: edit(r, ".github/workflows/ci.yml", "      - run: eng/install-swift.sh\n",
                         "      - run: eng/install-swift.sh\n      - run: swift build\n"),
          r"^CNF-018 \.github/workflows/ci\.yml"),
    Proof("P36", ["CNF-018"], "CI のアクションをタグで指す",
          lambda r: edit(r, ".github/workflows/ci.yml", "actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1", "actions/checkout@v7"),
          r"^CNF-018 \.github/workflows/ci\.yml"),
    Proof("P45", ["QLT-012", "CNF-018"], "CI のジョブに draft を飛ばす if: を書く（スキップは成功として数えられる）",
          lambda r: edit(r, ".github/workflows/ci.yml", "    runs-on:", "    if: ${{ !github.event.pull_request.draft }}\n    runs-on:"),
          r"^CNF-018 \.github/workflows/ci\.yml:\d+: if: は使えない"),
    Proof("P37", ["QLT-001"], ".swift-version を実際の版と違う 6.4.0 にする",
          lambda r: write(r, ".swift-version", "6.4.0\n"), r"tools: swift は 6\.4\.0 が要る"),
    Proof("P38", ["QLT-007"], "規約検査の CNF-013 の検出を壊す（検査器の単体テストが落ちること）",
          lambda r: edit(r, "eng/conformance.py", 'r"^\\s*(?:default\\s*:', 'r"^\\s*(?:NEVERMATCH\\s*:'),
          r"FAILED \(failures="),
    Proof("P39", ["CNF-015"], "Decodable を使う",
          core_file("Probe.swift", "/// 証明用。\nstruct Probe: Decodable {\n    let index: Int\n}\n"), r"^CNF-015 Sources/NeNeWireCore/Probe\.swift"),
    Proof("P40", ["CNF-017", "ARC-006"], "Core で print を呼ぶ",
          core_file("Probe.swift", "/// 証明用。\nenum Probe {\n    /// 証明用。\n    static func show() {\n        print(1)\n    }\n}\n"),
          r"^CNF-017 Sources/NeNeWireCore/Probe\.swift"),
    Proof("P41", ["GIT-003"], "形の合わないコミット（--no-verify でフックを迂回）",
          lambda r: git_commit(r, "update stuff", no_verify=True), r"GIT-003 [0-9a-f]{7}: 件名は"),
    Proof("P44", ["SWF-002", "SWF-004", "SWF-005", "SWF-006", "SWF-012", "SWF-015"],
          "有効にした SwiftLint の 16 規則それぞれの違反を 1 ファイルに置く（設定の全規則が実際に発火すること）",
          core_file("Probe.swift", every_lint_rule()), r"\((?:" + "|".join(LINT_RULES) + r")\)$",
          expect_all=[rf"\({rule}\)" for rule in LINT_RULES]),
    Proof("P47", ["QLT-002"], "ソースの無いテスト target を manifest に足す（SwiftPM 自身が警告を出し、コンパイラの警告エラーの外にある）",
          lambda r: (edit(r, "Package.swift", "    targets: [",
                          f'    targets: [\n        .testTarget(name: "NeNeWireProbeTests", dependencies: ["NeNeWireCore"], {SETTINGS}),'),
                     (r / "Tests/NeNeWireProbeTests").mkdir(parents=True)),
          r"swift-strict: SwiftPM かコンパイラが警告を出した"),
    Proof("P48", ["QLT-001"], "テストの期待値を 1 つ変える（make check の中で swift test が実際に回って落ちること）",
          lambda r: edit(r, "Tests/NeNeWireCoreTests/FetchTests.swift", '"2026-10-26T01:07:05Z"', '"2026-10-26T01:07:06Z"'),
          r"✘ Test datesInBothFormats"),
    Proof("P50", ["SWF-002"], "文字列の switch の全捕捉を case _ where true: と書く（CNF-013 の字句の外の書き方。コンパイラが網羅に数えないこと）",
          core_file("Probe.swift", "/// 証明用。\nenum Probe {\n    /// 証明用。\n    static func code(_ s: String) -> Int {\n"
                    "        switch s {\n        case \"a\":\n            return 1\n        case _ where true:\n            return 0\n        }\n    }\n}\n"),
          r"error: switch must be exhaustive"),
    Proof("P55", ["SWF-002", "CNF-013"], "switch に case (let other): を書く（括弧で包んだ束縛・M1-j）",
          core_file("Side.swift", SWITCH.replace("BODY", "case (let other):\n        return other == .none ? 0 : 2")),
          r"^CNF-013 Sources/NeNeWireCore/Side\.swift"),
    Proof("P56", ["SWF-002", "CNF-013"], "switch に case .none, _: を書く（並べた選択肢の中の _・M1-k）",
          core_file("Side.swift", SWITCH.replace("BODY", "case .none, _:\n        return 0")),
          r"^CNF-013 Sources/NeNeWireCore/Side\.swift"),
    Proof("P57", ["SWF-002", "CNF-013"], "タプルの switch に case (_, _): を書く（全位置が _ のタプル・M1-m）",
          core_file("Pair.swift", "/// 証明用。\nenum Pair {\n    case one\n    case two\n\n    /// 証明用。\n    static func both(_ a: Pair, _ b: Pair) -> Int {\n"
                    "        switch (a, b) {\n        case (.one, .one):\n            return 1\n        case (_, _):\n            return 0\n        }\n    }\n}\n"),
          r"^CNF-013 Sources/NeNeWireCore/Pair\.swift"),
    Proof("P58", ["SWF-007", "CNF-021"], "別ファイルの extension に init を足し、private init を経ずに Square を作る（M4-f）",
          core_file("Square+Bypass.swift", "extension Square {\n    /// 証明用。\n    init(bypass: Int) {\n        index = bypass\n    }\n}\n"),
          r"^CNF-021 Sources/NeNeWireCore/Square\+Bypass\.swift"),
    Proof("P59", ["SWF-013", "CNF-022"], "Core に async の関数を書く",
          core_file("Probe.swift", "/// 証明用。\nenum Probe {\n    /// 証明用。\n    static func wait() async -> Int { 1 }\n}\n"),
          r"^CNF-022 Sources/NeNeWireCore/Probe\.swift"),
    Proof("P60", ["SWF-009", "SWF-015", "CNF-014"], "Terminal で @preconcurrency import を書く（並行性の error を戻らない warning に下げる・M7-i）",
          lambda r: edit(r, "Sources/NeNeWireTerminal/Screen.swift", "import Glibc\n", "@preconcurrency import Glibc\n"),
          r"^CNF-014 Sources/NeNeWireTerminal/Screen\.swift", command=["make", "conformance"]),
    Proof("P61", ["QLT-003", "QLT-004", "CNF-005"], ".swift-format の rules で規則を 1 つ切る（リポジトリ全体の抑制になる・M8-j）",
          lambda r: write(r, ".swift-format", '{\n  "version": 1,\n  "indentation": {\n    "spaces": 4\n  },\n  "lineLength": 120,\n'
                          '  "rules": {\n    "AlwaysUseLowerCamelCase": false\n  }\n}\n'),
          r"^CNF-005 \.swift-format"),
    Proof("P62", ["CNF-023", "ARC-002"], "Core で posix_spawn を呼んで子プロセスを起動する（外部プロセスは Host だけ）",
          core_file("Probe.swift", "/// 証明用。\nenum Probe {\n    /// 証明用。\n    static func run() -> Int32 {\n        posix_spawn(nil, \"/bin/true\", nil, nil, nil, nil)\n    }\n}\n"),
          r"^CNF-023 Sources/NeNeWireCore/Probe\.swift", command=["make", "conformance"]),
    Proof("P63", ["ARC-002", "CNF-011", "QLT-006"], "Terminal が宣言していない推移的な依存の Core を import する（SwiftPM は拒まない・M6-e）",
          lambda r: edit(r, "Sources/NeNeWireTerminal/Screen.swift", "import Glibc\n", "import Glibc\nimport NeNeWireCore\n"),
          r"^CNF-011 Sources/NeNeWireTerminal/Screen\.swift"),
    Proof("P67", ["QLT-014"], "公開スクリプトに版と違うタグを渡す",
          nothing, r"package-release: タグ v9\.9\.9 が版 v[0-9.]+ と違う", command=["eng/package-release.sh", "v9.9.9"], scaffold=False),
    Proof("P68", ["QLT-014"], "公開スクリプトから --static-swift-stdlib を外す（Swift のランタイムに動的に依存する実行ファイルになる）",
          lambda r: edit(r, "eng/package-release.sh", " --static-swift-stdlib", ""),
          r"package-release: 宣言していない動的依存: libswift", command=["eng/package-release.sh"], scaffold=False),
    Proof("P69", ["QLT-014"], "公開スクリプトの同梱物に余計なファイルを 1 つ足す",
          lambda r: edit(r, "eng/package-release.sh", 'cp LICENSE "$stage/LICENSE"', 'cp LICENSE "$stage/LICENSE"\ntouch "$stage/notes.txt"'),
          r"package-release: 同梱物が固定の 3 つと違う", command=["eng/package-release.sh"], scaffold=False),
    Proof("P70", ["QLT-014"], "--version の出力を版の入力と違う値にする",
          lambda r: edit(r, "Sources/nene-wire/main.swift", 'print("nene-wire \\(Version.current)")', 'print("nene-wire 0.0.0")'),
          r"package-release: --version が 'nene-wire 0\.0\.0'", command=["eng/package-release.sh"], scaffold=False),
    Proof("P64", ["ARC-003", "ARC-007", "CNF-011", "SWF-014"], "Core が FoundationEssentials を import する（Foundation とは別の名前で Date が読める・M5-j）",
          core_file("Probe.swift", "import FoundationEssentials\n\n/// 証明用。\nenum Probe {}\n"), r"^CNF-011 Sources/NeNeWireCore/Probe\.swift"),
    Proof("P65", ["QLT-007"], "規約検査の CNF-013 の選択肢ごとの判定を壊す（検査器の単体テストが落ちること）",
          lambda r: edit(r, "eng/conformance.py", "            if items and any(irrefutable(item) for item in items):",
                         "            if items and False:"),
          r"FAILED \(failures="),
    Proof("P42", ["GIT-003"], "形の合わないコミットをフック付きで作ろうとする（フックが拒む）",
          lambda r: subprocess.run(["git", "-C", str(r), "config", "core.hooksPath", ".githooks"], check=True),
          r"GIT-003 件名は",
          command=["git", "-c", "user.name=proof", "-c", "user.email=proof@example.invalid", "commit", "--allow-empty", "-m", "update stuff"],
          scaffold=False),
]


# 複製した木では再現できない（GitHub 側の）証明。観察した日・run・出力をそのまま書く。
MANUAL: list[dict] = [
    {"id": "P43", "rules": ["GIT-004"],
     "violation": "ruleset が `main` に効いていることを読み戻し、必須 check の失敗した PR がマージできないことを見る"
                  "（`main` への直接 push と force push は試していない）",
     "command": "`gh api repos/hideyukiMORI/nene-wire/rules/branches/main`・`gh pr view 2`（2026-10-26）",
     "evidence": "`main` に効く規則は ruleset 25851529 の `deletion`・`non_fast_forward`・`pull_request`（squash のみ）・`required_status_checks`（`check`）の 4 つ。"
                 "PR #2 の head 1b235b9 は必須 check `check` が FAILURE で `mergeStateStatus` が `BLOCKED`"},
    {"id": "P46", "rules": ["QLT-012"],
     "violation": "draft の PR に push する（CI のジョブはスキップでなく失敗し、PR はマージできない）",
     "command": "GitHub Actions run 40262253912（PR #2・head 1b235b9・2026-10-26T03:04Z）",
     "evidence": "step `eng/ci-require-ready.sh true` が `ci: PR が draft なのでフルゲートを回さない。Ready にすると回る（QLT-012）` で exit 1。"
                 "必須 check `check` は FAILURE・`mergeStateStatus` は `BLOCKED`"},
]
FAMILIES = ["ARC", "SWF", "QLT", "CNF", "GIT"]


def render(doc: dict) -> bool:
    """gate-proofs.json から gate-proofs.md の 2 つの表を作り直す（手で貼らない）。"""
    path = ROOT / "docs" / "quality" / "gate-proofs.md"
    text = path.read_text(encoding="utf-8")
    md = lambda t: t.replace("|", "｜").replace(UNDEFINED_ID, UNDEFINED_ID_SHOWN)  # noqa: E731
    by: dict[str, list[dict]] = {}
    for r in doc["results"]:
        for rule in r["rules"]:
            by.setdefault(rule, []).append(
                {"id": r["id"], "violation": r["violation"], "command": f"`{r['command']}`",
                 "evidence": f"exit {r['exit']}・`{md((r['evidence'] or [''])[0][:120])}`"})
    for m in MANUAL:
        for rule in m["rules"]:
            by.setdefault(rule, []).append(m)
    active = [ln.split("|")[1].strip() for ln in (ROOT / "docs/QUALITY_GATES.md").read_text(encoding="utf-8").splitlines()
              if re.match(r"^\| [A-Z]{3}-\d{3} \| active \|", ln)]
    rows = ["| 規則 | 最小の違反 | 検証経路 | 実測 |", "| --- | --- | --- | --- |"]
    for rule in sorted(active, key=lambda x: (FAMILIES.index(x[:3]), x)):
        ps = by.get(rule, [])
        rows.append("| %s | %s | %s | %s |" % (
            rule, "<br>".join(f"{p['id']}: {md(p['violation'])}" for p in ps),
            "<br>".join(sorted({p["command"] for p in ps})),
            "<br>".join(f"{p['id']}: {p['evidence']}" for p in ps)))
    listing = ["| # | 規則 | 仕込んだ違反 | 実行したタスク | 結果 | 判定 |", "| --- | --- | --- | --- | --- | --- |"]
    for r in doc["results"]:
        listing.append(f"| {r['id']} | {', '.join(r['rules']) or '対照'} | {md(r['violation'])} | `{r['command']}` | exit {r['exit']} | {r['verdict']} |")
    for m in MANUAL:
        listing.append(f"| {m['id']} | {', '.join(m['rules'])} | {md(m['violation'])} | {m['command']} | 第 1-a 節 | pass |")
    unproven = [rule for rule in active if not by.get(rule)]
    if unproven:
        print("prove-gates: active なのに証明が無い: " + ", ".join(sorted(unproven)), file=sys.stderr)
    for name, body in (("active", rows), ("list", listing)):
        start, end = f"<!-- proofs:{name}:start -->", f"<!-- proofs:{name}:end -->"
        a, b = text.index(start) + len(start), text.index(end)
        text = text[:a] + "\n" + "\n".join(body) + "\n" + text[b:]
    path.write_text(text, encoding="utf-8")
    return not unproven


UNDEFINED_ID = "ARC-0" + "99"
UNDEFINED_ID_SHOWN = "ARC-0 99（仕込んだ未定義の ID。この文書自身が落ちないよう空白を入れて写した）"


def copy_tree(dest: Path) -> None:
    """git が追跡するか追跡し得るファイル（.gitignore と exclude に従う）と .git だけを複製する。規約検査が見る範囲と同じ。"""
    listed = subprocess.run(["git", "-C", str(ROOT), "ls-files", "-z", "--cached", "--others", "--exclude-standard"],
                            check=True, capture_output=True, text=True).stdout.split("\0")
    shutil.copytree(ROOT / ".git", dest / ".git", symlinks=True)
    for rel in listed:
        if rel and (ROOT / rel).is_file():
            (dest / rel).parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(ROOT / rel, dest / rel)
    os.symlink(ROOT / ".tools", dest / ".tools")


def fill_pending(root: Path) -> None:
    """複製の gate-proofs.md で、この実行が証明する規則の空の証明行だけを「測定中」で埋める。

    CNF-006 は実測の空の証明行を拒むので、初めて active にした規則は、測る前の複製で対照まで落ちてしまう。
    作業木の文書は測った結果からだけ作る（render）。ここで埋めるのは捨てる複製だけである。
    """
    path = root / "docs" / "quality" / "gate-proofs.md"
    covered = {rule for proof in PROOFS for rule in proof.rules} | {rule for m in MANUAL for rule in m["rules"]}
    lines = []
    for line in path.read_text(encoding="utf-8").splitlines():
        m = re.match(r"^\| ([A-Z]{3}-\d{3}) \|\s*\|\s*\|\s*\|$", line)
        lines.append(f"| {m.group(1)} | 測定中 | prove-gates | 測定中 |" if m and m.group(1) in covered else line)
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def scaffold(root: Path) -> None:
    write(root, "Package.swift", package_swift())
    for rel, text in SOURCES.items():
        write(root, rel, text)


def run_proof(proof: Proof) -> dict:
    with tempfile.TemporaryDirectory(prefix=f"wire-proof-{proof.id}-") as tmp:
        root = Path(tmp) / "repo"
        copy_tree(root)
        fill_pending(root)
        if proof.scaffold:
            scaffold(root)
        proof.mutate(root)
        if proof.scaffold:
            # 生成した manifest の行の長さは証明の対象ではないので、Package.swift だけ整形してから回す
            subprocess.run(["swift-format", "format", "-i", "--configuration", ".swift-format", "Package.swift"],
                           cwd=root, capture_output=True)
        p = subprocess.run(proof.command, cwd=root, capture_output=True, text=True, timeout=1800,
                           env=dict(os.environ, NO_COLOR="1"))
        output = (p.stdout + p.stderr).replace(str(root) + "/", "")
        matched = [ln.strip() for ln in output.splitlines() if re.search(proof.expect, ln.strip())]
        missing = [pat for pat in proof.expect_all if not re.search(pat, output)]
        ok = (p.returncode == 0) if proof.expect_exit_zero else (p.returncode != 0 and bool(matched) and not missing)
        return {
            "id": proof.id,
            "rules": proof.rules,
            "violation": proof.violation,
            "command": " ".join(proof.command),
            "exit": p.returncode,
            "expected": proof.expect,
            "verdict": "pass" if ok else "FAIL",
            "evidence": matched[:3] if not proof.expect_all else matched[:len(proof.expect_all)],
            "missing": missing,
            "tail": [ln for ln in output.strip().splitlines()[-8:]],
        }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--only", nargs="*")
    parser.add_argument("--render", action="store_true", help="測らずに gate-proofs.json から gate-proofs.md の表を作り直す")
    args = parser.parse_args()
    if args.render:
        return 0 if render(json.loads(OUT.read_text(encoding="utf-8"))) else 1
    results = []
    for proof in PROOFS:
        if args.only and proof.id not in args.only:
            continue
        r = run_proof(proof)
        print(f"{r['id']:5} {r['verdict']:4} exit={r['exit']:<3} {r['violation']}", flush=True)
        for line in (r["evidence"] or r["tail"])[:2]:
            print(f"        {line}", flush=True)
        if r["missing"]:
            print(f"        出力に現れなかった: {', '.join(r['missing'])}", flush=True)
            for line in r["tail"]:
                print(f"        | {line}", flush=True)
        results.append(r)
    if not args.only:
        doc = {
            "measured_on": subprocess.run(["date", "+%Y-%m-%d"], capture_output=True, text=True).stdout.strip(),
            "head": subprocess.run(["git", "-C", str(ROOT), "rev-parse", "--short", "HEAD"], capture_output=True, text=True).stdout.strip(),
            "note": "verdict=pass は「意図した規則で落ちた」（対照は exit 0）。作業木の未コミットの変更も複製に含む。",
            "results": results,
        }
        OUT.write_text(json.dumps(doc, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        complete = render(doc)
        print(f"wrote {OUT.relative_to(ROOT)} と docs/quality/gate-proofs.md の表")
        if not complete:
            return 1
    return 0 if all(r["verdict"] == "pass" for r in results) else 1


if __name__ == "__main__":
    sys.exit(main())

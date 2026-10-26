#!/usr/bin/env python3
"""Phase 0: Swift で M-1〜M-8 を実測し、docs/quality/phase0-results.json に書く。

使い捨ての swiftc 呼び出しと SwiftPM パッケージを一時ディレクトリに作り、
終了コードと診断行をそのまま記録する。判定（ある／無い／不十分）は ADR 0001 で人が書く。
標準ライブラリだけで書く。

移植元: NeNe Gambit eng/measure-language.py（コミット 64b82ec）。ケース ID は Gambit と同じものを同じ意味で使い、
このリポジトリで足したケースは同じ M の続きの記号（M1-i 以降など）にする（ADR 0001）。

    python3 eng/measure-language.py --swiftlint <path-to-swiftlint-static>
"""

from __future__ import annotations

import argparse
import json
import os
import platform
import re
import subprocess
import sys
import tempfile
from dataclasses import dataclass, field
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "docs" / "quality" / "phase0-results.json"
STRICT = ["-swift-version", "6", "-warnings-as-errors"]
DIAG = re.compile(r"(error|warning):|✘ Test ")


@dataclass
class Case:
    id: str
    m: str
    question: str
    kind: str  # swiftc | swiftc-run | xmod | spm | swiftlint | swift-format
    files: dict[str, str]
    args: list[str] = field(default_factory=list)
    lib: dict[str, str] = field(default_factory=dict)


def manifest(targets: str, products: str = "") -> str:
    return (
        "// swift-tools-version: 6.2\n"
        "import PackageDescription\n"
        "let package = Package(\n"
        '    name: "Probe",\n'
        f"    products: [{products}],\n"
        f"    targets: [{targets}]\n"
        ")\n"
    )


STRICT_SETTINGS = "swiftSettings: [.treatAllWarnings(as: .error)]"

SHAPE = "enum Shape { case a, b, c }\n"
DEPRECATED = "@available(*, deprecated)\nfunc old() -> Int { 1 }\n"

CASES: list[Case] = [
    # M-1 網羅性
    Case("M1-a", "M-1", "ケースを網羅しない switch はコンパイルエラーか", "swiftc",
         {"a.swift": SHAPE + "func f(_ s: Shape) -> Int {\n    switch s {\n    case .a: return 1\n    case .b: return 2\n    }\n}\n"},
         STRICT),
    Case("M1-b", "M-1", "default: は網羅性検査を殺すか（診断が出るか）", "swiftc",
         {"a.swift": SHAPE + "func f(_ s: Shape) -> Int {\n    switch s {\n    case .a: return 1\n    default: return 0\n    }\n}\n"},
         STRICT),
    Case("M1-c", "M-1", "case _: は網羅性検査を殺すか", "swiftc",
         {"a.swift": SHAPE + "func f(_ s: Shape) -> Int {\n    switch s {\n    case .a: return 1\n    case _: return 0\n    }\n}\n"},
         STRICT),
    Case("M1-d", "M-1", "case let x: （束縛する全捕捉）は網羅性検査を殺すか", "swiftc",
         {"a.swift": SHAPE + "func f(_ s: Shape) -> Int {\n    switch s {\n    case .a: return 1\n    case let other: return other == .b ? 2 : 0\n    }\n}\n"},
         STRICT),
    Case("M1-e", "M-1", "@unknown default で既知ケースを漏らすと -warnings-as-errors で落ちるか", "swiftc",
         {"a.swift": SHAPE + "func f(_ s: Shape) -> Int {\n    switch s {\n    case .a: return 1\n    case .b: return 2\n    @unknown default: return 0\n    }\n}\n"},
         STRICT),
    Case("M1-f", "M-1", "@unknown default で既知ケースを漏らす（-warnings-as-errors 無し）", "swiftc",
         {"a.swift": SHAPE + "func f(_ s: Shape) -> Int {\n    switch s {\n    case .a: return 1\n    case .b: return 2\n    @unknown default: return 0\n    }\n}\n"},
         ["-swift-version", "6"]),
    Case("M1-h", "M-1", "SwiftPM の treatAllWarnings(as: .error) でも @unknown default の既知ケース漏れは通るか", "spm",
         {"Package.swift": manifest(f'.target(name: "Core", {STRICT_SETTINGS})'),
          "Sources/Core/Core.swift": "public enum Shape { case a, b, c }\npublic func f(_ s: Shape) -> Int {\n    switch s {\n    case .a: return 1\n    case .b: return 2\n    @unknown default: return 0\n    }\n}\n"}),
    Case("M1-g", "M-1", "タプルの中の _ は網羅性検査を部分的に殺すか", "swiftc",
         {"a.swift": SHAPE + "func f(_ s: Shape, _ t: Shape) -> Int {\n    switch (s, t) {\n    case (.a, _): return 1\n    case (.b, _): return 2\n    case (.c, _): return 3\n    }\n}\n"},
         STRICT),
    Case("M1-i", "M-1", "閉じた enum を == と else で分岐すると、ケースを足しても診断は出ないか", "swiftc",
         {"a.swift": SHAPE + "func f(_ s: Shape) -> Int {\n    if s == .a {\n        return 1\n    } else {\n        return 0\n    }\n}\n"},
         STRICT),
    Case("M1-j", "M-1", "case (let other): （括弧で包んだ束縛）は網羅性検査を殺すか", "swiftc",
         {"a.swift": SHAPE + "func f(_ s: Shape) -> Int {\n    switch s {\n    case .a: return 1\n    case (let other): return other == .b ? 2 : 0\n    }\n}\n"},
         STRICT),
    Case("M1-k", "M-1", "case .a, _: （並べた選択肢の中の _）は網羅性検査を殺すか", "swiftc",
         {"a.swift": SHAPE + "func f(_ s: Shape) -> Int {\n    switch s {\n    case .b: return 2\n    case .a, _: return 1\n    }\n}\n"},
         STRICT),
    Case("M1-l", "M-1", "case let other as Shape: （型が同じ as パターン）は網羅性検査を殺すか", "swiftc",
         {"a.swift": SHAPE + "func f(_ s: Shape) -> Int {\n    switch s {\n    case .a: return 1\n    case let other as Shape: return other == .b ? 2 : 0\n    }\n}\n"},
         STRICT),
    Case("M1-m", "M-1", "タプルの全位置を _ にした case (_, _): は網羅性検査を殺すか", "swiftc",
         {"a.swift": SHAPE + "func f(_ s: Shape, _ t: Shape) -> Int {\n    switch (s, t) {\n    case (.a, .a): return 1\n    case (_, _): return 0\n    }\n}\n"},
         STRICT),
    # M-2 公開状態の不変
    Case("M2-a", "M-2", "他モジュールから public let に代入できるか", "xmod",
         {"client.swift": "import Lib\nfunc f() {\n    var b = Board()\n    b.size = 9\n    _ = b\n}\n"},
         STRICT,
         {"lib.swift": "public struct Board {\n    public let size: Int\n    public private(set) var moves: Int\n    public var loose: Int\n    public init() { size = 8; moves = 0; loose = 0 }\n}\n"}),
    Case("M2-b", "M-2", "他モジュールから public private(set) var に代入できるか", "xmod",
         {"client.swift": "import Lib\nfunc f() {\n    var b = Board()\n    b.moves = 3\n    _ = b\n}\n"},
         STRICT,
         {"lib.swift": "public struct Board {\n    public let size: Int\n    public private(set) var moves: Int\n    public var loose: Int\n    public init() { size = 8; moves = 0; loose = 0 }\n}\n"}),
    Case("M2-c", "M-2", "他モジュールから public var に代入できるか", "xmod",
         {"client.swift": "import Lib\nfunc f() {\n    var b = Board()\n    b.loose = 3\n    _ = b\n}\n"},
         STRICT,
         {"lib.swift": "public struct Board {\n    public let size: Int\n    public private(set) var moves: Int\n    public var loose: Int\n    public init() { size = 8; moves = 0; loose = 0 }\n}\n"}),
    Case("M2-d", "M-2", "返した配列に追加すると持ち主が変わるか（値の意味）", "swiftc-run",
         {"main.swift": "final class Ledger {\n    private(set) var items: [Int] = [1]\n    func snapshot() -> [Int] { items }\n}\nlet l = Ledger()\nvar s = l.snapshot()\ns.append(2)\nprint(\"owner=\\(l.items.count) copy=\\(s.count)\")\n"},
         ["-swift-version", "6"]),
    Case("M2-e", "M-2", "let で持ったクラス参照の中身は変更できるか", "swiftc",
         {"a.swift": "final class Cell { var v = 0 }\nfunc f() -> Int {\n    let c = Cell()\n    c.v = 1\n    return c.v\n}\n"},
         STRICT),
    # M-3 null・ゼロ値・未初期化
    Case("M3-a", "M-3", "未初期化の let を返すと -typecheck で落ちるか", "swiftc",
         {"a.swift": "func f(_ flag: Bool) -> Int {\n    let x: Int\n    if flag { x = 1 }\n    return x\n}\n"},
         STRICT + ["-typecheck"]),
    Case("M3-b", "M-3", "未初期化の let を返すと本コンパイルで落ちるか", "swiftc",
         {"a.swift": "func f(_ flag: Bool) -> Int {\n    let x: Int\n    if flag { x = 1 }\n    return x\n}\n"},
         STRICT),
    Case("M3-c", "M-3", "暗黙アンラップ Optional（IUO）は書けるか", "swiftc",
         {"a.swift": "func f() -> Int {\n    var cache: Int! = nil\n    cache = 3\n    let y: Int = cache\n    return y\n}\n"},
         STRICT),
    Case("M3-d", "M-3", "強制アンラップ ! は書けるか", "swiftc",
         {"a.swift": "func f(_ v: Int?) -> Int {\n    v!\n}\n"},
         STRICT),
    Case("M3-e", "M-3", "全プロパティに既定値がある struct は引数なしで作れるか（ゼロ値相当）", "swiftc",
         {"a.swift": "struct Marker {}\nstruct Score { var value = 0 }\nfunc f() -> Int {\n    _ = Marker()\n    return Score().value\n}\n"},
         STRICT),
    Case("M3-f", "M-3", "宣言だけの var を読むと落ちるか（暗黙のゼロ値は無いか）", "swiftc",
         {"a.swift": "func f() -> Int {\n    var x: Int\n    x += 1\n    return x\n}\n"},
         STRICT),
    # M-4 非公開コンストラクタ
    Case("M4-a", "M-4", "private init を同一モジュールの別ファイルから呼べるか", "swiftc",
         {"square.swift": "struct Square {\n    let index: Int\n    private init(index: Int) { self.index = index }\n    static func make(_ i: Int) -> Square? { (0..<64).contains(i) ? Square(index: i) : nil }\n}\n",
          "use.swift": "func f() -> Square { Square(index: 99) }\n"},
         STRICT),
    Case("M4-b", "M-4", "明示 init の無い public struct の memberwise init を他モジュールから呼べるか", "xmod",
         {"client.swift": "import Lib\nfunc f() -> Square { Square(index: 99) }\n"},
         STRICT,
         {"lib.swift": "public struct Square {\n    public let index: Int\n}\n"}),
    Case("M4-c", "M-4", "明示 init の無い struct の memberwise init を同一モジュールの別ファイルから呼べるか", "swiftc",
         {"square.swift": "struct Square {\n    let index: Int\n}\n",
          "use.swift": "func f() -> Square { Square(index: 99) }\n"},
         STRICT),
    Case("M4-d", "M-4", "unsafeBitCast で private init を迂回できるか", "swiftc",
         {"square.swift": "struct Square {\n    let index: Int\n    private init(index: Int) { self.index = index }\n}\n",
          "use.swift": "func f() -> Square { unsafeBitCast(99, to: Square.self) }\n"},
         STRICT),
    Case("M4-e", "M-4", "Decodable の合成 init(from:) は private init を迂回するか", "swiftc",
         {"square.swift": "struct Square: Decodable {\n    let index: Int\n    private init(index: Int) { self.index = index }\n}\n",
          "use.swift": "func f(_ d: any Decoder) throws -> Square { try Square(from: d) }\n"},
         STRICT),
    Case("M4-f", "M-4", "同一モジュールの別ファイルの extension に init を足し、格納プロパティへ直接代入して private init を迂回できるか", "swiftc",
         {"square.swift": "struct Square {\n    let index: Int\n    private init(index: Int) { self.index = index }\n}\n",
          "use.swift": "extension Square {\n    init(bypass: Int) { index = bypass }\n}\nfunc f() -> Square { Square(bypass: 99) }\n"},
         STRICT),
    Case("M4-g", "M-4", "他モジュールの extension に init を足し、格納プロパティへ直接代入できるか", "xmod",
         {"client.swift": "import Lib\nextension Square {\n    init(bypass: Int) { index = bypass }\n}\n"},
         STRICT,
         {"lib.swift": "public struct Square {\n    public let index: Int\n    private init(index: Int) { self.index = index }\n    public static func make(_ i: Int) -> Square? { (0..<64).contains(i) ? Square(index: i) : nil }\n}\n"}),
    # M-5 中核の決定性（依存ゼロの SwiftPM target から読めるか）
    Case("M5-a", "M-5", "依存を宣言しない target から Foundation の Date() を読めるか", "spm",
         {"Package.swift": manifest(f'.target(name: "Core", {STRICT_SETTINGS})'),
          "Sources/Core/Probe.swift": "import Foundation\npublic func probe() -> Double { Date().timeIntervalSince1970 }\n"}),
    Case("M5-b", "M-5", "依存を宣言しない target から Glibc の time() を読めるか", "spm",
         {"Package.swift": manifest(f'.target(name: "Core", {STRICT_SETTINGS})'),
          "Sources/Core/Probe.swift": "import Glibc\npublic func probe() -> Int { time(nil) }\n"}),
    Case("M5-c", "M-5", "import なしで Int.random を呼べるか", "spm",
         {"Package.swift": manifest(f'.target(name: "Core", {STRICT_SETTINGS})'),
          "Sources/Core/Probe.swift": "public func probe() -> Int { Int.random(in: 0..<10) }\n"}),
    Case("M5-d", "M-5", "import なしで SystemRandomNumberGenerator を使えるか", "spm",
         {"Package.swift": manifest(f'.target(name: "Core", {STRICT_SETTINGS})'),
          "Sources/Core/Probe.swift": "public func probe() -> UInt64 {\n    var g = SystemRandomNumberGenerator()\n    return g.next()\n}\n"}),
    Case("M5-e", "M-5", "import なしで ContinuousClock.now を読めるか", "spm",
         {"Package.swift": manifest(f'.target(name: "Core", {STRICT_SETTINGS})'),
          "Sources/Core/Probe.swift": "public func probe() -> ContinuousClock.Instant { ContinuousClock.now }\n"}),
    Case("M5-f", "M-5", "import なしで CommandLine.arguments（プロセス状態）を読めるか", "spm",
         {"Package.swift": manifest(f'.target(name: "Core", {STRICT_SETTINGS})'),
          "Sources/Core/Probe.swift": "public func probe() -> Int { CommandLine.arguments.count }\n"}),
    Case("M5-g", "M-5", "依存を宣言しない target から Dispatch を import できるか", "spm",
         {"Package.swift": manifest(f'.target(name: "Core", {STRICT_SETTINGS})'),
          "Sources/Core/Probe.swift": "import Dispatch\npublic func probe() -> UInt64 { DispatchTime.now().uptimeNanoseconds }\n"}),
    Case("M5-h", "M-5", "--explicit-target-dependency-import-check error は Foundation の import を拒むか", "spm",
         {"Package.swift": manifest(f'.target(name: "Core", {STRICT_SETTINGS})'),
          "Sources/Core/Probe.swift": "import Foundation\npublic func probe() -> Double { Date().timeIntervalSince1970 }\n"},
         ["--explicit-target-dependency-import-check", "error"]),
    Case("M5-i", "M-5", "import なしで Task.sleep（時計を暗に読む待ち）を書けるか", "spm",
         {"Package.swift": manifest(f'.target(name: "Core", {STRICT_SETTINGS})'),
          "Sources/Core/Probe.swift": "public func probe() async -> Int {\n    _ = try? await Task.sleep(for: .milliseconds(1))\n    return 1\n}\n"}),
    Case("M5-j", "M-5", "依存を宣言しない target から FoundationEssentials の Date() を読めるか", "spm",
         {"Package.swift": manifest(f'.target(name: "Core", {STRICT_SETTINGS})'),
          "Sources/Core/Probe.swift": "import FoundationEssentials\npublic func probe() -> Double { Date().timeIntervalSince1970 }\n"}),
    # M-6 依存方向
    Case("M6-a", "M-6", "宣言していない兄弟 target を import すると落ちるか（両方が同じ実行物の依存）", "spm",
         {"Package.swift": manifest(
             f'.target(name: "Engine", {STRICT_SETTINGS}), '
             f'.target(name: "Core", {STRICT_SETTINGS}), '
             f'.executableTarget(name: "app", dependencies: ["Core", "Engine"], {STRICT_SETTINGS})'),
          "Sources/Engine/Engine.swift": "public func engine() -> Int { 1 }\n",
          "Sources/Core/Core.swift": "import Engine\npublic func core() -> Int { engine() }\n",
          "Sources/app/main.swift": "import Core\nprint(core())\n"}),
    Case("M6-b", "M-6", "M6-a に --explicit-target-dependency-import-check error を足すと落ちるか", "spm",
         {"Package.swift": manifest(
             f'.target(name: "Engine", {STRICT_SETTINGS}), '
             f'.target(name: "Core", {STRICT_SETTINGS}), '
             f'.executableTarget(name: "app", dependencies: ["Core", "Engine"], {STRICT_SETTINGS})'),
          "Sources/Engine/Engine.swift": "public func engine() -> Int { 1 }\n",
          "Sources/Core/Core.swift": "import Engine\npublic func core() -> Int { engine() }\n",
          "Sources/app/main.swift": "import Core\nprint(core())\n"},
         ["--explicit-target-dependency-import-check", "error"]),
    Case("M6-c", "M-6", "宣言していない target を import し、その target だけを build すると落ちるか", "spm",
         {"Package.swift": manifest(
             f'.target(name: "Engine", {STRICT_SETTINGS}), .target(name: "Core", {STRICT_SETTINGS})'),
          "Sources/Engine/Engine.swift": "public func engine() -> Int { 1 }\n",
          "Sources/Core/Core.swift": "import Engine\npublic func core() -> Int { engine() }\n"},
         ["--target", "Core"]),
    Case("M6-d", "M-6", "target の循環依存を宣言すると落ちるか", "spm",
         {"Package.swift": manifest(
             f'.target(name: "Engine", dependencies: ["Core"], {STRICT_SETTINGS}), '
             f'.target(name: "Core", dependencies: ["Engine"], {STRICT_SETTINGS})'),
          "Sources/Engine/Engine.swift": "public func engine() -> Int { 1 }\n",
          "Sources/Core/Core.swift": "public func core() -> Int { 1 }\n"}),
    Case("M6-e", "M-6", "依存の依存（宣言していない推移的な target）を import すると落ちるか", "spm",
         {"Package.swift": manifest(
             f'.target(name: "Core", {STRICT_SETTINGS}), '
             f'.target(name: "Engine", dependencies: ["Core"], {STRICT_SETTINGS}), '
             f'.target(name: "Render", dependencies: ["Engine"], {STRICT_SETTINGS})'),
          "Sources/Core/Core.swift": "public func core() -> Int { 1 }\n",
          "Sources/Engine/Engine.swift": "import Core\npublic func engine() -> Int { core() }\n",
          "Sources/Render/Render.swift": "import Core\nimport Engine\npublic func render() -> Int { core() + engine() }\n"}),
    Case("M6-f", "M-6", "M6-e に --explicit-target-dependency-import-check error を足すと落ちるか", "spm",
         {"Package.swift": manifest(
             f'.target(name: "Core", {STRICT_SETTINGS}), '
             f'.target(name: "Engine", dependencies: ["Core"], {STRICT_SETTINGS}), '
             f'.target(name: "Render", dependencies: ["Engine"], {STRICT_SETTINGS})'),
          "Sources/Core/Core.swift": "public func core() -> Int { 1 }\n",
          "Sources/Engine/Engine.swift": "import Core\npublic func engine() -> Int { core() }\n",
          "Sources/Render/Render.swift": "import Core\nimport Engine\npublic func render() -> Int { core() + engine() }\n"},
         ["--explicit-target-dependency-import-check", "error"]),
    # M-7 抑制
    Case("M7-a", "M-7", "@diagnose(..., as: ignored) で -warnings-as-errors 下の警告を消せるか", "swiftc",
         {"a.swift": DEPRECATED + "@diagnose(DeprecatedDeclaration, as: ignored)\nfunc use() -> Int { old() }\n"},
         STRICT),
    Case("M7-b", "M-7", "対照: @diagnose が無ければ同じ呼び出しは -warnings-as-errors で落ちるか", "swiftc",
         {"a.swift": DEPRECATED + "func use() -> Int { old() }\n"},
         STRICT),
    Case("M7-c", "M-7", "呼び出し側を @available(*, deprecated) にすると非推奨の警告が消えるか", "swiftc",
         {"a.swift": DEPRECATED + "@available(*, deprecated)\nfunc use() -> Int { old() }\n"},
         STRICT),
    Case("M7-d", "M-7", "Package.swift の treatWarning(_:as: .warning) で 1 群だけ警告へ戻せるか", "spm",
         {"Package.swift": manifest(
             '.target(name: "Core", swiftSettings: [.treatAllWarnings(as: .error), '
             '.treatWarning("DeprecatedDeclaration", as: .warning)])'),
          "Sources/Core/Core.swift": "@available(*, deprecated)\npublic func old() -> Int { 1 }\npublic func use() -> Int { old() }\n"}),
    Case("M7-e", "M-7", "swiftlint:disable:next を理由なしで書くと違反が消えるか", "swiftlint",
         {".swiftlint.yml": "only_rules:\n  - force_unwrapping\nstrict: true\n",
          "a.swift": "func f(_ v: Int?) -> Int {\n    // swiftlint:disable:next force_unwrapping\n    return v!\n}\n"}),
    Case("M7-f", "M-7", "対照: 抑制が無ければ SwiftLint は同じ違反で落ちるか", "swiftlint",
         {".swiftlint.yml": "only_rules:\n  - force_unwrapping\nstrict: true\n",
          "a.swift": "func f(_ v: Int?) -> Int {\n    return v!\n}\n"}),
    Case("M7-g", "M-7", "swift-format-ignore を理由なしで書くと lint の指摘が消えるか", "swift-format",
         {"a.swift": "// swift-format-ignore\nlet Bad_name = 1\n"}),
    Case("M7-h", "M-7", "対照: 抑制が無ければ swift-format lint --strict は落ちるか", "swift-format",
         {"a.swift": "let Bad_name = 1\n"}),
    Case("M7-i", "M-7", "@preconcurrency import で、他モジュールの非 Sendable 型の大域変数の診断が消えるか", "xmod",
         {"client.swift": "@preconcurrency import Lib\nlet shared = Box()\nfunc f() -> Int { shared.value }\n"},
         STRICT,
         {"lib.swift": "public final class Box {\n    public var value = 0\n    public init() {}\n}\n"}),
    Case("M7-j", "M-7", "対照: @preconcurrency が無ければ同じ大域変数は落ちるか", "xmod",
         {"client.swift": "import Lib\nlet shared = Box()\nfunc f() -> Int { shared.value }\n"},
         STRICT,
         {"lib.swift": "public final class Box {\n    public var value = 0\n    public init() {}\n}\n"}),
    Case("M7-k", "M-7", "nonisolated(unsafe) で可変な大域変数の並行性検査を外せるか", "swiftc",
         {"a.swift": "nonisolated(unsafe) var counter = 0\nfunc f() -> Int {\n    counter += 1\n    return counter\n}\n"},
         STRICT),
    Case("M7-l", "M-7", "対照: nonisolated(unsafe) が無ければ可変な大域変数は落ちるか", "swiftc",
         {"a.swift": "var counter = 0\nfunc f() -> Int {\n    counter += 1\n    return counter\n}\n"},
         STRICT),
    # M-8 baseline・全面抑制
    Case("M8-a", "M-8", "unsafeFlags([\"-suppress-warnings\"]) で target 全体の警告を消せるか（treatAllWarnings(.error) と併用）", "spm",
         {"Package.swift": manifest(
             '.target(name: "Core", swiftSettings: [.treatAllWarnings(as: .error), .unsafeFlags(["-suppress-warnings"])])'),
          "Sources/Core/Core.swift": "@available(*, deprecated)\npublic func old() -> Int { 1 }\npublic func use() -> Int { old() }\n"}),
    Case("M8-b", "M-8", "treatAllWarnings(as: .warning) で target 全体を警告に戻せるか", "spm",
         {"Package.swift": manifest('.target(name: "Core", swiftSettings: [.treatAllWarnings(as: .warning)])'),
          "Sources/Core/Core.swift": "@available(*, deprecated)\npublic func old() -> Int { 1 }\npublic func use() -> Int { old() }\n"}),
    Case("M8-c", "M-8", "対照: treatAllWarnings(as: .error) だけなら同じ target は落ちるか", "spm",
         {"Package.swift": manifest(f'.target(name: "Core", {STRICT_SETTINGS})'),
          "Sources/Core/Core.swift": "@available(*, deprecated)\npublic func old() -> Int { 1 }\npublic func use() -> Int { old() }\n"}),
    Case("M8-g", "M-8", "unsafeFlags([\"-suppress-warnings\"]) だけなら target 全体の警告が消えるか", "spm",
         {"Package.swift": manifest('.target(name: "Core", swiftSettings: [.unsafeFlags(["-suppress-warnings"])])'),
          "Sources/Core/Core.swift": "@available(*, deprecated)\npublic func old() -> Int { 1 }\npublic func use() -> Int { old() }\n"}),
    Case("M8-h", "M-8", "ゲートが -Xswiftc -warnings-as-errors を渡しても、manifest の treatAllWarnings(as: .warning) は勝つか", "spm",
         {"Package.swift": manifest('.target(name: "Core", swiftSettings: [.treatAllWarnings(as: .warning)])'),
          "Sources/Core/Core.swift": "@available(*, deprecated)\npublic func old() -> Int { 1 }\npublic func use() -> Int { old() }\n"},
         ["-Xswiftc", "-warnings-as-errors"]),
    Case("M8-i", "M-8", "ゲートが -Xswiftc -warnings-as-errors を渡しても、manifest の treatWarning(_:as: .warning) は勝つか", "spm",
         {"Package.swift": manifest('.target(name: "Core", swiftSettings: [.treatWarning("DeprecatedDeclaration", as: .warning)])'),
          "Sources/Core/Core.swift": "@available(*, deprecated)\npublic func old() -> Int { 1 }\npublic func use() -> Int { old() }\n"},
         ["-Xswiftc", "-warnings-as-errors"]),
    Case("M8-d", "M-8", "SwiftLint の baseline で既存違反を凍結できるか", "swiftlint",
         {".swiftlint.yml": "only_rules:\n  - force_unwrapping\nstrict: true\n",
          "a.swift": "func f(_ v: Int?) -> Int {\n    return v!\n}\n"},
         ["--baseline-from-write"]),
    Case("M8-e", "M-8", "swiftlint:disable all をファイル先頭に書くとファイル全体の違反が消えるか", "swiftlint",
         {".swiftlint.yml": "only_rules:\n  - force_unwrapping\nstrict: true\n",
          "a.swift": "// swiftlint:disable all\nfunc f(_ v: Int?) -> Int {\n    return v!\n}\n"}),
    Case("M8-f", "M-8", "swift-format-ignore-file でファイル全体の lint を消せるか", "swift-format",
         {"a.swift": "// swift-format-ignore-file\nlet Bad_name = 1\n"}),
    Case("M8-j", "M-8", ".swift-format の rules で規則を false にすると、リポジトリ全体の lint の指摘が消えるか", "swift-format",
         {".swift-format": "{\n  \"version\": 1,\n  \"rules\": {\n    \"AlwaysUseLowerCamelCase\": false\n  }\n}\n",
          "a.swift": "let Bad_name = 1\n"}),
    # 補足: Phase 1 の判断材料（M-1〜M-8 の外）
    Case("X-a", "補足", "裸の protocol 型（any 無し）は Swift 6 と警告エラーで通るか", "spm",
         {"Package.swift": manifest(f'.target(name: "Core", {STRICT_SETTINGS})'),
          "Sources/Core/Core.swift": "public protocol P {}\npublic func f(_ p: P) -> Int { 1 }\n"}),
    Case("X-b", "補足", "ExistentialAny を有効にすると裸の protocol 型は落ちるか", "spm",
         {"Package.swift": manifest('.target(name: "Core", swiftSettings: [.treatAllWarnings(as: .error), .enableUpcomingFeature("ExistentialAny")])'),
          "Sources/Core/Core.swift": "public protocol P {}\npublic func f(_ p: P) -> Int { 1 }\n"}),
    Case("X-c", "補足", "テスト target が無いパッケージで swift test は何を返すか", "spm",
         {"Package.swift": manifest(f'.target(name: "Core", {STRICT_SETTINGS})'),
          "Sources/Core/Core.swift": "public func f() -> Int { 1 }\n"},
         ["--test"]),
    Case("X-d", "補足", "UInt64 を変数の量で 64 以上シフトすると、落ちずに 0 になるか（盤の表現の判断材料）", "swiftc-run",
         {"main.swift": "let one: UInt64 = 1\nlet shift = Int(CommandLine.arguments.count) + 63\nprint(\"shifted=\\(one << shift) masked=\\(one &<< shift)\")\n"},
         ["-swift-version", "6"]),
    Case("X-e", "補足", "release 構成の swift test で @testable import は使えるか", "spm",
         {"Package.swift": manifest(f'.target(name: "Core", {STRICT_SETTINGS}), .testTarget(name: "CoreTests", dependencies: ["Core"], {STRICT_SETTINGS})'),
          "Sources/Core/Core.swift": "func hidden() -> Int { 1 }\n",
          "Tests/CoreTests/CoreTests.swift": "@testable import Core\nimport Testing\n\n@Test func hiddenIsOne() {\n    #expect(hidden() == 1)\n}\n"},
         ["--test", "-c", "release"]),
    Case("X-f", "補足", "対照: X-e の期待をわざと外すと落ちるか（release 構成でテストが実際に走っていること）", "spm",
         {"Package.swift": manifest(f'.target(name: "Core", {STRICT_SETTINGS}), .testTarget(name: "CoreTests", dependencies: ["Core"], {STRICT_SETTINGS})'),
          "Sources/Core/Core.swift": "func hidden() -> Int { 1 }\n",
          "Tests/CoreTests/CoreTests.swift": "@testable import Core\nimport Testing\n\n@Test func hiddenIsOne() {\n    #expect(hidden() == 2)\n}\n"},
         ["--test", "-c", "release"]),
]


def run(cmd: list[str], cwd: Path) -> tuple[int, str]:
    env = dict(os.environ, NO_COLOR="1")
    p = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True, env=env, timeout=900)
    return p.returncode, p.stdout + p.stderr


def diagnostics(output: str) -> list[str]:
    lines = []
    for line in output.splitlines():
        if DIAG.search(line) and not line.lstrip().startswith(("|", "`")):
            lines.append(line.strip())
    return lines[:6]


def render(cmd: list[str], tmp: str, swiftlint: str) -> str:
    words = ["swiftlint" if c == swiftlint else Path(c).name if c.startswith(tmp) else c for c in cmd]
    return " ".join(words)


def scrub(line: str, tmp: str) -> str:
    """一時ディレクトリの名前（パッケージ名にもなる）を消し、再実行で差分が出ないようにする。"""
    line = line.replace(tmp + "/", "")
    return re.sub(re.escape(Path(tmp).name), "<probe>", line, flags=re.IGNORECASE)


def write_files(base: Path, files: dict[str, str]) -> None:
    for rel, text in files.items():
        path = base / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding="utf-8")


def measure(case: Case, swiftlint: str) -> dict:
    with tempfile.TemporaryDirectory(prefix=f"wire-{case.id}-") as tmp:
        base = Path(tmp)
        write_files(base, case.files)
        sources = sorted(str(base / f) for f in case.files if f.endswith(".swift"))
        steps: list[tuple[int, str, list[str]]] = []
        if case.kind == "swiftc":
            cmd = ["swiftc", *case.args, "-module-name", "Probe", "-parse-as-library"]
            if "-typecheck" not in case.args:
                cmd += ["-c", "-o", str(base / "probe.o")] if len(sources) == 1 else ["-c", "-wmo", "-o", str(base / "probe.o")]
            cmd += sources
            steps.append((*run(cmd, base), cmd))
        elif case.kind == "swiftc-run":
            cmd = ["swiftc", *case.args, "-o", str(base / "probe"), *sources]
            code, out = run(cmd, base)
            steps.append((code, out, cmd))
            if code == 0:
                steps.append((*run([str(base / "probe")], base), ["./probe"]))
        elif case.kind == "xmod":
            write_files(base / "lib", case.lib)
            libsrc = sorted(str(base / "lib" / f) for f in case.lib)
            lib_cmd = ["swiftc", *STRICT, "-parse-as-library", "-module-name", "Lib", "-emit-module",
                       "-emit-module-path", str(base / "Lib.swiftmodule"), *libsrc]
            code, out = run(lib_cmd, base)
            steps.append((code, out, lib_cmd))
            cmd = ["swiftc", *case.args, "-parse-as-library", "-module-name", "Client", "-I", str(base),
                   "-c", "-o", str(base / "client.o"), *sources]
            steps.append((*run(cmd, base), cmd))
        elif case.kind == "spm":
            sub = ["test"] if "--test" in case.args else ["build"]
            rest = [a for a in case.args if a != "--test"]
            cmd = ["swift", *sub, "--scratch-path", str(base / ".build"), *rest]
            steps.append((*run(cmd, base), cmd))
        elif case.kind == "swiftlint":
            if "--baseline-from-write" in case.args:
                write_cmd = [swiftlint, "lint", "--quiet", "--write-baseline", "baseline.json", "a.swift"]
                steps.append((*run(write_cmd, base), write_cmd))
                cmd = [swiftlint, "lint", "--quiet", "--baseline", "baseline.json", "a.swift"]
            else:
                cmd = [swiftlint, "lint", "--quiet", "a.swift"]
            steps.append((*run(cmd, base), cmd))
        elif case.kind == "swift-format":
            cmd = ["swift-format", "lint", "--strict", "a.swift"]
            steps.append((*run(cmd, base), cmd))
        else:
            raise ValueError(case.kind)
        final_code, final_out, final_cmd = steps[-1]
        return {
            "id": case.id,
            "m": case.m,
            "question": case.question,
            "kind": case.kind,
            "command": render(final_cmd, tmp, swiftlint),
            "exit": final_code,
            "outcome": "rejected" if final_code != 0 else "accepted",
            "diagnostics": [scrub(d, tmp) for d in diagnostics(final_out)],
            "stdout_tail": scrub(final_out.strip().splitlines()[-1], tmp) if final_out.strip() else "",
            "prior_steps": [{"command": render(s[2], tmp, swiftlint), "exit": s[0]}
                            for s in steps[:-1]],
            "sources": case.files | {f"lib/{k}": v for k, v in case.lib.items()},
        }


def tool_version(cmd: list[str]) -> str:
    try:
        return subprocess.run(cmd, capture_output=True, text=True).stdout.strip().splitlines()[0]
    except (OSError, IndexError):
        return "unavailable"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--swiftlint", required=True)
    parser.add_argument("--only", nargs="*")
    args = parser.parse_args()
    # ケースは一時ディレクトリで回すので、相対パスのままだと見つからない
    args.swiftlint = str(Path(args.swiftlint).resolve())
    results = []
    for case in CASES:
        if args.only and case.id not in args.only:
            continue
        r = measure(case, args.swiftlint)
        print(f"{r['id']:6} exit={r['exit']:<3} {r['outcome']:8} {r['question']}", flush=True)
        for d in r["diagnostics"][:2]:
            print(f"         {d}", flush=True)
        results.append(r)
    doc = {
        "measured_on": subprocess.run(["date", "+%Y-%m-%d"], capture_output=True, text=True).stdout.strip(),
        "environment": {
            "swift": tool_version(["swift", "--version"]),
            "swift_format": tool_version(["swift-format", "--version"]),
            "swiftlint": tool_version([args.swiftlint, "version"]),
            "os": platform.platform(),
            "glibc": " ".join(platform.libc_ver()),
        },
        "note": "outcome は終了コードだけで決まる（rejected = 非 0）。判定は ADR 0001 に書く。",
        "results": results,
    }
    if not args.only:
        OUT.write_text(json.dumps(doc, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print(f"wrote {OUT.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

"""eng/conformance.py の正例・反例（QLT-007）。規則ごとに「違反で落ちる」と「正しい形は通る」の両方を見る。"""

from __future__ import annotations

import datetime as dt
import sys
import tempfile
import textwrap
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import conformance as c  # noqa: E402

GRAPH = textwrap.dedent("""\
    Core      kind=library    deps=
    Engine    kind=library    deps=Core
    Term      kind=library    deps=Engine std=Glibc unsafe=allowed
    Host      kind=library    deps=Core std=Glibc unsafe=allowed spawn=allowed
    app       kind=executable deps=Core,Engine,Term std=Glibc role=composition-root
    CoreTests kind=test       deps=Core std=Testing
    """)

SETTINGS = 'swiftSettings: [.treatAllWarnings(as: .error), .enableUpcomingFeature("ExistentialAny")]'


def package(*targets: str) -> str:
    return (
        "// swift-tools-version: 6.2\nimport PackageDescription\n\nlet package = Package(\n"
        '    name: "P",\n    targets: [\n        ' + ",\n        ".join(targets) + "\n    ],\n"
        "    swiftLanguageModes: [.v6]\n)\n"
    )


def lib(name: str, deps: str = "") -> str:
    return f'.target(name: "{name}", dependencies: [{deps}], {SETTINGS})'


class Repo:
    def __init__(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.root = Path(self._tmp.name)
        self.write("docs/architecture/module-graph.txt", GRAPH)
        self.write("Package.swift", package(lib("Core"), lib("Engine", '"Core"')))

    def write(self, rel: str, text: str) -> None:
        path = self.root / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding="utf-8")

    def remove(self, rel: str) -> None:
        (self.root / rel).unlink()

    def run(self, check, today: str = "2026-10-25") -> list[str]:
        ctx = c.Context(self.root, dt.date.fromisoformat(today))
        return [v.rule for v in check(ctx)]

    def close(self) -> None:
        self._tmp.cleanup()


class Base(unittest.TestCase):
    def setUp(self) -> None:
        self.repo = Repo()

    def tearDown(self) -> None:
        self.repo.close()

    def assertFires(self, check, rule: str, rel: str, text: str) -> None:
        self.repo.write(rel, text)
        self.assertIn(rule, self.repo.run(check), f"{rule} が {rel} で発火しない")

    def assertQuiet(self, check, rel: str, text: str) -> None:
        self.repo.write(rel, text)
        self.assertEqual([], self.repo.run(check), f"{rel} の正しい形で違反が出た")


class StripTest(unittest.TestCase):
    def test_comments_and_strings_are_blanked(self) -> None:
        src = 'let a = "default:" // default:\n/* case _: */ let b = 1\n'
        out = c.strip_swift(src)
        self.assertNotIn("default", out)
        self.assertNotIn("case _", out)
        self.assertEqual(src.count("\n"), out.count("\n"))

    def test_interpolation_stays_code(self) -> None:
        out = c.strip_swift('let s = "x\\(Int.random(in: 0..<3))y"\n')
        self.assertIn("Int.random(in: 0..<3)", out)
        self.assertNotIn("x", out.split("=")[1].replace("Int.random", ""))

    def test_raw_and_multiline_strings(self) -> None:
        out = c.strip_swift('let a = #"default:"#\nlet b = """\ncase _:\n"""\nlet c = 1\n')
        self.assertNotIn("default", out)
        self.assertNotIn("case _", out)
        self.assertIn("let c = 1", out)


class Cnf001(Base):
    def test_fires_on_generic_suffix(self) -> None:
        self.assertFires(c.cnf001, "CNF-001", "Sources/Core/TimeHelper.swift", "struct TimeHelper {}\n")

    def test_fires_on_generic_directory(self) -> None:
        self.assertFires(c.cnf001, "CNF-001", "Sources/Core/utils/Square.swift", "struct Square {}\n")

    def test_quiet_on_role_name(self) -> None:
        self.assertQuiet(c.cnf001, "Sources/Core/MoveGenerator.swift", "struct MoveGenerator {}\n")


class Cnf002(Base):
    def test_fires_on_two_types(self) -> None:
        self.assertFires(c.cnf002, "CNF-002", "Sources/Core/Piece.swift", "enum Piece {}\nenum Color {}\n")

    def test_fires_on_name_mismatch(self) -> None:
        self.assertFires(c.cnf002, "CNF-002", "Sources/Core/Pieces.swift", "public enum Piece {}\n")

    def test_quiet_on_nested_and_extension(self) -> None:
        self.assertQuiet(c.cnf002, "Sources/Core/Piece.swift",
                         "enum Piece {\n    enum Kind {}\n}\n\nextension Piece {\n    struct Inner {}\n}\n")


WAIVER = textwrap.dedent("""\
    # WVR-0001: 例
    - Status: active
    - Rule: `SWF-004`
    - Issue: #9
    - Owner: hide
    - Created: 2026-10-25
    - Expires: {expires}
    - Scope: `Sources/Core/Board.swift#Board`
    """)
INDEX = "| Waiver | 規則 |\n| --- | --- |\n| WVR-0001 | SWF-004 |\n"


class Cnf003(Base):
    def test_fires_on_diagnose(self) -> None:
        self.assertFires(c.cnf003, "CNF-003", "Sources/Core/Board.swift",
                         "@diagnose(DeprecatedDeclaration, as: ignored)\nfunc f() {}\n")

    def test_fires_on_deprecated_caller(self) -> None:
        self.assertFires(c.cnf003, "CNF-003", "Sources/Core/Board.swift", "@available(*, deprecated)\nfunc f() {}\n")

    def test_fires_on_format_ignore(self) -> None:
        self.assertFires(c.cnf003, "CNF-003", "Sources/Core/Board.swift", "// " + c.FORMAT_IGNORE + "\nlet x = 1\n")

    def test_fires_on_range_disable(self) -> None:
        self.assertFires(c.cnf003, "CNF-003", "Sources/Core/Board.swift", "// " + c.LINT_TOOL + ":disable force_unwrapping\n")

    def test_fires_without_waiver(self) -> None:
        self.assertFires(c.cnf003, "CNF-003", "Sources/Core/Board.swift",
                         "// " + c.LINT_TOOL + ":disable:next force_unwrapping\nlet x = y!\n")

    def test_quiet_with_active_waiver(self) -> None:
        self.repo.write("docs/waivers/WVR-0001-example.md", WAIVER.format(expires="2026-12-31"))
        self.repo.write("docs/waivers/README.md", INDEX)
        self.assertQuiet(c.cnf003, "Sources/Core/Board.swift",
                         "// Waiver: WVR-0001\n// " + c.LINT_TOOL + ":disable:next force_unwrapping\nlet x = y!\n")

    def test_quiet_on_available_without_deprecated(self) -> None:
        self.assertQuiet(c.cnf003, "Sources/Core/Board.swift", "@available(macOS 15, *)\nfunc f() {}\n")


class Cnf004(Base):
    def test_fires_on_expired(self) -> None:
        self.repo.write("docs/waivers/README.md", INDEX)
        self.assertFires(c.cnf004, "CNF-004", "docs/waivers/WVR-0001-example.md", WAIVER.format(expires="2026-10-24"))

    def test_fires_on_missing_index(self) -> None:
        self.repo.write("docs/waivers/README.md", "| Waiver |\n")
        self.assertFires(c.cnf004, "CNF-004", "docs/waivers/WVR-0001-example.md", WAIVER.format(expires="2026-12-31"))

    def test_fires_on_missing_field(self) -> None:
        self.repo.write("docs/waivers/README.md", INDEX)
        self.assertFires(c.cnf004, "CNF-004", "docs/waivers/WVR-0001-example.md",
                         WAIVER.format(expires="2026-12-31").replace("- Owner: hide\n", ""))

    def test_quiet_on_valid(self) -> None:
        self.repo.write("docs/waivers/README.md", INDEX)
        self.assertQuiet(c.cnf004, "docs/waivers/WVR-0001-example.md", WAIVER.format(expires="2026-10-25"))


class Cnf005(Base):
    def test_fires_on_baseline_file(self) -> None:
        self.assertFires(c.cnf005, "CNF-005", "lint-" + c.BASE_WORD + ".json", "{}\n")

    def test_fires_on_weakened_makefile(self) -> None:
        self.assertFires(c.cnf005, "CNF-005", "Makefile", "lint:\n\tswiftlint " + c.GATE_WEAKENERS[0] + " x.json\n")

    def test_fires_on_lint_exclusion(self) -> None:
        self.assertFires(c.cnf005, "CNF-005", ".swiftlint.yml", "strict: true\nexcluded:\n  - Sources\n")

    def test_fires_without_strict(self) -> None:
        self.assertFires(c.cnf005, "CNF-005", ".swiftlint.yml", "only_rules:\n  - force_unwrapping # SWF-004\n")

    def test_fires_on_ignored_sources(self) -> None:
        self.assertFires(c.cnf005, "CNF-005", ".gitignore", ".build/\nSources/Core/\n")

    def test_fires_on_format_rule_switch(self) -> None:
        self.assertFires(c.cnf005, "CNF-005", ".swift-format",
                         '{"version": 1, "rules": {"AlwaysUseLowerCamelCase": false}}\n')

    def test_fires_on_unreadable_format_config(self) -> None:
        self.assertFires(c.cnf005, "CNF-005", ".swift-format", "version: 1\n")

    def test_quiet_on_clean(self) -> None:
        self.repo.write(".swift-format", '{"version": 1, "indentation": {"spaces": 4}, "lineLength": 120}\n')
        self.repo.write(".gitignore", ".build/\n.tools/\n")
        self.repo.write("Makefile", "check:\n\tswift build\n")
        self.assertQuiet(c.cnf005, ".swiftlint.yml", "strict: true\nonly_rules:\n  - force_unwrapping # SWF-004\n")


DOC = textwrap.dedent("""\
    # 憲章

    ### ARC-001 — 一つの経路

    本文。CNF-001 を参照する。

    - 機械強制: **{arc_state}**
    """)
GATES = textwrap.dedent("""\
    # ゲート

    | ID | 内容 | 規則 | 状態 |
    | --- | --- | --- | --- |
    | `CNF-001` | 総称名 | ARC-001 | {cnf_state} |

    ## 3. 強制マトリクス

    | 規則 | 状態 | 実体 |
    | --- | --- | --- |
    {rows}

    ## 4. 次
    """)


class Cnf006(Base):
    def write_docs(self, arc_state="planned", cnf_state="planned", rows=None, extra="", proofs="") -> None:
        rows = rows if rows is not None else "| ARC-001 | planned | x |\n| CNF-001 | planned | x |"
        self.repo.write("docs/ARCHITECTURE_CONSTITUTION.md", DOC.format(arc_state=arc_state) + extra)
        self.repo.write("docs/QUALITY_GATES.md", GATES.format(cnf_state=cnf_state, rows=rows))
        self.repo.write("docs/quality/gate-proofs.md", proofs)

    def test_quiet_on_consistent(self) -> None:
        self.write_docs()
        self.assertEqual([], self.repo.run(c.cnf006))

    def test_fires_on_missing_matrix_row(self) -> None:
        self.write_docs(rows="| ARC-001 | planned | x |")
        self.assertIn("CNF-006", self.repo.run(c.cnf006))

    def test_fires_on_undefined_reference(self) -> None:
        self.write_docs(extra="\nARC-999 を参照する。\n")
        self.assertIn("CNF-006", self.repo.run(c.cnf006))

    def test_fires_on_state_mismatch(self) -> None:
        self.write_docs(arc_state="active", proofs="| ARC-001 | x |\n")
        self.assertIn("CNF-006", self.repo.run(c.cnf006))

    def test_fires_on_active_without_proof(self) -> None:
        self.write_docs(arc_state="active", rows="| ARC-001 | active | x |\n| CNF-001 | planned | x |")
        self.assertIn("CNF-006", self.repo.run(c.cnf006))

    def test_quiet_on_active_with_proof(self) -> None:
        self.write_docs(arc_state="active", rows="| ARC-001 | active | x |\n| CNF-001 | planned | x |",
                        proofs="| ARC-001 | 違反 | make check | 失敗 |\n")
        self.assertEqual([], self.repo.run(c.cnf006))

    def test_fires_on_active_with_empty_proof_row(self) -> None:
        for row in ("| ARC-001 |  |  |  |\n", "| ARC-001 | 違反 | make check | 未実測 |\n", "| ARC-001 |\n"):
            with self.subTest(row=row):
                self.write_docs(arc_state="active", rows="| ARC-001 | active | x |\n| CNF-001 | planned | x |", proofs=row)
                self.assertIn("CNF-006", self.repo.run(c.cnf006))

    def test_fires_on_unknown_state(self) -> None:
        self.write_docs(rows="| ARC-001 | done | x |\n| CNF-001 | planned | x |")
        self.assertIn("CNF-006", self.repo.run(c.cnf006))

    def test_fires_on_duplicate_definition(self) -> None:
        self.write_docs(extra="\n### ARC-001 — 二度目\n\n- 機械強制: **planned**\n")
        self.assertIn("CNF-006", self.repo.run(c.cnf006))


class Cnf007(Base):
    def setUp(self) -> None:
        super().setUp()
        self.repo.write(".swiftlint.yml", "strict: true\nonly_rules:\n  - force_unwrapping # SWF-004\n")
        self.repo.write(".swift-format", "{}\n")
        self.repo.write("Makefile", "lint:\n\tx --config .swiftlint.yml\nformat:\n\ty --configuration .swift-format\n")

    def test_quiet_on_wired(self) -> None:
        self.assertEqual([], self.repo.run(c.cnf007))

    def test_fires_on_nested_config(self) -> None:
        self.assertFires(c.cnf007, "CNF-007", "Sources/Core/.swiftlint.yml", "disabled_rules: []\n")

    def test_fires_on_unwired_config(self) -> None:
        self.assertFires(c.cnf007, "CNF-007", "Makefile", "lint:\n\tx\n")

    def test_fires_on_rule_without_id(self) -> None:
        self.assertFires(c.cnf007, "CNF-007", ".swiftlint.yml", "strict: true\nonly_rules:\n  - force_unwrapping\n")


class Cnf008(Base):
    def test_fires_without_issue(self) -> None:
        self.assertFires(c.cnf008, "CNF-008", "Sources/Core/Board.swift", "// " + c.TODO_WORDS[0] + " あとで\n")

    def test_quiet_with_issue(self) -> None:
        self.assertQuiet(c.cnf008, "Sources/Core/Board.swift", "// " + c.TODO_WORDS[0] + " (#12) あとで\n")


class Cnf009(Base):
    def test_quiet_on_canonical(self) -> None:
        self.assertEqual([], self.repo.run(c.cnf009))

    def test_fires_on_missing_setting(self) -> None:
        self.assertFires(c.cnf009, "CNF-009", "Package.swift", package('.target(name: "Core")'))

    def test_fires_on_downgrade(self) -> None:
        self.assertFires(c.cnf009, "CNF-009", "Package.swift", package(
            '.target(name: "Core", swiftSettings: [.treatAllWarnings(as: .warning), .enableUpcomingFeature("ExistentialAny")])'))

    def test_fires_on_unsafe_flags(self) -> None:
        self.assertFires(c.cnf009, "CNF-009", "Package.swift", package(
            '.target(name: "Core", swiftSettings: [.treatAllWarnings(as: .error), '
            '.enableUpcomingFeature("ExistentialAny"), .unsafeFlags(["-Onone"])])'))

    def test_fires_on_unlisted_package(self) -> None:
        text = package(lib("Core")).replace(
            '    targets:', '    dependencies: [.package(url: "https://example.com/x.git", exact: "1.0.0")],\n    targets:')
        self.assertFires(c.cnf009, "CNF-009", "Package.swift", text)

    def test_fires_on_path(self) -> None:
        self.assertFires(c.cnf009, "CNF-009", "Package.swift",
                         package(f'.target(name: "Core", path: "src", {SETTINGS})'))

    def test_quiet_on_empty_targets(self) -> None:
        self.assertQuiet(c.cnf009, "Package.swift", package().replace("targets: [\n        \n    ]", "targets: []"))


class Cnf010(Base):
    def test_quiet_on_matching(self) -> None:
        self.assertEqual([], self.repo.run(c.cnf010))

    def test_fires_on_reverse_dependency(self) -> None:
        self.assertFires(c.cnf010, "CNF-010", "Package.swift", package(lib("Core", '"Engine"'), lib("Engine", '"Core"')))

    def test_fires_on_unknown_target(self) -> None:
        self.assertFires(c.cnf010, "CNF-010", "Package.swift", package(lib("Core"), lib("Misc")))

    def test_fires_on_cycle_in_graph(self) -> None:
        self.assertFires(c.cnf010, "CNF-010", "docs/architecture/module-graph.txt",
                         "Core kind=library deps=Engine\nEngine kind=library deps=Core\n")


class Cnf011(Base):
    def test_fires_on_foundation_in_core(self) -> None:
        self.assertFires(c.cnf011, "CNF-011", "Sources/Core/Board.swift", "import Foundation\n")

    def test_fires_on_xctest(self) -> None:
        self.assertFires(c.cnf011, "CNF-011", "Tests/CoreTests/BoardTests.swift", "import XCTest\n")

    def test_fires_on_unknown_directory(self) -> None:
        self.assertFires(c.cnf011, "CNF-011", "Sources/Extra/Board.swift", "let x = 1\n")

    def test_quiet_on_allowed(self) -> None:
        self.repo.write("Sources/Term/Screen.swift", "import Glibc\nimport Engine\n")
        self.assertQuiet(c.cnf011, "Tests/CoreTests/BoardTests.swift", "import Testing\n@testable import Core\n")


class Cnf012(Base):
    def test_fires_on_system_random(self) -> None:
        self.assertFires(c.cnf012, "CNF-012", "Sources/Engine/Search.swift", "let x = Int.random(in: 0..<3)\n")

    def test_fires_on_clock(self) -> None:
        self.assertFires(c.cnf012, "CNF-012", "Sources/Core/Board.swift", "let t = ContinuousClock.now\n")

    def test_fires_on_command_line_in_tests(self) -> None:
        self.assertFires(c.cnf012, "CNF-012", "Tests/CoreTests/BoardTests.swift", "let n = CommandLine.arguments.count\n")

    def test_fires_on_shuffled(self) -> None:
        self.assertFires(c.cnf012, "CNF-012", "Sources/Engine/Search.swift", "let m = moves.shuffled()\n")

    def test_quiet_on_injected_generator(self) -> None:
        self.assertQuiet(c.cnf012, "Sources/Engine/Search.swift",
                         "let x = Int.random(in: 0..<3, using: &rng)\nlet m = moves.randomElement(using: &rng)\nlet s = moveTime(1)\n")

    def test_quiet_in_composition_root(self) -> None:
        self.assertQuiet(c.cnf012, "Sources/app/main.swift", "let t = ContinuousClock.now\nlet a = CommandLine.arguments\n")


class Cnf013(Base):
    def test_fires_on_each_catch_all(self) -> None:
        for body in ("default: return 0", "@unknown default: return 0", "case _: return 0", "case let other: return 0",
                     "case var (other): return 0", "case (let other): return 0", "case .b, _: return 0",
                     "case .b,\n         _: return 0", "case let (x, y): return 0", "case (_, let y): return 0"):
            with self.subTest(body=body):
                self.assertFires(c.cnf013, "CNF-013", "Sources/Core/Board.swift",
                                 f"func f(_ s: S) -> Int {{\n    switch s {{\n    case .a: return 1\n    {body}\n    }}\n}}\n")

    def test_quiet_on_exhaustive_and_labels(self) -> None:
        self.assertQuiet(c.cnf013, "Sources/Core/Board.swift",
                         "func f(_ s: S, _ t: S) -> Int {\n    switch (s, t) {\n    case (.a, _): return 1\n    case (.b, _): return 2\n    }\n}\n"
                         "let v = counts[key, default: 0]\n")

    def test_quiet_on_refutable_patterns_and_declarations(self) -> None:
        self.assertQuiet(c.cnf013, "Sources/Core/Board.swift",
                         "enum S {\n    case a, b\n    case pair(x: Int, y: Int)\n    case raw = 1\n}\n"
                         "func f(_ s: S, _ o: Int?) -> Int {\n    switch s {\n    case .a, .b: return 1\n"
                         "    case let .pair(x, y): return x + y\n    case .raw where o != nil: return 2\n    case .raw: return 3\n    }\n}\n"
                         "func g(_ o: Int?) -> Int {\n    switch o {\n    case .some(let v): return v > 0 ? 1 : 0\n    case .none: return 0\n    }\n}\n")


class Cnf014(Base):
    def test_fires_on_unsafe_in_core(self) -> None:
        self.assertFires(c.cnf014, "CNF-014", "Sources/Core/Board.swift", "let s = unsafeBitCast(1, to: Square.self)\n")

    def test_fires_on_reflection_everywhere(self) -> None:
        self.assertFires(c.cnf014, "CNF-014", "Sources/Term/Screen.swift", "let m = Mirror(reflecting: x)\n")

    def test_fires_on_preconcurrency(self) -> None:
        self.assertFires(c.cnf014, "CNF-014", "Sources/Term/Screen.swift", "@preconcurrency import Glibc\n")

    def test_quiet_on_unsafe_in_allowed_target(self) -> None:
        self.assertQuiet(c.cnf014, "Sources/Term/Screen.swift", "withUnsafeMutablePointer(to: &t) { p in _ = p }\n")


class Cnf015(Base):
    def test_fires_on_codable(self) -> None:
        self.assertFires(c.cnf015, "CNF-015", "Sources/Core/Square.swift", "struct Square: Decodable {}\n")

    def test_quiet_on_plain(self) -> None:
        self.assertQuiet(c.cnf015, "Sources/Core/Square.swift", "struct Square: Hashable {}\n")


class Cnf016(Base):
    def test_fires_on_public_stored_var(self) -> None:
        self.assertFires(c.cnf016, "CNF-016", "Sources/Core/Board.swift", "public struct Board {\n    public var size: Int\n}\n")

    def test_fires_on_open(self) -> None:
        self.assertFires(c.cnf016, "CNF-016", "Sources/Core/Board.swift", "open class Board {}\n")

    def test_quiet_on_let_and_computed(self) -> None:
        self.assertQuiet(c.cnf016, "Sources/Core/Board.swift",
                         "public struct Board {\n    public let size: Int\n    public private(set) var moves: Int\n"
                         "    public var isEmpty: Bool { size == 0 }\n}\n")


class Cnf017(Base):
    def test_fires_on_print_in_library(self) -> None:
        self.assertFires(c.cnf017, "CNF-017", "Sources/Core/Board.swift", "func f() { print(1) }\n")

    def test_quiet_in_composition_root_and_methods(self) -> None:
        self.repo.write("Sources/app/main.swift", "print(1)\nexit(0)\n")
        self.assertQuiet(c.cnf017, "Sources/Core/Board.swift", "func f(r: R) { r.print(1) }\n")


WORKFLOW = textwrap.dedent("""\
    name: CI
    on:
      pull_request:
    permissions:
      contents: read
    jobs:
      check:
        runs-on: ubuntu-22.04
        steps:
          - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
          - run: eng/ci-require-ready.sh ${{ github.event.pull_request.draft }}
          - run: eng/install-swift.sh
          - run: make check BASE=${{ github.event.pull_request.base.sha }}
    """)


class Cnf018(Base):
    def test_quiet_on_canonical(self) -> None:
        self.assertQuiet(c.cnf018, ".github/workflows/ci.yml", WORKFLOW)

    def test_fires_on_tag_pin(self) -> None:
        self.assertFires(c.cnf018, "CNF-018", ".github/workflows/ci.yml",
                         WORKFLOW.replace("@3d3c42e5aac5ba805825da76410c181273ba90b1", "@v7"))

    def test_fires_on_extra_run(self) -> None:
        self.assertFires(c.cnf018, "CNF-018", ".github/workflows/ci.yml",
                         WORKFLOW + "      - run: swift build\n")

    def test_fires_on_skip_condition(self) -> None:
        self.assertFires(c.cnf018, "CNF-018", ".github/workflows/ci.yml",
                         WORKFLOW.replace("    runs-on:", "    if: ${{ !github.event.pull_request.draft }}\n    runs-on:"))

    def test_fires_on_write_permission(self) -> None:
        self.assertFires(c.cnf018, "CNF-018", ".github/workflows/ci.yml",
                         WORKFLOW.replace("  contents: read\n", "  contents: write\n"))


class Cnf019(Base):
    def test_fires_on_throws_in_sources(self) -> None:
        self.assertFires(c.cnf019, "CNF-019", "Sources/Core/BoardText.swift", "func parse() throws -> Int { 1 }\n")

    def test_quiet_in_tests(self) -> None:
        self.assertQuiet(c.cnf019, "Tests/CoreTests/BoardTextTests.swift", "@Test func f() throws { _ = try #require(x) }\n")


class Cnf020(Base):
    def test_fires_on_any(self) -> None:
        self.assertFires(c.cnf020, "CNF-020", "Sources/Core/Bag.swift", "let bag: [String: Any] = [:]\n")

    def test_quiet_on_existential(self) -> None:
        self.assertQuiet(c.cnf020, "Sources/Core/Bag.swift", "func f(_ g: inout any RandomNumberGenerator) {}\n")


class Cnf021(Base):
    def test_fires_on_init_in_extension(self) -> None:
        self.assertFires(c.cnf021, "CNF-021", "Sources/Core/Square+Bypass.swift",
                         "extension Square {\n    init(bypass: Int) { index = bypass }\n}\n")

    def test_fires_on_failable_public_init_in_extension(self) -> None:
        self.assertFires(c.cnf021, "CNF-021", "Sources/Core/Square+Text.swift",
                         "public extension Square {\n    /// 文。\n    @inlinable public init?(text: String) { return nil }\n}\n")

    def test_quiet_on_init_in_type_body_and_calls(self) -> None:
        self.assertQuiet(c.cnf021, "Sources/Core/Square.swift",
                         "struct Square {\n    let index: Int\n    private init(index: Int) { self.index = index }\n}\n\n"
                         "extension Square {\n    static func make(_ i: Int) -> Square? { i < 64 ? Square(index: i) : nil }\n"
                         "    func initials() -> Int { index }\n}\n")


class Cnf022(Base):
    def test_fires_on_each_concurrency_word(self) -> None:
        for body in ("func f() async -> Int { 1 }", "let t = Task { 1 }", "actor Box {}", "let q = DispatchQueue(label: \"x\")",
                     "func g() async { _ = try? await Task.sleep(for: .seconds(1)) }"):
            with self.subTest(body=body):
                self.assertFires(c.cnf022, "CNF-022", "Sources/Core/Board.swift", body + "\n")

    def test_fires_in_tests(self) -> None:
        self.assertFires(c.cnf022, "CNF-022", "Tests/CoreTests/BoardTests.swift", "@Test func f() async {}\n")

    def test_quiet_on_plain_code(self) -> None:
        self.assertQuiet(c.cnf022, "Sources/Core/Board.swift", "struct Board: Sendable {\n    let tasks = 1\n}\n")


class Cnf023(Base):
    def test_fires_on_spawn_outside_host(self) -> None:
        for call in ("posix_spawn(&pid, path, nil, nil, argv, nil)", "fork()", "execvp(path, argv)", "system(cmd)", "popen(cmd, mode)"):
            with self.subTest(call=call):
                self.assertFires(c.cnf023, "CNF-023", "Sources/Term/Screen.swift", f"let r = {call}\n")

    def test_fires_in_core_and_tests(self) -> None:
        self.assertFires(c.cnf023, "CNF-023", "Sources/Core/Feed.swift", "let r = posix_spawnp(&pid, file, nil, nil, argv, nil)\n")
        self.assertFires(c.cnf023, "CNF-023", "Tests/CoreTests/FeedTests.swift", "let r = fork()\n")

    def test_quiet_in_host(self) -> None:
        self.assertQuiet(c.cnf023, "Sources/Host/Child.swift", "let r = posix_spawnp(&pid, file, nil, nil, argv, nil)\n")

    def test_quiet_on_words_and_comments(self) -> None:
        self.assertQuiet(c.cnf023, "Sources/Core/Feed.swift", "// fork() here\nlet forked = 1\nlet s = \"system()\"\n")


if __name__ == "__main__":
    unittest.main()

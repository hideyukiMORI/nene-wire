# ゲート発火の証明 — NeNe Wire

> Status: 記録 / 最終実測 2026-10-26（61 件すべて pass・`python3 eng/prove-gates.py`・結果の正本は [gate-proofs.json](gate-proofs.json)）
> 根拠となる規則: QLT-007（カスタムゲートには negative proof が要る）

**検査は「落ちること」を見るまで信用しない。** 各ゲートについて、最小の違反を仕込んだ状態で
意図した規則 ID によって失敗すること、そして元に戻すと `make check` が緑に戻ることを実測する。
ゲートを変えたら、この記録も同じ変更で更新する。

🔴 **この文書に結果を先に書かない。** 結果の列は実測するまで **未実測** のままにする。
🔴 **NeNe Reversi から移植した検査も、証明はこのリポジトリで取り直す**（ADR 0003）。Reversi の証明の結果は 1 つも写していない。

証明は `eng/prove-gates.py` が行う。作業木（git が追跡するか追跡し得るファイルと `.git`）を一時ディレクトリへ複製し、
依存グラフの正本どおりの 5 target と規則に沿った最小のソース（「足場」）を置いてから違反を **1 か所だけ** 仕込み、
`make check`（いくつかはより狭いタスク）を回す。
**意図した規則 ID（または道具の規則名）が出力に現れて失敗したとき**だけ pass とする。別の理由で落ちたものは証明にならない。
作業木そのものには触れない。足場は証明のための一時物で、リポジトリには入れていない。
`prove-gates.py` は、強制マトリクスで active の規則に証明が 1 つも無いと exit 1 で終わる。

環境: WSL2 Ubuntu（glibc 2.35）/ Swift 6.4.1（swiftly）/ swift-format 6.4.1 / SwiftLint 0.65.1（swiftlint-static）/ Python 3.10.12
CI: GitHub Actions `ubuntu-22.04` / Swift 6.4.1（固定の tarball・`eng/install-swift.sh`）

---

## 1. 実測結果

### 1-a. active の規則（規則 ID ごとの発火と復帰）

🔴 **文書整合検査（CNF-006）は「`| <規則 ID> |` で始まる行」を active の証明として読む。** active に書き換える規則は、
必ずこの表に規則 ID を行頭にして 1 行足す。
表は `python3 eng/prove-gates.py`（測り直す）か `--render`（測らずに作り直す）が gate-proofs.json と QUALITY_GATES.md の active の行から生成する。手で書かない。
規則を active に書き換えたら、**先に `--render` で表を作ってから**測り直す（複製の中で CNF-006 が「証明行が無い」で先に落ち、対照まで落ちる）。

<!-- proofs:active:start -->
| 規則 | 最小の違反 | 検証経路 | 実測 |
| --- | --- | --- | --- |
| ARC-002 | P01: Core が宣言していない Render を import する<br>P02: Terminal が正本に無い Core への依存を宣言する（循環は作らない）<br>P62: Core で posix_spawn を呼んで子プロセスを起動する（外部プロセスは Host だけ）<br>P63: Terminal が宣言していない推移的な依存の Core を import する（SwiftPM は拒まない・M6-e） | `make check`<br>`make conformance` | P01: exit 2・`Sources/NeNeWireCore/Probe.swift:1:8: error: no such module 'NeNeWireRender'`<br>P02: exit 2・`CNF-010 Package.swift:14: target NeNeWireTerminal の依存が正本と違う（余分: NeNeWireCore / 不足: なし）`<br>P62: exit 2・`CNF-023 Sources/NeNeWireCore/Probe.swift:5: 外部プロセスの起動（posix_spawn / fork / exec / system / popen）は spawn=allowed の targe`<br>P63: exit 2・`CNF-011 Sources/NeNeWireTerminal/Screen.swift:2: NeNeWireTerminal は NeNeWireCore を import できない` |
| ARC-003 | P03: Core が Foundation を import する<br>P64: Core が FoundationEssentials を import する（Foundation とは別の名前で Date が読める・M5-j） | `make check` | P03: exit 2・`CNF-011 Sources/NeNeWireCore/Probe.swift:1: NeNeWireCore は Foundation を import できない`<br>P64: exit 2・`CNF-011 Sources/NeNeWireCore/Probe.swift:1: NeNeWireCore は FoundationEssentials を import できない` |
| ARC-007 | P04: Render が using: の無い Int.random を呼ぶ<br>P05: Core のテストが CommandLine.arguments を読む（テストにも禁止がかかる）<br>P64: Core が FoundationEssentials を import する（Foundation とは別の名前で Date が読める・M5-j） | `make check` | P04: exit 2・`CNF-012 Sources/NeNeWireRender/Pick.swift:7: random(...) は using: で乱数源を受け取る`<br>P05: exit 2・`CNF-012 Tests/NeNeWireCoreTests/ProbeTests.swift:3: 時刻・乱数・環境・プロセス状態は合成ルートだけが読む`<br>P64: exit 2・`CNF-011 Sources/NeNeWireCore/Probe.swift:1: NeNeWireCore は FoundationEssentials を import できない` |
| SWF-002 | P06: enum に case を足し、switch を直さない<br>P07: switch に default: を書く<br>P44: 有効にした SwiftLint の 16 規則それぞれの違反を 1 ファイルに置く（設定の全規則が実際に発火すること）<br>P50: 文字列の switch の全捕捉を case _ where true: と書く（CNF-013 の字句の外の書き方。コンパイラが網羅に数えないこと）<br>P55: switch に case (let other): を書く（括弧で包んだ束縛・M1-j）<br>P56: switch に case .none, _: を書く（並べた選択肢の中の _・M1-k）<br>P57: タプルの switch に case (_, _): を書く（全位置が _ のタプル・M1-m） | `make check` | P06: exit 2・`Sources/NeNeWireCore/Side.swift:10:5: error: switch must be exhaustive`<br>P07: exit 2・`CNF-013 Sources/NeNeWireCore/Side.swift:15: 全捕捉（default / @unknown default / case _ / case let x / 括弧や並びに隠れた _ と束縛）は網羅性検`<br>P44: exit 2・`Sources/NeNeWireCore/Probe.swift:584:22: error: Blanket Disable Command Violation: Use 'next', 'this' or 'previous' inst`<br>P50: exit 2・`Sources/NeNeWireCore/Probe.swift:5:9: error: switch must be exhaustive`<br>P55: exit 2・`CNF-013 Sources/NeNeWireCore/Side.swift:15: 全捕捉（default / @unknown default / case _ / case let x / 括弧や並びに隠れた _ と束縛）は網羅性検`<br>P56: exit 2・`CNF-013 Sources/NeNeWireCore/Side.swift:15: 全捕捉（default / @unknown default / case _ / case let x / 括弧や並びに隠れた _ と束縛）は網羅性検`<br>P57: exit 2・`CNF-013 Sources/NeNeWireCore/Pair.swift:11: 全捕捉（default / @unknown default / case _ / case let x / 括弧や並びに隠れた _ と束縛）は網羅性検` |
| SWF-003 | P09: 公開の格納 var を置く | `make check` | P09: exit 2・`CNF-016 Sources/NeNeWireRender/Cell.swift:3: public の格納 var は外から変更できる（let か private(set) にする）` |
| SWF-004 | P10: 強制アンラップを書く<br>P44: 有効にした SwiftLint の 16 規則それぞれの違反を 1 ファイルに置く（設定の全規則が実際に発火すること） | `make check` | P10: exit 2・`Sources/nene-wire/main.swift:10:13: error: Force Unwrapping Violation: Force unwrapping should be avoided (force_unwrapp`<br>P44: exit 2・`Sources/NeNeWireCore/Probe.swift:584:22: error: Blanket Disable Command Violation: Use 'next', 'this' or 'previous' inst` |
| SWF-005 | P11: 製品コードに throws を書く<br>P44: 有効にした SwiftLint の 16 規則それぞれの違反を 1 ファイルに置く（設定の全規則が実際に発火すること） | `make check` | P11: exit 2・`CNF-019 Sources/NeNeWireCore/Probe.swift:4: 期待される失敗は閉じた結果型で返す（throw / try / catch は使えない）`<br>P44: exit 2・`Sources/NeNeWireCore/Probe.swift:584:22: error: Blanket Disable Command Violation: Use 'next', 'this' or 'previous' inst` |
| SWF-006 | P12: Any を使う<br>P13: 要素 3 つのタプルを返す<br>P44: 有効にした SwiftLint の 16 規則それぞれの違反を 1 ファイルに置く（設定の全規則が実際に発火すること） | `make check` | P12: exit 2・`CNF-020 Sources/NeNeWireCore/Probe.swift:4: Any / AnyObject / AnyHashable / AnyClass は使えない`<br>P13: exit 2・`Sources/NeNeWireCore/Probe.swift:4:29: error: Large Tuple Violation: Tuples should have at most 2 members (large_tuple)`<br>P44: exit 2・`Sources/NeNeWireCore/Probe.swift:584:22: error: Blanket Disable Command Violation: Use 'next', 'this' or 'previous' inst` |
| SWF-009 | P14: Core で unsafeBitCast を使う<br>P60: Terminal で @preconcurrency import を書く（並行性の error を戻らない warning に下げる・M7-i） | `make check`<br>`make conformance` | P14: exit 2・`CNF-014 Sources/NeNeWireCore/Probe.swift:3: unsafe 系の API は unsafe=allowed の target だけ`<br>P60: exit 2・`CNF-014 Sources/NeNeWireTerminal/Screen.swift:1: リフレクション・下線付き属性・@preconcurrency・マクロ・動的呼び出しは使えない` |
| SWF-010 | P15: 型を BoardHelper と名付ける | `make check` | P15: exit 2・`CNF-001 Sources/NeNeWireCore/BoardHelper.swift:2: 総称名の型 BoardHelper` |
| SWF-011 | P16: 1 ファイルに最上位の型を 2 つ置く | `make check` | P16: exit 2・`CNF-002 Sources/NeNeWireCore/Probe.swift:5: 主要宣言が 2 個ある: Probe, Other` |
| SWF-012 | P17: 引数 5 つの関数を書く<br>P18: 循環的複雑度 11 の関数を書く（SwiftLint は if 11 個を 11 と数える）<br>P44: 有効にした SwiftLint の 16 規則それぞれの違反を 1 ファイルに置く（設定の全規則が実際に発火すること） | `make check` | P17: exit 2・`Sources/NeNeWireCore/Probe.swift:4:12: error: Function Parameter Count Violation: Function should have 4 parameters or l`<br>P18: exit 2・`Sources/NeNeWireCore/Probe.swift:4:5: error: Cyclomatic Complexity Violation: Function should have complexity 10 or less`<br>P44: exit 2・`Sources/NeNeWireCore/Probe.swift:584:22: error: Blanket Disable Command Violation: Use 'next', 'this' or 'previous' inst` |
| SWF-013 | P59: Core に async の関数を書く | `make check` | P59: exit 2・`CNF-022 Sources/NeNeWireCore/Probe.swift:4: async / await / Task / actor / Thread / Dispatch は使えない（並行の形は合成ルートの 1 本のループだけ` |
| SWF-014 | P03: Core が Foundation を import する<br>P64: Core が FoundationEssentials を import する（Foundation とは別の名前で Date が読める・M5-j） | `make check` | P03: exit 2・`CNF-011 Sources/NeNeWireCore/Probe.swift:1: NeNeWireCore は Foundation を import できない`<br>P64: exit 2・`CNF-011 Sources/NeNeWireCore/Probe.swift:1: NeNeWireCore は FoundationEssentials を import できない` |
| SWF-015 | P19: waiver 無しの swiftlint:disable:next で強制アンラップを抑制する<br>P20: @diagnose で非推奨の警告を消す<br>P21: 期限切れの active な waiver を台帳と索引に置く<br>P44: 有効にした SwiftLint の 16 規則それぞれの違反を 1 ファイルに置く（設定の全規則が実際に発火すること）<br>P60: Terminal で @preconcurrency import を書く（並行性の error を戻らない warning に下げる・M7-i） | `make check`<br>`make conformance` | P19: exit 2・`CNF-003 Sources/nene-wire/main.swift:10: 直前行に有効な // Waiver: WVR-NNNN が無い`<br>P20: exit 2・`CNF-003 Sources/NeNeWireCore/Probe.swift:3: @available(..., deprecated) は非推奨の警告を隠す`<br>P21: exit 2・`CNF-004 docs/waivers/WVR-0001:1: 期限切れの waiver（2026-10-24）`<br>P44: exit 2・`Sources/NeNeWireCore/Probe.swift:584:22: error: Blanket Disable Command Violation: Use 'next', 'this' or 'previous' inst`<br>P60: exit 2・`CNF-014 Sources/NeNeWireTerminal/Screen.swift:1: リフレクション・下線付き属性・@preconcurrency・マクロ・動的呼び出しは使えない` |
| SWF-016 | P22: テストで XCTest を import する | `make check` | P22: exit 2・`CNF-011 Tests/NeNeWireCoreTests/ProbeTests.swift:1: NeNeWireCoreTests は XCTest を import できない` |
| QLT-001 | P35: CI に make check 以外の run（swift build）を足す<br>P37: .swift-version を実際の版と違う 6.4.0 にする<br>P48: テストの期待値を 1 つ変える（make check の中で swift test が実際に回って落ちること） | `make check` | P35: exit 2・`CNF-018 .github/workflows/ci.yml:30: CI で許す run はツールチェーン導入とゲートの 1 行だけ: swift build`<br>P37: exit 2・`tools: swift は 6.4.0 が要るが、起動できない: The swift version file `.swift-version` requires toolchain version 6.4.0, which is not`<br>P48: exit 2・`✘ Test datesInBothFormats() recorded an issue at FetchTests.swift:8:9: Expectation failed: DateText.parse("Mon, 26 Oct 2` |
| QLT-002 | P23: target の警告設定を treatAllWarnings(as: .warning) に緩める（警告の出るコードは置かない。設定そのものを拒むこと）<br>P24: 未使用のローカル定数を置く（警告がエラーになること）<br>P47: ソースの無いテスト target を manifest に足す（SwiftPM 自身が警告を出し、コンパイラの警告エラーの外にある） | `make check` | P23: exit 2・`CNF-009 Package.swift:8: target NeNeWireCore に .treatAllWarnings(as: .error) が無い`<br>P24: exit 2・`Sources/NeNeWireCore/Probe.swift:5:13: error: initialization of immutable value 'unused' was never used; consider replac`<br>P47: exit 2・`swift-strict: SwiftPM かコンパイラが警告を出した（QLT-002）` |
| QLT-003 | P25: 名前に baseline を含むファイルを置く<br>P26: .gitignore で Sources を検査から隠す<br>P61: .swift-format の rules で規則を 1 つ切る（リポジトリ全体の抑制になる・M8-j） | `make check` | P25: exit 2・`CNF-005 swiftlint-baseline.json:1: 名前に baseline を含むファイル`<br>P26: exit 2・`CNF-005 .gitignore:2: 検査の対象から外れる無視の指定 'Sources/NeNeWireCore/Hidden.swift'（生成物の置き場だけを無視する）`<br>P61: exit 2・`CNF-005 .swift-format:1: swift-format の設定 rules は使えない（規則の無効化はリポジトリ全体の抑制になる・M8-j）` |
| QLT-004 | P27: インデントを 2 桁にする<br>P28: Core のディレクトリに入れ子の .swiftlint.yml を置く<br>P61: .swift-format の rules で規則を 1 つ切る（リポジトリ全体の抑制になる・M8-j） | `make check` | P27: exit 2・`Sources/NeNeWireRender/Cell.swift:3:1: error: [Indentation] indent by 2 spaces`<br>P28: exit 2・`CNF-007 Sources/NeNeWireCore/.swiftlint.yml:1: ゲートが読まない場所の検査設定（入れ子の設定は道具が勝手に拾う）`<br>P61: exit 2・`CNF-005 .swift-format:1: swift-format の設定 rules は使えない（規則の無効化はリポジトリ全体の抑制になる・M8-j）` |
| QLT-005 | P35: CI に make check 以外の run（swift build）を足す | `make check` | P35: exit 2・`CNF-018 .github/workflows/ci.yml:30: CI で許す run はツールチェーン導入とゲートの 1 行だけ: swift build` |
| QLT-006 | P02: Terminal が正本に無い Core への依存を宣言する（循環は作らない）<br>P03: Core が Foundation を import する<br>P63: Terminal が宣言していない推移的な依存の Core を import する（SwiftPM は拒まない・M6-e） | `make check` | P02: exit 2・`CNF-010 Package.swift:14: target NeNeWireTerminal の依存が正本と違う（余分: NeNeWireCore / 不足: なし）`<br>P03: exit 2・`CNF-011 Sources/NeNeWireCore/Probe.swift:1: NeNeWireCore は Foundation を import できない`<br>P63: exit 2・`CNF-011 Sources/NeNeWireTerminal/Screen.swift:2: NeNeWireTerminal は NeNeWireCore を import できない` |
| QLT-007 | P29: SourceKit が要る規則（statement_position）を有効にする（静的バイナリが黙って飛ばす）<br>P38: 規約検査の CNF-013 の検出を壊す（検査器の単体テストが落ちること）<br>P65: 規約検査の CNF-013 の選択肢ごとの判定を壊す（検査器の単体テストが落ちること） | `make check` | P29: exit 2・`lint: 有効にした規則が実行されていない（CNF-007）`<br>P38: exit 2・`FAILED (failures=1)`<br>P65: exit 2・`FAILED (failures=8)` |
| QLT-011 | P33: 許可リストに無い外部パッケージを manifest に書く（解決に行かせないため狭い検査で）<br>P34: SwiftLint の lock の SHA-256 を 1 文字変え、道具を入れ直させる | `make conformance`<br>`make tools` | P33: exit 2・`CNF-009 Package.swift:7: 許可リストに無い外部パッケージ`<br>P34: exit 2・`/tmp/tmp.E6kfmrtjHO/swiftlint_linux_amd64.zip: FAILED` |
| QLT-012 | P45: CI のジョブに draft を飛ばす if: を書く（スキップは成功として数えられる）<br>P46: draft の PR に push する（CI のジョブはスキップでなく失敗し、PR はマージできない） | GitHub Actions run 40262253912（PR #2・head 1b235b9・2026-10-26T03:04Z）<br>`make check` | P45: exit 2・`CNF-018 .github/workflows/ci.yml:16: if: は使えない（スキップされた必須 check は成功として数えられる）`<br>P46: step `eng/ci-require-ready.sh true` が `ci: PR が draft なのでフルゲートを回さない。Ready にすると回る（QLT-012）` で exit 1。必須 check `check` は FAILURE・`mergeStateStatus` は `BLOCKED` |
| CNF-001 | P15: 型を BoardHelper と名付ける | `make check` | P15: exit 2・`CNF-001 Sources/NeNeWireCore/BoardHelper.swift:2: 総称名の型 BoardHelper` |
| CNF-002 | P16: 1 ファイルに最上位の型を 2 つ置く | `make check` | P16: exit 2・`CNF-002 Sources/NeNeWireCore/Probe.swift:5: 主要宣言が 2 個ある: Probe, Other` |
| CNF-003 | P19: waiver 無しの swiftlint:disable:next で強制アンラップを抑制する<br>P20: @diagnose で非推奨の警告を消す | `make check` | P19: exit 2・`CNF-003 Sources/nene-wire/main.swift:10: 直前行に有効な // Waiver: WVR-NNNN が無い`<br>P20: exit 2・`CNF-003 Sources/NeNeWireCore/Probe.swift:3: @available(..., deprecated) は非推奨の警告を隠す` |
| CNF-004 | P21: 期限切れの active な waiver を台帳と索引に置く | `make check` | P21: exit 2・`CNF-004 docs/waivers/WVR-0001:1: 期限切れの waiver（2026-10-24）` |
| CNF-005 | P25: 名前に baseline を含むファイルを置く<br>P26: .gitignore で Sources を検査から隠す<br>P61: .swift-format の rules で規則を 1 つ切る（リポジトリ全体の抑制になる・M8-j） | `make check` | P25: exit 2・`CNF-005 swiftlint-baseline.json:1: 名前に baseline を含むファイル`<br>P26: exit 2・`CNF-005 .gitignore:2: 検査の対象から外れる無視の指定 'Sources/NeNeWireCore/Hidden.swift'（生成物の置き場だけを無視する）`<br>P61: exit 2・`CNF-005 .swift-format:1: swift-format の設定 rules は使えない（規則の無効化はリポジトリ全体の抑制になる・M8-j）` |
| CNF-006 | P30: 未定義の規則 ID を文書に書く<br>P31: 証明行の無い規則をマトリクスで active にする（本文も合わせて書き換える）<br>P66: active の規則の証明行の実測を空にする（空の行は証明ではない） | `make check` | P30: exit 2・`CNF-006 docs/todo/current.md:31: 未定義の規則 ID ARC-0 99（仕込んだ未定義の ID。この文書自身が落ちないよう空白を入れて写した）`<br>P31: exit 2・`CNF-006 docs/QUALITY_GATES.md:1: active の QLT-008 に gate-proofs の証明行（｜ QLT-008 ｜）が無い`<br>P66: exit 2・`CNF-006 docs/quality/gate-proofs.md:1: active の CNF-015 の証明行に実測が書かれていない（空の行は証明ではない）` |
| CNF-007 | P28: Core のディレクトリに入れ子の .swiftlint.yml を置く<br>P29: SourceKit が要る規則（statement_position）を有効にする（静的バイナリが黙って飛ばす） | `make check` | P28: exit 2・`CNF-007 Sources/NeNeWireCore/.swiftlint.yml:1: ゲートが読まない場所の検査設定（入れ子の設定は道具が勝手に拾う）`<br>P29: exit 2・`lint: 有効にした規則が実行されていない（CNF-007）` |
| CNF-008 | P32: Issue 番号の無い作業メモ（TODO）を書く | `make check` | P32: exit 2・`CNF-008 Sources/NeNeWireCore/Square.swift:1: TODO / FIXME の直後に (#Issue番号) が無い` |
| CNF-009 | P23: target の警告設定を treatAllWarnings(as: .warning) に緩める（警告の出るコードは置かない。設定そのものを拒むこと）<br>P33: 許可リストに無い外部パッケージを manifest に書く（解決に行かせないため狭い検査で） | `make check`<br>`make conformance` | P23: exit 2・`CNF-009 Package.swift:8: target NeNeWireCore に .treatAllWarnings(as: .error) が無い`<br>P33: exit 2・`CNF-009 Package.swift:7: 許可リストに無い外部パッケージ` |
| CNF-010 | P02: Terminal が正本に無い Core への依存を宣言する（循環は作らない） | `make check` | P02: exit 2・`CNF-010 Package.swift:14: target NeNeWireTerminal の依存が正本と違う（余分: NeNeWireCore / 不足: なし）` |
| CNF-011 | P03: Core が Foundation を import する<br>P22: テストで XCTest を import する<br>P63: Terminal が宣言していない推移的な依存の Core を import する（SwiftPM は拒まない・M6-e）<br>P64: Core が FoundationEssentials を import する（Foundation とは別の名前で Date が読める・M5-j） | `make check` | P03: exit 2・`CNF-011 Sources/NeNeWireCore/Probe.swift:1: NeNeWireCore は Foundation を import できない`<br>P22: exit 2・`CNF-011 Tests/NeNeWireCoreTests/ProbeTests.swift:1: NeNeWireCoreTests は XCTest を import できない`<br>P63: exit 2・`CNF-011 Sources/NeNeWireTerminal/Screen.swift:2: NeNeWireTerminal は NeNeWireCore を import できない`<br>P64: exit 2・`CNF-011 Sources/NeNeWireCore/Probe.swift:1: NeNeWireCore は FoundationEssentials を import できない` |
| CNF-012 | P04: Render が using: の無い Int.random を呼ぶ<br>P05: Core のテストが CommandLine.arguments を読む（テストにも禁止がかかる） | `make check` | P04: exit 2・`CNF-012 Sources/NeNeWireRender/Pick.swift:7: random(...) は using: で乱数源を受け取る`<br>P05: exit 2・`CNF-012 Tests/NeNeWireCoreTests/ProbeTests.swift:3: 時刻・乱数・環境・プロセス状態は合成ルートだけが読む` |
| CNF-013 | P07: switch に default: を書く<br>P08: switch に case let other: を書く（default とも case _ とも書かない全捕捉）<br>P55: switch に case (let other): を書く（括弧で包んだ束縛・M1-j）<br>P56: switch に case .none, _: を書く（並べた選択肢の中の _・M1-k）<br>P57: タプルの switch に case (_, _): を書く（全位置が _ のタプル・M1-m） | `make check` | P07: exit 2・`CNF-013 Sources/NeNeWireCore/Side.swift:15: 全捕捉（default / @unknown default / case _ / case let x / 括弧や並びに隠れた _ と束縛）は網羅性検`<br>P08: exit 2・`CNF-013 Sources/NeNeWireCore/Side.swift:15: 全捕捉（default / @unknown default / case _ / case let x / 括弧や並びに隠れた _ と束縛）は網羅性検`<br>P55: exit 2・`CNF-013 Sources/NeNeWireCore/Side.swift:15: 全捕捉（default / @unknown default / case _ / case let x / 括弧や並びに隠れた _ と束縛）は網羅性検`<br>P56: exit 2・`CNF-013 Sources/NeNeWireCore/Side.swift:15: 全捕捉（default / @unknown default / case _ / case let x / 括弧や並びに隠れた _ と束縛）は網羅性検`<br>P57: exit 2・`CNF-013 Sources/NeNeWireCore/Pair.swift:11: 全捕捉（default / @unknown default / case _ / case let x / 括弧や並びに隠れた _ と束縛）は網羅性検` |
| CNF-014 | P14: Core で unsafeBitCast を使う<br>P60: Terminal で @preconcurrency import を書く（並行性の error を戻らない warning に下げる・M7-i） | `make check`<br>`make conformance` | P14: exit 2・`CNF-014 Sources/NeNeWireCore/Probe.swift:3: unsafe 系の API は unsafe=allowed の target だけ`<br>P60: exit 2・`CNF-014 Sources/NeNeWireTerminal/Screen.swift:1: リフレクション・下線付き属性・@preconcurrency・マクロ・動的呼び出しは使えない` |
| CNF-015 | P39: Decodable を使う | `make check` | P39: exit 2・`CNF-015 Sources/NeNeWireCore/Probe.swift:2: Codable / Decodable / Encodable は使えない` |
| CNF-016 | P09: 公開の格納 var を置く | `make check` | P09: exit 2・`CNF-016 Sources/NeNeWireRender/Cell.swift:3: public の格納 var は外から変更できる（let か private(set) にする）` |
| CNF-017 | P40: Core で print を呼ぶ | `make check` | P40: exit 2・`CNF-017 Sources/NeNeWireCore/Probe.swift:5: print / readLine / exit 等は合成ルートだけ` |
| CNF-018 | P35: CI に make check 以外の run（swift build）を足す<br>P36: CI のアクションをタグで指す<br>P45: CI のジョブに draft を飛ばす if: を書く（スキップは成功として数えられる） | `make check` | P35: exit 2・`CNF-018 .github/workflows/ci.yml:30: CI で許す run はツールチェーン導入とゲートの 1 行だけ: swift build`<br>P36: exit 2・`CNF-018 .github/workflows/ci.yml:19: アクションを commit SHA で固定していない: actions/checkout@v7`<br>P45: exit 2・`CNF-018 .github/workflows/ci.yml:16: if: は使えない（スキップされた必須 check は成功として数えられる）` |
| CNF-019 | P11: 製品コードに throws を書く | `make check` | P11: exit 2・`CNF-019 Sources/NeNeWireCore/Probe.swift:4: 期待される失敗は閉じた結果型で返す（throw / try / catch は使えない）` |
| CNF-020 | P12: Any を使う | `make check` | P12: exit 2・`CNF-020 Sources/NeNeWireCore/Probe.swift:4: Any / AnyObject / AnyHashable / AnyClass は使えない` |
| CNF-021 | P58: 別ファイルの extension に init を足し、private init を経ずに Square を作る（M4-f） | `make check` | P58: exit 2・`CNF-021 Sources/NeNeWireCore/Square+Bypass.swift:3: extension に init を書かない（型の本体の唯一のファクトリを迂回できる）` |
| CNF-022 | P59: Core に async の関数を書く | `make check` | P59: exit 2・`CNF-022 Sources/NeNeWireCore/Probe.swift:4: async / await / Task / actor / Thread / Dispatch は使えない（並行の形は合成ルートの 1 本のループだけ` |
| CNF-023 | P62: Core で posix_spawn を呼んで子プロセスを起動する（外部プロセスは Host だけ） | `make conformance` | P62: exit 2・`CNF-023 Sources/NeNeWireCore/Probe.swift:5: 外部プロセスの起動（posix_spawn / fork / exec / system / popen）は spawn=allowed の targe` |
| GIT-003 | P41: 形の合わないコミット（--no-verify でフックを迂回）<br>P42: 形の合わないコミットをフック付きで作ろうとする（フックが拒む） | `git -c user.name=proof -c user.email=proof@example.invalid commit --allow-empty -m update stuff`<br>`make check` | P41: exit 2・`GIT-003 6bd77e8: 件名は `<type>(<scope>): <日本語の説明> (#<issue番号>)` の形（type は feat / fix / docs / refactor / test / build / ci`<br>P42: exit 1・`GIT-003 件名は `<type>(<scope>): <日本語の説明> (#<issue番号>)` の形（type は feat / fix / docs / refactor / test / build / ci / chore）` |
| GIT-004 | P43: ruleset が `main` に効いていることを読み戻し、必須 check の失敗した PR がマージできないことを見る（`main` への直接 push と force push は試していない） | `gh api repos/hideyukiMORI/nene-wire/rules/branches/main`・`gh pr view 2`（2026-10-26） | P43: `main` に効く規則は ruleset 25851529 の `deletion`・`non_fast_forward`・`pull_request`（squash のみ）・`required_status_checks`（`check`）の 4 つ。PR #2 の head 1b235b9 は必須 check `check` が FAILURE で `mergeStateStatus` が `BLOCKED` |
<!-- proofs:active:end -->

**復帰の確認**: 対照 P00（足場だけ・違反なし）と P00b（足場を置かない作業木そのまま）が、どちらも `make check` で exit 0（`make check: 緑`）。
各証明は対照と同じ足場に違反を 1 つ足しただけなので、「仕込みを戻すと緑」は P00 が示す。

**除外側の確認**: P00 の足場では、合成ルート `nene-reversi` が `ContinuousClock.now`・`SystemRandomNumberGenerator`・`CommandLine.arguments`・`print` を使い、
`NeNeReversiTerminal`（`unsafe=allowed`）が `withUnsafeMutablePointer` と `ioctl` を使っている。それでも `make check` は緑で、
同じ書き方を Core・Engine・テストに置くと P04・P05・P14・P40 で落ちる。

### 1-b. 証明の一覧

<!-- proofs:list:start -->
| # | 規則 | 仕込んだ違反 | 実行したタスク | 結果 | 判定 |
| --- | --- | --- | --- | --- | --- |
| P00 | 対照 | 対照: 足場だけ（違反なし）。合成ルートが時計・乱数・CommandLine・getenv・print を使い、Host が posix_spawn、Terminal が withUnsafe を使う | `make check` | exit 0 | pass |
| P00b | 対照 | 対照: 足場を置かない作業木そのまま | `make check` | exit 0 | pass |
| P01 | ARC-002 | Core が宣言していない Render を import する | `make check` | exit 2 | pass |
| P02 | ARC-002, CNF-010, QLT-006 | Terminal が正本に無い Core への依存を宣言する（循環は作らない） | `make check` | exit 2 | pass |
| P03 | ARC-003, CNF-011, SWF-014, QLT-006 | Core が Foundation を import する | `make check` | exit 2 | pass |
| P04 | ARC-007, CNF-012 | Render が using: の無い Int.random を呼ぶ | `make check` | exit 2 | pass |
| P05 | ARC-007, CNF-012 | Core のテストが CommandLine.arguments を読む（テストにも禁止がかかる） | `make check` | exit 2 | pass |
| P06 | SWF-002 | enum に case を足し、switch を直さない | `make check` | exit 2 | pass |
| P07 | SWF-002, CNF-013 | switch に default: を書く | `make check` | exit 2 | pass |
| P08 | CNF-013 | switch に case let other: を書く（default とも case _ とも書かない全捕捉） | `make check` | exit 2 | pass |
| P09 | SWF-003, CNF-016 | 公開の格納 var を置く | `make check` | exit 2 | pass |
| P10 | SWF-004 | 強制アンラップを書く | `make check` | exit 2 | pass |
| P11 | SWF-005, CNF-019 | 製品コードに throws を書く | `make check` | exit 2 | pass |
| P12 | SWF-006, CNF-020 | Any を使う | `make check` | exit 2 | pass |
| P13 | SWF-006 | 要素 3 つのタプルを返す | `make check` | exit 2 | pass |
| P14 | SWF-009, CNF-014 | Core で unsafeBitCast を使う | `make check` | exit 2 | pass |
| P15 | SWF-010, CNF-001 | 型を BoardHelper と名付ける | `make check` | exit 2 | pass |
| P16 | SWF-011, CNF-002 | 1 ファイルに最上位の型を 2 つ置く | `make check` | exit 2 | pass |
| P17 | SWF-012 | 引数 5 つの関数を書く | `make check` | exit 2 | pass |
| P18 | SWF-012 | 循環的複雑度 11 の関数を書く（SwiftLint は if 11 個を 11 と数える） | `make check` | exit 2 | pass |
| P19 | SWF-015, CNF-003 | waiver 無しの swiftlint:disable:next で強制アンラップを抑制する | `make check` | exit 2 | pass |
| P20 | SWF-015, CNF-003 | @diagnose で非推奨の警告を消す | `make check` | exit 2 | pass |
| P21 | SWF-015, CNF-004 | 期限切れの active な waiver を台帳と索引に置く | `make check` | exit 2 | pass |
| P22 | SWF-016, CNF-011 | テストで XCTest を import する | `make check` | exit 2 | pass |
| P23 | QLT-002, CNF-009 | target の警告設定を treatAllWarnings(as: .warning) に緩める（警告の出るコードは置かない。設定そのものを拒むこと） | `make check` | exit 2 | pass |
| P24 | QLT-002 | 未使用のローカル定数を置く（警告がエラーになること） | `make check` | exit 2 | pass |
| P25 | QLT-003, CNF-005 | 名前に baseline を含むファイルを置く | `make check` | exit 2 | pass |
| P26 | QLT-003, CNF-005 | .gitignore で Sources を検査から隠す | `make check` | exit 2 | pass |
| P27 | QLT-004 | インデントを 2 桁にする | `make check` | exit 2 | pass |
| P28 | QLT-004, CNF-007 | Core のディレクトリに入れ子の .swiftlint.yml を置く | `make check` | exit 2 | pass |
| P29 | CNF-007, QLT-007 | SourceKit が要る規則（statement_position）を有効にする（静的バイナリが黙って飛ばす） | `make check` | exit 2 | pass |
| P30 | CNF-006 | 未定義の規則 ID を文書に書く | `make check` | exit 2 | pass |
| P31 | CNF-006 | 証明行の無い規則をマトリクスで active にする（本文も合わせて書き換える） | `make check` | exit 2 | pass |
| P66 | CNF-006 | active の規則の証明行の実測を空にする（空の行は証明ではない） | `make check` | exit 2 | pass |
| P32 | CNF-008 | Issue 番号の無い作業メモ（TODO）を書く | `make check` | exit 2 | pass |
| P33 | QLT-011, CNF-009 | 許可リストに無い外部パッケージを manifest に書く（解決に行かせないため狭い検査で） | `make conformance` | exit 2 | pass |
| P34 | QLT-011 | SwiftLint の lock の SHA-256 を 1 文字変え、道具を入れ直させる | `make tools` | exit 2 | pass |
| P35 | QLT-001, CNF-018, QLT-005 | CI に make check 以外の run（swift build）を足す | `make check` | exit 2 | pass |
| P36 | CNF-018 | CI のアクションをタグで指す | `make check` | exit 2 | pass |
| P45 | QLT-012, CNF-018 | CI のジョブに draft を飛ばす if: を書く（スキップは成功として数えられる） | `make check` | exit 2 | pass |
| P37 | QLT-001 | .swift-version を実際の版と違う 6.4.0 にする | `make check` | exit 2 | pass |
| P38 | QLT-007 | 規約検査の CNF-013 の検出を壊す（検査器の単体テストが落ちること） | `make check` | exit 2 | pass |
| P39 | CNF-015 | Decodable を使う | `make check` | exit 2 | pass |
| P40 | CNF-017, ARC-006 | Core で print を呼ぶ | `make check` | exit 2 | pass |
| P41 | GIT-003 | 形の合わないコミット（--no-verify でフックを迂回） | `make check` | exit 2 | pass |
| P44 | SWF-002, SWF-004, SWF-005, SWF-006, SWF-012, SWF-015 | 有効にした SwiftLint の 16 規則それぞれの違反を 1 ファイルに置く（設定の全規則が実際に発火すること） | `make check` | exit 2 | pass |
| P47 | QLT-002 | ソースの無いテスト target を manifest に足す（SwiftPM 自身が警告を出し、コンパイラの警告エラーの外にある） | `make check` | exit 2 | pass |
| P48 | QLT-001 | テストの期待値を 1 つ変える（make check の中で swift test が実際に回って落ちること） | `make check` | exit 2 | pass |
| P50 | SWF-002 | 文字列の switch の全捕捉を case _ where true: と書く（CNF-013 の字句の外の書き方。コンパイラが網羅に数えないこと） | `make check` | exit 2 | pass |
| P55 | SWF-002, CNF-013 | switch に case (let other): を書く（括弧で包んだ束縛・M1-j） | `make check` | exit 2 | pass |
| P56 | SWF-002, CNF-013 | switch に case .none, _: を書く（並べた選択肢の中の _・M1-k） | `make check` | exit 2 | pass |
| P57 | SWF-002, CNF-013 | タプルの switch に case (_, _): を書く（全位置が _ のタプル・M1-m） | `make check` | exit 2 | pass |
| P58 | SWF-007, CNF-021 | 別ファイルの extension に init を足し、private init を経ずに Square を作る（M4-f） | `make check` | exit 2 | pass |
| P59 | SWF-013, CNF-022 | Core に async の関数を書く | `make check` | exit 2 | pass |
| P60 | SWF-009, SWF-015, CNF-014 | Terminal で @preconcurrency import を書く（並行性の error を戻らない warning に下げる・M7-i） | `make conformance` | exit 2 | pass |
| P61 | QLT-003, QLT-004, CNF-005 | .swift-format の rules で規則を 1 つ切る（リポジトリ全体の抑制になる・M8-j） | `make check` | exit 2 | pass |
| P62 | CNF-023, ARC-002 | Core で posix_spawn を呼んで子プロセスを起動する（外部プロセスは Host だけ） | `make conformance` | exit 2 | pass |
| P63 | ARC-002, CNF-011, QLT-006 | Terminal が宣言していない推移的な依存の Core を import する（SwiftPM は拒まない・M6-e） | `make check` | exit 2 | pass |
| P64 | ARC-003, ARC-007, CNF-011, SWF-014 | Core が FoundationEssentials を import する（Foundation とは別の名前で Date が読める・M5-j） | `make check` | exit 2 | pass |
| P65 | QLT-007 | 規約検査の CNF-013 の選択肢ごとの判定を壊す（検査器の単体テストが落ちること） | `make check` | exit 2 | pass |
| P42 | GIT-003 | 形の合わないコミットをフック付きで作ろうとする（フックが拒む） | `git -c user.name=proof -c user.email=proof@example.invalid commit --allow-empty -m update stuff` | exit 1 | pass |
| P43 | GIT-004 | ruleset が `main` に効いていることを読み戻し、必須 check の失敗した PR がマージできないことを見る（`main` への直接 push と force push は試していない） | `gh api repos/hideyukiMORI/nene-wire/rules/branches/main`・`gh pr view 2`（2026-10-26） | 第 1-a 節 | pass |
| P46 | QLT-012 | draft の PR に push する（CI のジョブはスキップでなく失敗し、PR はマージできない） | GitHub Actions run 40262253912（PR #2・head 1b235b9・2026-10-26T03:04Z） | 第 1-a 節 | pass |
<!-- proofs:list:end -->

---

## 2. 出力の抜粋（実行結果からの引用）

各証明の出力から、期待した行（`evidence`）と末尾の数行（`tail`）を [gate-proofs.json](gate-proofs.json) に残している。代表例（P62 がこのリポジトリで置き換えた CNF-023）:

```text
P62  CNF-023 Sources/NeNeWireCore/Probe.swift:5: 外部プロセスの起動（posix_spawn / fork / exec / system / popen）は spawn=allowed の target だけ
P55  CNF-013 Sources/NeNeWireCore/Side.swift:15: 全捕捉（default / @unknown default / case _ / case let x / 括弧や並びに隠れた _ と束縛）は網羅性検査を殺す
P56  CNF-013 Sources/NeNeWireCore/Side.swift:15: 全捕捉（default / @unknown default / case _ / case let x / 括弧や並びに隠れた _ と束縛）は網羅性検査を殺す
P57  CNF-013 Sources/NeNeWireCore/Pair.swift:11: 全捕捉（default / @unknown default / case _ / case let x / 括弧や並びに隠れた _ と束縛）は網羅性検査を殺す
P58  CNF-021 Sources/NeNeWireCore/Square+Bypass.swift:3: extension に init を書かない（型の本体の唯一のファクトリを迂回できる）
P59  CNF-022 Sources/NeNeWireCore/Probe.swift:4: async / await / Task / actor / Thread / Dispatch は使えない（並行の形は合成ルートの 1 本のループだけ）
P61  CNF-005 .swift-format:1: swift-format の設定 rules は使えない（規則の無効化はリポジトリ全体の抑制になる・M8-j）
P63  CNF-011 Sources/NeNeWireTerminal/Screen.swift:2: NeNeWireTerminal は NeNeWireCore を import できない
P64  CNF-011 Sources/NeNeWireCore/Probe.swift:1: NeNeWireCore は FoundationEssentials を import できない
P66  CNF-006 docs/quality/gate-proofs.md:1: active の CNF-015 の証明行に実測が書かれていない（空の行は証明ではない）
P47  swift-strict: SwiftPM かコンパイラが警告を出した（QLT-002）
P37  tools: swift は 6.4.0 が要るが、起動できない: The swift version file `.swift-version` requires toolchain version 6.4.0, which is not installed. You can install it
```

---

## 3. 事故から生まれた検査・証明の取り直し

Issue #1 の Phase 0〜2 で、測る手順が次を見つけた。

| 見つけたこと | 対処 |
| --- | --- |
| 足場の合成ルートに `getenv` を足したとき `import Glibc` を書き忘れ、対照 P00 がビルドで落ちて 52 件が FAIL になった（証明の仕込みではなく足場の誤り） | 足場を直し、P00 が緑になるのを見てから全件を測り直した |
| 足場の Host（`posix_spawn` で子プロセスを起動する最小の型）が、整形の検査（`forEach` → for 文）と Optional の外し忘れで 2 回落ちた | 足場を直した。どちらも「足場が規則に沿っていない」ことをゲートが正しく捕まえた |
| Reversi の CNF-023（登録商標のゲーム名）は NeNe Wire では何も守らない | 「外部プロセスの起動は `spawn=allowed` の target だけ」に置き換え、P62（Core で `posix_spawn`）で証明した |
| draft の PR #2 の CI は、ジョブをスキップせず `eng/ci-require-ready.sh` で失敗し、PR は `BLOCKED` になった（run 40262253912） | 兄弟が見つけた「スキップは成功と数えられる」穴が最初から塞がっていることを、このリポジトリの run で確かめた（P46） |

---

## 4. リポジトリ設定（ruleset）

| 設定 | 値 | 確認日 |
| --- | --- | --- |
| ruleset | `main`（id 25851529）・enforcement `active`・対象 `~DEFAULT_BRANCH`・bypass なし（`current_user_can_bypass: never`） | 2026-10-26 |
| PR 必須 | `pull_request`（承認 0 件・未解決スレッドで止める） | 2026-10-26 |
| 必須 check | `required_status_checks`: context `check`・integration 15368（GitHub Actions） | 2026-10-26 |
| strict up-to-date | `strict_required_status_checks_policy: true` | 2026-10-26 |
| force push / ブランチ削除の禁止 | `non_fast_forward`・`deletion` | 2026-10-26 |
| squash のみ | ruleset の `allowed_merge_methods: ["squash"]`＋リポジトリ設定（merge commit・rebase は無効・マージ後に枝を自動削除） | 2026-10-26 |

読み戻しは `gh api repos/hideyukiMORI/nene-wire/rulesets/25851529` と `gh api repos/hideyukiMORI/nene-wire/rules/branches/main`（`main` に効く規則が上の 4 つだけであること）。
直接 push・force push・削除が拒まれることは試していない（兄弟の NeNe Reversi でも作業環境の権限で止められた試行で、ここでも行わない）。

🔴 **設定していないものを「必須になっている」と書かない。** 設定したら `gh api` で読み戻して記録する。

---

## 5. 環境依存の確認（QLT-013）

（まだ無い。端末の表示の確認は Phase 3 の手順 3 で Windows Terminal を使って記録する）

# ADR 0001 — 厳格さは機械で強制する

- 状態: 受理
- 日付: 2026-10-26
- Issue: #1
- 影響する規則: すべて

## 文脈

本リポジトリの規約は、AYANE 厳格規約ポリシーと、先行する 5 リポジトリ（NENE-PIXEL＝Kotlin / nene-recall＝Go /
xi-tools＝Rust / NeNeCommander＝C# / NeNeClock＝Java）で確立された考え方を Swift 6 へ持ち込んだものである。
Swift への適用は NeNe Delve（2026-10-23）・NeNe Sand（2026-10-24）・NeNe Gambit（2026-10-25）・NeNe Reversi（2026-10-25〜26）に続いて 5 回目になる。
共通する中核は 1 つに要約できる。

> **一つの意味には一つの正典経路しか無い状態を作り、それを人の記憶ではなく機械に守らせる。**

規約は、破ったときに何も起きなければ、時間とともに必ず腐る。

### Swift 6.4.1 で実測したこと

先行の値を写さず、ポリシー第 3 節の M-1〜M-8 を 2026-10-26 にこのリポジトリで自分でコンパイルして確かめた。
実測は `eng/measure-language.py`（NeNe Reversi の同名のスクリプトをコミット b3dac02 から移植・元は NeNe Gambit・ADR 0003）が一時ディレクトリに
swiftc の呼び出しと SwiftPM パッケージを作って行い、終了コードと診断行を [docs/quality/phase0-results.json](../quality/phase0-results.json) に
そのまま書く。**75 ケース**: Gambit と同じ 56 ケース（同じ ID・同じソース）に、NeNe Reversi が足した 19 ケース
（M1-i〜M1-m・M4-f・M4-g・M5-i・M5-j・M6-e・M6-f・M7-i〜M7-l・M8-j・X-d〜X-f）。判定はこの ADR で人が書く。
再実行は `python3 eng/measure-language.py --swiftlint .tools/swiftlint`（`make tools` の後）。

環境: Swift 6.4.1（swift-6.4.1-RELEASE・x86_64-unknown-linux-gnu）/ swift-format 6.4.1（ツールチェーン同梱）/
SwiftLint 0.65.1（`swiftlint-static`）/ WSL2 Ubuntu・glibc 2.35。swiftc の直接呼び出しは `-swift-version 6 -warnings-as-errors`、
SwiftPM は `// swift-tools-version: 6.2` の manifest に `swiftSettings: [.treatAllWarnings(as: .error)]` を置いた。
🆕 の付いた行が、NeNe Reversi で足したケースである（このリポジトリでは足していない）。

#### M-1 網羅性

```text
M1-a  ケース漏れ                                   exit 1  error: switch must be exhaustive
M1-b  default:                                     exit 0  診断なし
M1-c  case _:                                      exit 0  診断なし
M1-d  case let other:（束縛する全捕捉）             exit 0  診断なし
M1-e  @unknown default で既知ケース漏れ             exit 0  warning: switch must be exhaustive（-warnings-as-errors でも warning のまま）
M1-h  同上を SwiftPM の treatAllWarnings(as: .error) で  exit 0  warning のまま
M1-g  タプルの位置の _                             exit 0  診断なし
M1-i  🆕 == と else で閉じた enum を分岐            exit 0  診断なし（ケースを足しても何も言われない）
M1-j  🆕 case (let other):（括弧で包んだ束縛）       exit 0  診断なし
M1-k  🆕 case .a, _:（並べた選択肢の中の _）         exit 0  診断なし
M1-l  🆕 case let other as Shape:（同じ型の as）     exit 1  error: 'as' test is always true
M1-m  🆕 case (_, _):（タプルの全位置が _）           exit 0  診断なし
```

🔑 全捕捉は `default:`・`case _:`・`case let x:` の 3 つの形に限らない。**括弧で包んだ束縛（M1-j）・並べた選択肢の 1 つとしての `_`（M1-k）・
全位置が `_` か束縛のタプル（M1-m）**も、診断なしで網羅性検査を殺す。Gambit の字句検査（CNF-013）の正規表現は行頭の
`case _:` と `case let x:` / `case let (x):` だけを見ており、この 3 つの形を通す（Python で正規表現に当てて確かめた）。
タプルの**一部の**位置の `_`（`case (.a, _):`）は「その位置を見ない」という意味で全捕捉ではないので、拒否しない。
`==` と `else` の分岐（M1-i）は網羅性を持たないが、`else` そのものを字句で拒否すると正当な条件分岐まで拒むので、塞げない。

#### M-2 公開状態の不変

```text
M2-a  他モジュールから public let へ代入          exit 1  error: cannot assign to property: 'size' is a 'let' constant
M2-b  他モジュールから public private(set) var へ  exit 1  error: cannot assign to property: 'moves' setter is inaccessible
M2-c  他モジュールから public var へ代入          exit 0
M2-d  返した配列に append                         exit 0  実行結果 owner=1 copy=2（配列は値の意味で複製される）
M2-e  let で持ったクラス参照の var を変更          exit 0
```

#### M-3 null・ゼロ値・未初期化

```text
M3-a  未初期化の let を返す（-typecheck）  exit 0  診断なし
M3-b  同じソースを本コンパイル（-c）        exit 1  error: constant 'x' used before being initialized
M3-c  暗黙アンラップ Optional（Int!）       exit 0
M3-d  強制アンラップ v!                    exit 0
M3-e  空 struct の Marker()・既定値つき struct の Score()  exit 0
M3-f  宣言だけの var を読む                exit 1  error: variable 'x' passed by reference before being initialized
```

暗黙のゼロ値は無い（M3-f）。`nil` を持てるのは Optional だけだが、IUO と強制アンラップはコンパイラが通す。

#### M-4 非公開コンストラクタ

```text
M4-a  private init を同一モジュールの別ファイルから       exit 1  error: 'Square' initializer is inaccessible due to 'private' protection level
M4-b  明示 init の無い public struct を他モジュールから    exit 1  error: ... due to 'internal' protection level
M4-c  明示 init の無い struct を同一モジュールの別ファイルから  exit 0（memberwise init）
M4-d  unsafeBitCast(99, to: Square.self)                  exit 0
M4-e  Decodable の合成 init(from:)                        exit 0（private init を経ずに値ができる）
M4-f  🆕 同一モジュールの別ファイルの extension に init を足し、格納プロパティへ直接代入  exit 0
M4-g  🆕 同じことを他モジュールの extension で              exit 1  error: 'let' property 'index' may not be initialized directly; use "self.init(...)" or "self = ..." instead
```

🔑 **`private init` は、同じモジュールのどのファイルからでも `extension` の `init` で迂回できる**（M4-f）。`unsafe` も `Decodable` も要らない。
他モジュールからは拒まれる（M4-g）ので、穴は target の内側にある。

#### M-5 中核の決定性（依存を宣言しない SwiftPM target）

```text
M5-a  import Foundation; Date()              exit 0
M5-b  import Glibc; time(nil)                exit 0
M5-c  Int.random(in:)（import なし）          exit 0
M5-d  SystemRandomNumberGenerator（import なし）  exit 0
M5-e  ContinuousClock.now（import なし）      exit 0
M5-f  CommandLine.arguments（import なし）    exit 0
M5-g  import Dispatch; DispatchTime.now()    exit 0
M5-h  M5-a に --explicit-target-dependency-import-check error  exit 0（標準モジュールは対象外）
M5-i  🆕 Task.sleep(for:)（import なし）       exit 0（時計を暗に読む待ちが書ける）
M5-j  🆕 import FoundationEssentials; Date()  exit 0（Foundation とは別の名前のモジュールからも時計が読める）
```

no_std に当たる仕組みは見つからなかった。時計・乱数・プロセス状態は**標準ライブラリだけで**読める。
`Foundation` の名前だけを禁じても `FoundationEssentials` から同じ `Date` が読める（M5-j）ので、禁止は「許可した名前以外の import を拒む」
許可リストの形でなければ塞がらない。

#### M-6 依存方向

```text
M6-a  宣言していない兄弟 target を import（両方が同じ実行物の依存）  exit 1  error: no such module 'Engine'
M6-b  M6-a に --explicit-target-dependency-import-check error         exit 1  同上
M6-c  宣言していない target を import し、その target だけ build        exit 1  同上
M6-d  target の循環を宣言                                             exit 1  error: '<probe>': cyclic dependency declaration found: Core -> Engine -> Core
M6-e  🆕 依存の依存（Render -> Engine -> Core の Render から Core）を宣言なしで import  exit 0
M6-f  🆕 M6-e に --explicit-target-dependency-import-check error         exit 0
```

🔑 SwiftPM は**推移的な依存の import を拒まない**（M6-e）。`--explicit-target-dependency-import-check error` を付けても通った（M6-f）。
つまり「Render は Core を直接使わない」のような制約は、ビルドグラフの宣言だけでは守れない。target ごとの import 許可リスト
（宣言した直接の依存だけ）を規約検査が字句で見て初めて塞がる。Gambit の CNF-011 は既にこの形（許可＝宣言した依存＋標準モジュール）だったが、
その理由（推移的な import がビルドで通ること）は測られていなかった。

#### M-7 抑制

```text
M7-a  @diagnose(DeprecatedDeclaration, as: ignored)        exit 0  -warnings-as-errors 下の警告が消える
M7-b  対照: 同じ呼び出しを抑制なしで                       exit 1  error: 'old()' is deprecated [#DeprecatedDeclaration]
M7-c  呼び出し側に @available(*, deprecated)               exit 0  非推奨の警告が消える
M7-d  manifest の .treatWarning("DeprecatedDeclaration", as: .warning)  exit 0  warning に戻る
M7-e  // swiftlint:disable:next force_unwrapping（理由なし）  exit 0
M7-f  対照: 抑制なし                                       exit 2  error: Force Unwrapping Violation ... (force_unwrapping)
M7-g  // swift-format-ignore（理由なし）                    exit 0
M7-h  対照: swift-format lint --strict                      exit 1  error: [AlwaysUseLowerCamelCase] ...
M7-i  🆕 @preconcurrency import Lib（非 Sendable 型の大域変数）  exit 0  warning: let 'shared' is not concurrency-safe ...（-warnings-as-errors でも warning のまま）
M7-j  🆕 対照: @preconcurrency なし                          exit 1  error: let 'shared' is not concurrency-safe ...
M7-k  🆕 nonisolated(unsafe) var counter                     exit 0  並行性の検査が外れる
M7-l  🆕 対照: nonisolated(unsafe) なし                       exit 1  error: var 'counter' is not concurrency-safe ...
```

🔴 Swift 6.4.1 には**ソースの属性で警告を消す経路**（`@diagnose(<group>, as: ignored)`）がある。理由も規則 ID も要らない。
🔴 **`@preconcurrency import` は Swift 6 の並行性の error を warning に下げ、その warning は `-warnings-as-errors` でもエラーに戻らない**（M7-i）。
`@unknown default`（M1-e）と同じく、警告のエラー化をすり抜ける 2 つ目の warning である。

#### M-8 baseline・全面抑制

```text
M8-a  treatAllWarnings(as: .error) と unsafeFlags(["-suppress-warnings"])  exit 1  error: conflicting options '-warnings-as-errors' and '-suppress-warnings'
M8-g  unsafeFlags(["-suppress-warnings"]) だけ                exit 0  target 全体の警告が消える
M8-b  treatAllWarnings(as: .warning)                          exit 0  target 全体が warning に戻る
M8-c  対照: treatAllWarnings(as: .error)                      exit 1  error: 'old()' is deprecated
M8-h  swift build -Xswiftc -warnings-as-errors ＋ manifest の treatAllWarnings(as: .warning)  exit 0  manifest が勝つ
M8-i  swift build -Xswiftc -warnings-as-errors ＋ manifest の treatWarning(_:as: .warning)   exit 0  manifest が勝つ
M8-d  swiftlint --write-baseline → --baseline                 exit 0  既存違反が消える
M8-e  // swiftlint:disable all（ファイル先頭）                exit 0
M8-f  // swift-format-ignore-file                             exit 0
M8-j  🆕 .swift-format の "rules": {"AlwaysUseLowerCamelCase": false}  exit 0  リポジトリ全体でその規則が消える（対照は M7-h）
```

🔴 **ゲートのコマンド行で `-warnings-as-errors` を渡しても、`Package.swift` の設定がそれを上書きする**（M8-h・M8-i）。
🔴 **`.swift-format` の `rules` は、ファイルに 1 行も書かずにリポジトリ全体の規則を切る**（M8-j）。設定ファイルそのものが baseline になる。
Gambit の CNF-005 は `.swiftlint.yml` の除外系の鍵を拒むが、`.swift-format` の中身は見ていなかった。

#### 補足（Phase 1〜3 の判断材料）

```text
X-a  裸の protocol 型（any 無し）                       exit 0
X-b  .enableUpcomingFeature("ExistentialAny") を有効に  exit 1  error: use of protocol 'P' as a type must be written 'any P'
X-c  テスト target が無いパッケージで swift test        exit 1  error: no tests found; create a target in the 'Tests' directory
X-d  🆕 UInt64 を変数の量 64 でシフト                  exit 0  実行結果 shifted=0 masked=1（<< は落ちずに 0、&<< は 64 で割った余りでシフト）
X-e  🆕 swift test -c release で @testable import       exit 0
X-f  🆕 対照: X-e の期待をわざと外す                   exit 1  ✘ Test hiddenIsOne() recorded an issue ... Expectation failed: hidden() == 2
                                                              （release 構成でもテストは走り、internal の関数を呼べている）
```

X-e と X-f は、手で `swift build -c release --build-tests -v` も回して確かめた。SwiftPM は release 構成のテストのビルドに `-enable-testing` を付ける。

| 先行事例の規則 | Swift 6.4.1（本リポジトリの実測） |
| --- | --- |
| 不正状態を表現不能に・網羅性 | **不十分**。ケース漏れは error（M1-a）。`default:` / `case _:` / `case let x:`・括弧の束縛・並べた `_`・全位置 `_` のタプルは診断なし。既知ケースを漏らす `@unknown default` は警告エラーでも warning で exit 0。字句検査で拒否する。`==` と `else` の分岐は塞げない |
| 公開状態は不変 | **不十分**。`let` と `private(set)` は他モジュールからの代入を拒む。`public var` とクラス参照の中身は通る。配列は値の意味で複製される |
| `null` の意味は一つ（ゼロ値・未初期化の穴） | **不十分**。暗黙のゼロ値は無い。未初期化の `let` は本コンパイルで error（`-typecheck` では出ない）。IUO と強制アンラップは通る → SwiftLint で補う |
| 非公開コンストラクタ＋唯一のファクトリ（迂回経路） | **不十分**。`private init` は他ファイルからの呼び出しを拒む。同一モジュールの memberwise・**同一モジュールの extension の init**・`unsafeBitCast`・`Decodable` の合成 init が迂回する |
| 中核の決定性を構文的に塞げるか | **無い**（言語では）。Foundation / FoundationEssentials / Glibc / Dispatch は宣言なしで import でき、時計・乱数・`CommandLine`・`Task.sleep` は標準ライブラリだけで読める。字句検査（import の許可リストと API 名）で補う |
| 依存方向をビルドが拒むか（標準同梱の枠組みの漏れ） | **不十分**（target 間の直接の依存はある）。宣言の無い import は `no such module`、循環は `cyclic dependency`。**推移的な依存の import は通る**。標準モジュールも漏れる。import の許可リストで補う |
| 抑制を言語で封じられるか | **不十分**。`@diagnose(..., as: ignored)`・`@preconcurrency import`・`nonisolated(unsafe)`・呼び出し側の `@available(*, deprecated)`・manifest の `treatWarning`・`swiftlint:disable`・`swift-format-ignore` がどれも理由なしで効く。waiver 台帳と字句検査で補う |
| baseline を作る経路が塞がっているか | **塞がっていない**。manifest の `treatAllWarnings(as: .warning)` / `unsafeFlags(["-suppress-warnings"])` が target 全体を緩め、コマンド行の指定に勝つ。SwiftLint に `--baseline`、`.swift-format` に `rules` がある。規約検査が manifest と設定ファイルを読んで拒む |

### 先行の Swift 列との突き合わせ

#### NeNe Reversi（4 回目・2026-10-26・75 ケース）

Reversi の [phase0-results.json](https://github.com/hideyukiMORI/nene-reversi/blob/b3dac02/docs/quality/phase0-results.json) と機械的に比べた。
**75 ケースすべてで、終了コード・判定・診断行・ソースが一致した**（違いは一時ディレクトリの名前が入ったコマンド行の 7 件だけ）。
したがって、以下の表と判定（Reversi が Gambit との突き合わせで見つけた 7 つの穴を含む）は、このリポジトリの実測としてもそのまま成り立つ。
新しい穴は見つからなかった。Swift 6.4.1 の言語の性質は、同じツールチェーンで 2 回測って同じだった。

#### NeNe Gambit（3 回目・2026-10-25・56 ケース）— Reversi の突き合わせ（このリポジトリの実測でも同じ）

Gambit の [phase0-results.json](https://github.com/hideyukiMORI/nene-gambit/blob/64b82ec/docs/quality/phase0-results.json) と、
こちらの結果を同じ ID どうしで機械的に比べた（終了コード・診断行の本文・ソース）。

**56 ケースすべてで、ソース・終了コード・診断行が一致した。** 判定（ある／無い／不十分）も 8 項目とも一致した。
同じ版の道具を同じ環境で回したので、一致は予想どおりだが、「同じ入力から同じ出力が出る」ことはこれで確かめた。

食い違いと追加は、Gambit が測っていなかった場所にある。

| # | 判定 | 事実の突き合わせ |
| --- | --- | --- |
| M-1 | 一致（不十分） | 🔴 **Gambit の規約検査の穴**: 括弧の束縛（M1-j）・並べた `_`（M1-k）・全位置 `_` のタプル（M1-m）は診断なしで網羅性を殺すが、Gambit の CNF-013 の正規表現はどれも拾わない。本リポジトリは CNF-013 を「`case` の選択肢を最上位の `,` で分け、必ず一致するパターンが 1 つでもあれば拒否する」形に変えた |
| M-2 | 一致（不十分） | 追加なし |
| M-3 | 一致（不十分） | 追加なし |
| M-4 | 一致（不十分） | **追加**: 同一モジュールの extension の init が `private init` を迂回する（M4-f）。Gambit の SWF-007 は memberwise・`unsafeBitCast`・`Decodable` だけを挙げていた。本リポジトリは extension に init を書くことを CNF-021 で拒否する |
| M-5 | 一致（言語では塞げない） | **追加**: `Task.sleep` が import なしで書ける（M5-i）・`FoundationEssentials` から `Date` が読める（M5-j）。前者は CNF-022（並行の語の禁止）が、後者は CNF-011 の import 許可リストが塞ぐ |
| M-6 | Gambit は「ある（target 間）」、本リポジトリは「**不十分**」 | 🔴 **判定の不一致**: 推移的な依存の import が `--explicit-target-dependency-import-check error` を付けても通る（M6-e・M6-f）。Gambit の測った M6-a〜M6-d はどれも「宣言の無い**兄弟**」で、依存の依存を測っていなかった。Gambit の CNF-011 は結果的にこの穴を塞いでいる |
| M-7 | 一致（不十分） | **追加**: `@preconcurrency import` が並行性の error を、`-warnings-as-errors` でも戻らない warning に下げる（M7-i）。`nonisolated(unsafe)` も並行性の検査を外す（M7-k。Gambit の CNF-014 は `unsafe` の字句で既に拾う）。本リポジトリは `@preconcurrency` を CNF-014 で拒否する |
| M-8 | 一致（言語では塞がらない） | **追加**: `.swift-format` の `rules` がリポジトリ全体の規則を切る（M8-j）。本リポジトリは CNF-005 で `.swift-format` の鍵を `version` / `indentation` / `lineLength` に限る |
| 補足 | — | 🔴 **Gambit の前提の不一致**: Gambit の ADR 0004 と CLAUDE.md は「release 構成では `@testable import` が使えない」と書くが、Swift 6.4.1 の `swift test -c release` では使えた（X-e・対照 X-f）。Gambit の phase0-results.json にこのケースは無く、測った記録は見つからなかった。テストを公開 API だけで書く方針そのものは SWF-008 として正しいが、その理由は「使えないから」ではない。この結果は Phase 3 のテストの ADR で使う |

#### NeNe Delve（1 回目）・ポリシー同梱の比較表の Swift 列

Gambit の ADR 0001 が Delve の列と突き合わせた結論（判定は 8 項目一致・M-7 の「pragma は無い」は `@diagnose` があるので不正確）を、本リポジトリの実測も支持する。
本リポジトリの結果からは、比較表の Swift 列について次も言える。M-6 の「ターゲット間は有る」は**直接の依存に限る**（M6-e）。
M-4 には extension の init の迂回（M4-f）、M-7 には `@preconcurrency`（M7-i）、M-8 には `.swift-format` の `rules`（M8-j）を足すべきである。
比較表の正本は本リポジトリの外にあるので、ここでは書き換えず、食い違いとしてここに残す。

4 回目でも M-1〜M-5・M-7・M-8 の判定は動かなかった。M-6 だけは、測る範囲を広げたら「ある」から「不十分」に変わった。
**同じ判定が 3 回続いても、測っていない形の穴は残る**。判定の確定とは「次に誰かが新しい形を測るまで」の意味である。

**そして、いま実装が空である。** 規則を後から被せる場合に必要になる baseline が、今は要らない。
違反ゼロから始められる時点は今しかない。

## 決定

**すべての規範規則に「機械強制の状態」を持たせ、その状態を文書の側で機械検査する。**

1. 規則の正本を `docs/ARCHITECTURE_CONSTITUTION.md` / `docs/CODING_RULES.md` / `docs/QUALITY_GATES.md` に置く。
   すべての規則に ID を与え、状態を **active / planned / 不能 / 不採用** で明示する。**planned を active と書かない**
2. `make check` を唯一の入口とする。CI は同じコマンドを呼ぶだけにし、CI 側にしか無い検査を作らない
3. baseline を持たない。例外は期限付きの狭い waiver だけ
4. 抑制には理由と規則 ID を要求する。Swift は抑制を言語で封じられない（M-7）ので **waiver 台帳を持つ**。
   SwiftLint の行単位の抑制（`swiftlint:disable:next` / `:this`）だけを、直前行の `// Waiver: WVR-NNNN` と有効な台帳の項目が
   そろったときに許す。`@diagnose`・`@preconcurrency`・`swift-format-ignore`・ファイル単位の抑制は waiver があっても拒否する
5. ゲートを弱める変更は ADR を要する
6. Swift の版は `.swift-version` だけが決める。SwiftLint の版と SHA-256 は `eng/swiftlint.lock` だけが決める。2 か所に書かない
7. **ゲートは意図的な違反で発火することを証明してから active と書く**（`docs/quality/gate-proofs.md`）
8. 規約検査（`eng/conformance.py`）は Python 3 の標準ライブラリだけで書く。自身の正例・反例テストをゲートから呼ぶ

実測から直接決まる Swift 固有の決定（Gambit と同じもの）:

- **警告のエラー化は `Package.swift` の各 target の `swiftSettings: [.treatAllWarnings(as: .error), ...]` 1 か所に置く。**
  コマンド行の `-Xswiftc -warnings-as-errors` は manifest に負ける（M8-h）ので置かない。規約検査が manifest を読み、全 target にこの設定があること、
  `treatWarning` / `treatAllWarnings(as: .warning)` / `unsafeFlags` が無いことを確かめる
- `@diagnose`・`@available(..., deprecated ...)`・`unsafeBitCast` 等の `unsafe` 系 API・`Codable` を字句検査で拒否する（M-4・M-7）
- Core と Engine と Render は import を許可リスト（宣言した直接の依存だけ・標準モジュールは無し）で縛り、時計・乱数・プロセス状態の API 名を字句検査で拒否する（M-5・M-6）
- 依存方向は SwiftPM の target グラフ（M6-a〜M6-d）を正とし、機械可読の正本 `docs/architecture/module-graph.txt` と `Package.swift` の宣言を突き合わせる
- `ExistentialAny` を全 target で有効にする（X-b）
- テスト target が 1 本も無い木では `swift test` が exit 1 になる（X-c）。意味の無いテストを足して結線しない。最初のテスト target が入る Phase 3 の PR で `make check` に結線する

Reversi の実測から新たに決めたこと（このリポジトリも同じ規則を移植して持つ）:

- 網羅性を殺す全捕捉は、`case` の選択肢を最上位の `,` で分けて、必ず一致するパターン（`_`・束縛・それだけのタプル）が 1 つでもあれば拒否する（M1-j・M1-k・M1-m → CNF-013）
- `init` は型の本体にだけ書き、`extension` に書かない（M4-f → CNF-021）
- どの target でも `async` / `await` / `Task` / `actor` / スレッド / Dispatch を書かない（M5-i → CNF-022・SWF-013）
- `@preconcurrency` を書かない（M7-i → CNF-014）
- `.swift-format` の鍵は `version` / `indentation` / `lineLength` だけ（M8-j → CNF-005）

## 強制

- **active にする条件**: Phase 2 で negative proof を `docs/quality/gate-proofs.md` に記録したもの。強制マトリクス（`docs/QUALITY_GATES.md` 第 3 節）が正本
- **不能**: 「`planned` を勝手に `active` と書き換えないこと」そのもの。文書整合検査は active の行に証明行があることまでは見るが、
  証明が本物かどうかは人が見るしかない

## 結果

得られるもの:

- 規約が自分について嘘をつく経路が塞がる
- 新しい貢献者（人でも AI でも）が「何がいま守られているか」を 1 か所で読める
- 規約を緩めるコストが上がる

失うもの:

- 文書のメンテナンスコスト。規則を足すたびに 3 か所（本文・マトリクス・実装）が同期を要求される
- 検査の実装そのものの保守。Swift の構文を字句で見るので、文字列リテラルやコメントの中身を誤検出しないよう検査器が字句を剥がす
- 書き味の制約: `switch` に全捕捉を書けないので、整数や文字列での分岐は `if` で書くか閉じた enum に直すことになる。
  `extension` に `init` を書けないので、別の表現から作る経路も型の本体の `static func` にまとめることになる。
  端末の termios / ioctl には `withUnsafeMutablePointer` 等が要るので、`unsafe` 系 API を許す区画を 1 つだけ作ることになる

**正直に記録しておくこと:**

- 🔴 字句検査は意味を見ない。`case` の選択肢が複数行にまたがり、行末が `,` でない形（例: 二項演算子で改行した式パターン）や、
  `typealias` で API 名を隠す迂回は、検査器が見る形を増やさない限り通る。見つけたら事故として規則に足す。
  **Gambit の CNF-013 は 3 回分の実測を経ても括弧と並びの形を見落としていた**ことが、その実例である
- 🔴 `==` と `else` の分岐（M1-i）は網羅性を持たないが、塞げない（SWF-002 の本文に書く）
- 🔴 `public var` とクラス参照の可変性は言語で塞げない。公開型を struct に寄せ、SwiftLint と規約検査で補えるところだけ補う
- 🔴 `swiftlint` の検査は静的バイナリの 0.65.1 に依存する。動的バイナリはこの環境の glibc 2.35 では起動しない（Gambit の実測。ここでは測り直していない）
- **本 ADR の厳格さは、実装がまだ空である今だからこそ無傷で導入できた。** 緑であることは、規則が良いことの証明ではない。
  検査対象がまだ小さいことの結果でもある。実装で規則が邪魔になったとき、緩めるのではなく **ADR で判断を残すこと**が本 ADR の眼目である

## 却下した選択肢

| 選択肢 | 却下の理由 |
| --- | --- |
| 散文の規約だけを置く | 守られているかを確かめる手段が無く、時間とともに必ず腐る。**本 ADR の出発点そのもの** |
| 既製 lint の既定セットだけで済ませる | 既製ルールは「Swift として危ういこと」を見るが、「NeNe Wire として守るべきこと」（Core が時計を読まない等）は見られない |
| 全 lint の一括有効化（SwiftLint の `opt_in_rules: all` 相当） | 相互に矛盾する規則が同時に入り、規則ではなく道具の機嫌に従うことになる |
| baseline を作って既存違反を後回しにする | 新規リポジトリなので既存違反が無い。ここで baseline を許すと、以後の違反も同じ入口から入ってくる |
| 実装が入ってから導入する | 既存違反を凍結する baseline が必要になる。今なら違反ゼロで始められる |
| 規約を `CLAUDE.md` にだけ書く | 人間と AI の遵守に依存する。前例（nene-recall）で、規約は CLAUDE.md にあったが守っていたのはテスト 10 ケースだけだった |
| 規則 ID を付けず散文で参照する | 「どの規則の話か」がレビューのたびに揺れる |
| 先行（Gambit）の実測結果を写して Phase 0 を省く | 写していたら M1-j・M1-k・M1-m・M4-f・M6-e・M7-i・M8-j の 7 つの穴を知らないまま規約を確定していた。同じ 56 ケースが一致したことは写してよい根拠ではなく、測り直した結果である |
| Gambit の CNF-013 の正規表現をそのまま移植する | 括弧の束縛・並べた `_`・全位置 `_` のタプルを通す（M1-j・M1-k・M1-m） |
| 警告のエラー化をゲートのコマンド行（`-Xswiftc -warnings-as-errors`）に置く | manifest の設定に負ける（M8-h・M8-i）。守っているように見えて守れない |
| `--explicit-target-dependency-import-check error` で import を縛る | 標準モジュール（Foundation）も推移的な依存も拒まない（M5-h・M6-f）。target 間の直接の依存は既定でも `no such module` になる（M6-a）ので、足しても何も増えない |
| `Foundation` の名前だけを禁止語にする | `FoundationEssentials` から同じ `Date` が読める（M5-j）。許可リストの形にする |
| `else` を字句で拒否する（M1-i を塞ぐ） | 正当な条件分岐（範囲の判定・Optional の有無）まで拒む。閉じた enum の分岐は `switch` で書くことを SWF-002 の本文に書き、レビュー事項として残す |
| `-typecheck` を高速な検査としてゲートに使う | 未初期化 `let` を見逃す（M3-a）。ゲートは本コンパイルを使う |
| 規約検査を Swift で書く | 検査器が検査対象と同じパッケージのビルドに乗り、ビルドが壊れたときに検査器も動かなくなる。Python 3 の標準ライブラリは CI のランナーにも WSL にも入っている |

## 関連

- 先行: NENE-PIXEL `docs/ADR`、nene-recall ADR 0010、xi-tools ADR 0001、NeNeCommander ADR-0001、NeNeClock ADR 0001、NeNe Delve ADR 0001、NeNe Gambit ADR 0001
- 実測: [docs/quality/phase0-results.json](../quality/phase0-results.json)・`eng/measure-language.py`
- 移植の記録: [ADR 0003](0003-port-gates-from-reversi.md)

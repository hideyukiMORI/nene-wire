# 品質ゲート — NeNe Wire

> Status: normative（規範）/ 2026-10-26 初版
> 本書は「いま何が機械で守られているか」の**正本**である。
> 規範の本文は [ARCHITECTURE_CONSTITUTION.md](ARCHITECTURE_CONSTITUTION.md) と
> [CODING_RULES.md](CODING_RULES.md)、機械側の実体はこの文書に対応する。

`make check` がローカルと CI の**唯一の完了定義**である。
個別の道具（`make build` / `make lint` / `make conformance` 等）は診断のために単独で回してよいが、その成功は完了の代わりにならない。

---

## 1. ゲートの整合性規則（QLT-0xx）

### QLT-001 — ゲートは一つ

ローカルの検証と CI は**同じ 1 つのコマンド**（`make check`）を呼ぶ。CI のワークフローに品質判断のロジックを書かない。
第 2 の完了定義を文書化しない。Swift の版は `.swift-version`、SwiftLint の版は `eng/swiftlint.lock` にだけ書き、
`make check` の最初の段（`eng/install-tools.sh`）が実際の版と突き合わせる。

- 機械強制: **active** → CNF-018（CI の `run` はツールチェーンの導入と `make check` の 1 行だけ）＋`eng/install-tools.sh`（版の不一致で失敗）

### QLT-002 — 警告は失敗する

コンパイラの警告・整形差分・静的解析の指摘はすべて失敗にする。重大度の引き下げは禁止。

🔴 警告のエラー化はゲートのコマンド行ではなく **`Package.swift` の各 target の `.treatAllWarnings(as: .error)`** に置く。
コマンド行の `-Xswiftc -warnings-as-errors` は manifest の `treatAllWarnings(as: .warning)` / `treatWarning` に負ける（実測 M8-h・M8-i）。
🔴 既知ケースを漏らす `@unknown default` の診断と、`@preconcurrency import` が下げた並行性の診断は、警告エラー下でも warning のまま exit 0 になる
（M1-e・M1-h・M7-i）。前者は CNF-013、後者は CNF-014 が字句で拒否する。
🔴 SwiftPM が manifest を解釈して出す警告（空のテスト target など）はコンパイラの警告ではないので `treatAllWarnings` の外にある（Gambit の Issue #3 の実測）。
`eng/swift-strict.sh` が `swift build` の出力の `warning:` を見て落とす。

- 機械強制: **active** → CNF-009（manifest）＋`eng/swift-strict.sh`（SwiftPM 自身の警告）＋`swift-format lint --strict`＋SwiftLint `strict: true`

### QLT-003 — baseline を作らない

lint・静的解析・アーキテクチャ・依存・テストのいずれについても baseline を持たない。既存の違反を「無かったこと」にする経路を作らない。
**唯一の例外機構は期限付きの狭い waiver である。**

- 機械強制: **active** → CNF-005

### QLT-004 — 整形は検査であって修復ではない

整形は `swift-format lint --strict --configuration .swift-format` で検査する。ゲートがソースを書き換えて成功させることはしない。
整形の設定は `.swift-format` 1 つだけ（入れ子の設定ファイルは CNF-007 が拒否する）。その鍵は `version` / `indentation` / `lineLength` だけで、
`rules` で規則を切ることはリポジトリ全体の抑制になる（M8-j）ので CNF-005 が拒否する。

- 機械強制: **active** → `make format`＋CNF-007＋CNF-005

### QLT-005 — ローカルと CI は同一

CI で必要なゲートは、すべてローカルで実行できる。検査を足したくなったら、まずローカルのゲートに足す。

- 機械強制: **active** → CNF-018

### QLT-006 — アーキテクチャは実行可能

モジュール境界・import 規律・状態の経路は機械が検査する。散文だけのアーキテクチャ規則は、**「不能」と明記されない限り未完成**として扱う。

- 機械強制: **active** → SwiftPM の target グラフ＋CNF-010 / CNF-011（推移的な依存の import も CNF-011 が見る・M6-e）

### QLT-007 — カスタムゲートには negative proof が要る

自作の検査は、「わざと違反させた入力で、意図した規則によって落ちること」と「正しい入力では通ること」の両方を示すまで信用しない。
証拠は [quality/gate-proofs.md](quality/gate-proofs.md) に記録する。ゲートを変えたら証拠も同じ変更で更新する。
検査器自身の正例・反例の単体テスト（`eng/tests/`）を `make conformance-test` としてゲートに結線する。

🔴 **設定が在ることは、検査が効いていることの証明ではない。** SwiftLint の静的バイナリは SourceKit が要る規則を黙って飛ばす。
`eng/lint.sh` は `Skipping enabled rule` が出たら失敗にする。

- 機械強制: **active** → `make conformance-test`＋CNF-006（active の行に、実測の空でない証明行があること）＋CNF-007

### QLT-008 — 振る舞いの変更はテストを伴う

振る舞いを変えたら、いちばん狭い安定した境界にテストを足す。不具合の修正は、可能なら**先に落ちる回帰テスト**を書いてから直す。

- 機械強制: **planned**（レビュー事項。テスト target は Phase 3 で入る）

### QLT-009 — カバレッジは下げられない

中核（Core）の分岐カバレッジの下限は、Phase 3 の縦切りで実測してから決める。決めたら上げてよいが下げてはならない。
**いまはカバレッジの層を置いていない。**

- 機械強制: **planned**

### QLT-010 — ゲートの弱体化はアーキテクチャ変更

重大度・除外・閾値・モジュール境界・必須 CI ジョブを変えるには明示的な根拠が要る。MUST 規則を弱める変更には ADR か waiver が要る。
**無関係な作業を通すために検査を切ることは禁止。**

- 機械強制: **不能**（判断そのものが対象。PR の手続きで担保する）

### QLT-011 — 依存は再現可能

製品の外部依存は 0。道具は版と SHA-256 で固定する（SwiftLint: `eng/swiftlint.lock`・CI の Swift: `eng/swift.lock`）。
許可リストに無い外部パッケージを manifest に書けない。

- 機械強制: **active** → CNF-009＋`eng/install-tools.sh` / `eng/install-swift.sh` の `sha256sum --check`

### QLT-012 — 検証の頻度は変更に従う

反復中は最も狭い検査を使う。**フルゲートは PR の Draft → Ready の時点で必ず通す。**
CI の起動条件は `ready_for_review`・`synchronize`・`edited`・`opened`・`reopened` で、**draft の間はジョブを失敗させる**（`eng/ci-require-ready.sh`）。
🔴 ジョブを `if:` で**スキップしてはならない**。GitHub はスキップされた必須 check を成功として数える。NeNe Gambit の PR #2 で、Ready にした直後に push の反映より先に
`ready_for_review` が届いて古い head で CI が走り、新しい head には draft 時のスキップだけが付いて、フルゲートを通っていない head が `CLEAN`（マージ可能）になった。
Ready の後の push は `synchronize` でフルゲートが回る。必須 check は head の SHA ごとに付き、ruleset の strict up-to-date が古い base を拒むので、
古い成功 SHA・スキップされたジョブ・狭い検査は、通ったフルゲートの代わりにならない。

- 機械強制: **active** → CNF-018（`if:` の禁止）＋`eng/ci-require-ready.sh`（draft なら失敗）＋ruleset の必須 check と strict up-to-date

### QLT-013 — 環境依存の主張は正直に名付ける

単体テストは端末・実機を必要としない。単体テストが通ったことを「Windows Terminal で正しく見える」の証拠として扱わない。
表示を伴う確認は [quality/gate-proofs.md](quality/gate-proofs.md) に環境と手順を書いて別に記録する。

- 機械強制: **planned**

---

## 2. 規約検査の規則（CNF-0xx）— `eng/conformance.py`

汎用の lint が見ないもの、つまり**このリポジトリ固有の規約**を検査する。Python 3 の標準ライブラリだけで書き、`make conformance` から常に呼ぶ。
各規則には正例・反例の単体テスト（`eng/tests/test_conformance.py`）を付け、`make conformance-test` でゲートに結線する（QLT-007）。
違反は `CNF-NNN パス:行: 説明` の形で出る。Swift の検査はコメントと文字列リテラルを剥がした本文に対して行う（文字列補間の中はコードとして残す）。

| ID | 内容 | 規則 | 状態 |
| --- | --- | --- | --- |
| `CNF-001` | 禁止された総称名（型名の語尾・ディレクトリ名・target 名） | SWF-010 | active |
| `CNF-002` | 最上位の型は 1 ファイル 1 つ・ファイル名＝型名 | SWF-011 | active |
| `CNF-003` | 抑制は行単位の `swiftlint:disable:next` / `:this` に waiver を添えたものだけ。`@diagnose`・`swift-format-ignore`・`@available(..., deprecated)` を拒否 | SWF-015 | active |
| `CNF-004` | waiver 台帳の整合（命名・必須項目・索引・**期限切れで落とす**） | SWF-015 | active |
| `CNF-005` | baseline とゲート無力化の禁止（名前に baseline を含むファイル・ゲートの経路の弱める指定・SwiftLint の除外系の設定・`.swift-format` の `version` / `indentation` / `lineLength` 以外の鍵・生成物の置き場以外を無視する `.gitignore`） | QLT-003 | active |
| `CNF-006` | 文書整合（規則 ID の重複定義・未定義参照・マトリクスの行・本文とマトリクスの状態の一致・active の証明行。実測が空か「未実測」の行は証明に数えない） | ADR 0001 | active |
| `CNF-007` | 検査設定が実際にゲートから読み込まれていること（設定は所定の 2 つだけ・Makefile が明示的に渡す・有効にした lint 規則に規則 ID） | QLT-007 | active |
| `CNF-008` | `TODO` / `FIXME` には `(#Issue番号)` | QLT-008 | active |
| `CNF-009` | manifest の設定（全 target に `treatAllWarnings(as: .error)` と `ExistentialAny`・`unsafeFlags` / `treatWarning` / `plugins:` 等の禁止・依存は許可リストだけ） | QLT-002 | active |
| `CNF-010` | SwiftPM の target と依存が正本 `docs/architecture/module-graph.txt` と一致・正本に循環が無い・合成ルートは 1 つ | ARC-002 | active |
| `CNF-011` | target ごとの import 許可リスト（宣言した直接の依存＋正本の `std=` だけ。Core・Render は標準モジュール無し・Foundation / FoundationEssentials はどこにも無い・テストは `Testing` だけ） | ARC-003 | active |
| `CNF-012` | 合成ルート以外で時刻・乱数・環境・プロセス状態を読まない（`using:` の無い `random(...)` 等） | ARC-007 | active |
| `CNF-013` | 網羅性を殺す全捕捉の禁止（`default:` / `@unknown default`・`case` の選択肢のどれかが `_`・束縛・それだけのタプル。括弧で包んでも並べても見る） | SWF-002 | active |
| `CNF-014` | `unsafe` 系 API は `unsafe=allowed` の target だけ。リフレクション・下線付き属性・`@preconcurrency`・マクロ・動的呼び出しはどこでも禁止 | SWF-009 | active |
| `CNF-015` | `Codable` / `Decodable` / `Encodable` の禁止 | SWF-007 | active |
| `CNF-016` | 公開の格納 `var` と `open` の禁止 | SWF-003 | active |
| `CNF-017` | 合成ルート以外で `print` / `readLine` / `exit` / `FileHandle` 等を使わない | ARC-006 | active |
| `CNF-018` | CI はツールチェーンの導入と `make check` の 1 行（と draft なら失敗する 1 行）だけを呼ぶ・`if:` を書かない・アクションは commit SHA で固定・token は `contents: read` | QLT-001 | active |
| `CNF-019` | 製品コード（`Sources/`）で `throws` / `throw` / `try` / `catch` を使わない | SWF-005 | active |
| `CNF-020` | `Any` / `AnyObject` / `AnyHashable` / `AnyClass` の禁止 | SWF-006 | active |
| `CNF-021` | `extension` の中に `init` を書かない（同じ target の別ファイルから `private init` を迂回できる・M4-f） | SWF-007 | active |
| `CNF-022` | どの target でも `async` / `await` / `Task` / `actor` / スレッド / Dispatch を使わない | SWF-013 | active |
| `CNF-023` | 外部プロセスを起動する API（`posix_spawn` / `fork` / `exec*` / `system` / `popen`）は、依存グラフの正本で `spawn=allowed` を宣言した target（Host）だけ | ARC-002 | active |

🔴 **検出語の一部は検査器のソースで文字列を分割して組み立てる**（検査器が自分自身を違反として報告する。前例: xi-tools 初版で 7 件の自己検出）。
🔴 **検査器の単体テスト（`eng/tests/`）は規約検査の参照検査の対象外**（テストは意図的な違反と架空の規則 ID を書く場所）。
Swift のテストソース（`Tests/`）は対象外にしない。テストにも決定性と網羅性の規則がかかる（CNF-019 だけは `Sources/` に限る）。
🔴 CNF-001〜CNF-022 は NeNe Wire の `eng/conformance.py`（コミット b3dac02）からの移植（その CNF-001〜020 は NeNe Gambit から）で、
CNF-023 はこのリポジトリで置き換えた（Reversi の CNF-023 は登録商標のゲーム名の検査で、NeNe Wire には当てはまらない・ADR 0003）。証明はすべてこのリポジトリで取り直した（[quality/gate-proofs.md](quality/gate-proofs.md)）。

---

## 3. 強制マトリクス

規範の各規則が、いまどの層で守られているか。**この表が実装と食い違ったら merge を止める。**
CNF-006 が「本文に定義があるのにここに行が無い」「本文とここで状態が違う」「active なのに証明行が無い」を拒否する。

| 規則 | 状態 | 機械強制の実体 |
| --- | --- | --- |
| ARC-001 | planned | レビュー事項（CNF-001 が温床を減らす） |
| ARC-002 | active | SwiftPM の target グラフ＋CNF-010 |
| ARC-003 | active | CNF-011＋CNF-012 |
| ARC-004 | planned | レビュー事項 |
| ARC-005 | planned | レビュー事項（CNF-016 が補助） |
| ARC-006 | planned | レビュー事項（CNF-017・CNF-014 が補助） |
| ARC-007 | active | CNF-012＋CNF-011 |
| ARC-008 | planned | レビュー事項 |
| ARC-009 | planned | 永続化を持たない（CNF-015 が補助） |
| ARC-010 | planned | レビュー事項（CNF-019 が補助） |
| ARC-011 | planned | レビュー事項（CNF-011 が補助） |
| ARC-012 | 不能 | QLT-010 の手続き |
| SWF-001 | planned | レビュー事項 |
| SWF-002 | active | コンパイラ（M1-a）＋CNF-013＋SwiftLint `fallthrough` |
| SWF-003 | active | コンパイラ（M2-a・M2-b）＋CNF-016 |
| SWF-004 | active | SwiftLint（`force_unwrapping` ほか 5 規則） |
| SWF-005 | active | CNF-019＋SwiftLint `force_try` |
| SWF-006 | active | CNF-020＋SwiftLint `large_tuple` |
| SWF-007 | planned | レビュー事項（CNF-021・CNF-015・CNF-014 が補助） |
| SWF-008 | planned | レビュー事項（swift-format `FileScopedDeclarationPrivacy` が補助） |
| SWF-009 | active | CNF-014＋CNF-009 |
| SWF-010 | active | CNF-001 |
| SWF-011 | active | CNF-002 |
| SWF-012 | active | SwiftLint（複雑度・長さ・引数・入れ子の 6 規則） |
| SWF-013 | active | CNF-022＋CNF-011 |
| SWF-014 | active | CNF-011＋CNF-012 |
| SWF-015 | active | CNF-003＋CNF-004＋SwiftLint `superfluous_disable_command` / `blanket_disable_command` |
| SWF-016 | active | CNF-011 |
| SWF-017 | 不能 | 測る道具が無い（レビュー事項） |
| SWF-018 | planned | レビュー事項（CNF-016 が補助） |
| GIT-001 | planned | PR テンプレートの `Closes #N`（検査は無い） |
| GIT-002 | planned | ruleset で `main` を保護（ブランチ名の形の検査は無い） |
| GIT-003 | active | `.githooks/commit-msg`＋`make commits`（PR の全コミット） |
| GIT-004 | active | ruleset（PR 必須・squash のみ・必須 check） |
| GIT-005 | planned | PR タイトルの検査は無い |
| QLT-001 | active | CNF-018＋`eng/install-tools.sh` |
| QLT-002 | active | CNF-009＋`eng/swift-strict.sh`＋`swift-format --strict`＋SwiftLint `strict` |
| QLT-003 | active | CNF-005 |
| QLT-004 | active | `make format`＋CNF-007＋CNF-005 |
| QLT-005 | active | CNF-018 |
| QLT-006 | active | SwiftPM＋CNF-010＋CNF-011 |
| QLT-007 | active | `make conformance-test`＋CNF-006＋CNF-007 |
| QLT-008 | planned | レビュー事項 |
| QLT-009 | planned | カバレッジの層を置いていない |
| QLT-010 | 不能 | PR の手続き |
| QLT-011 | active | CNF-009＋lock の SHA-256 照合 |
| QLT-012 | active | CNF-018（`if:` の禁止）＋`eng/ci-require-ready.sh`＋ruleset の必須 check と strict |
| QLT-013 | planned | レビュー事項 |
| CNF-001 | active | `eng/conformance.py` |
| CNF-002 | active | `eng/conformance.py` |
| CNF-003 | active | `eng/conformance.py` |
| CNF-004 | active | `eng/conformance.py` |
| CNF-005 | active | `eng/conformance.py` |
| CNF-006 | active | `eng/conformance.py` |
| CNF-007 | active | `eng/conformance.py`＋`eng/lint.sh` |
| CNF-008 | active | `eng/conformance.py` |
| CNF-009 | active | `eng/conformance.py` |
| CNF-010 | active | `eng/conformance.py` |
| CNF-011 | active | `eng/conformance.py` |
| CNF-012 | active | `eng/conformance.py` |
| CNF-013 | active | `eng/conformance.py` |
| CNF-014 | active | `eng/conformance.py` |
| CNF-015 | active | `eng/conformance.py` |
| CNF-016 | active | `eng/conformance.py` |
| CNF-017 | active | `eng/conformance.py` |
| CNF-018 | active | `eng/conformance.py` |
| CNF-019 | active | `eng/conformance.py` |
| CNF-020 | active | `eng/conformance.py` |
| CNF-021 | active | `eng/conformance.py` |
| CNF-022 | active | `eng/conformance.py` |
| CNF-023 | active | `eng/conformance.py` |

---

## 4. `make check` に入っている層

| 段 | 目的 | 実体 |
| --- | --- | --- |
| `tools` | 道具の版の一致 | `eng/install-tools.sh`（swift と swift-format は `.swift-version`、SwiftLint は `eng/swiftlint.lock`） |
| `build` | 型安全・網羅性・警告ゼロ | `eng/swift-strict.sh swift build`（警告のエラー化は manifest。SwiftPM 自身の警告も落とす） |
| `format` | 文字列としての正本 | `swift-format lint --strict --configuration .swift-format`（全 Swift ファイル） |
| `lint` | 構造と複雑度 | `eng/lint.sh`（SwiftLint 0.65.1 `--strict`・規則の飛ばしで失敗） |
| `conformance` | NeNe Wire 固有・API 単位の禁止・アーキテクチャ・文書整合 | `python3 eng/conformance.py` |
| `conformance-test` | 規約検査の正例・反例 | `python3 -m unittest discover -s eng/tests` |
| `commits` | コミットの形 | `eng/validate-commit-message.py --range $(BASE)..HEAD` |
| 単体テスト | 振る舞い | **まだ無い**（テスト target が無い木の `swift test` は exit 1・X-c。Phase 3 で結線） |
| カバレッジ | 中核の検証密度 | **まだ無い**（QLT-009） |
| 依存 | 再現性 | 外部依存 0。CNF-009 が許可リスト外を拒否 |

---

## 5. マージゲート

`main` は次を必須とする。

- Pull Request 経由であること
- `make check` が成功していること（CI の必須 check `check`）
- 期限切れ waiver が無いこと（CNF-004 が `make check` を落とす）
- squash merge のみ

`main` への直接 push・force push・ブランチ削除は禁止する。

🔴 **リポジトリ設定（ruleset）を適用したら、その事実を [quality/gate-proofs.md](quality/gate-proofs.md) に記録する。**
**設定していないものを「必須になっている」と書かない。**
🔴 必須 check の context は job 名の `check` である（ワークフロー名付きの `CI / check` では緑でも `BLOCKED` のままになった前例がある）。

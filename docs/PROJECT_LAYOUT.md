# モジュール構成と依存規則 — NeNe Wire

> Status: normative（規範）/ 2026-10-26 初版
> パッケージ: SwiftPM `NeNeWire`（`Package.swift`）

モジュールグラフはアーキテクチャの一部である。**ディレクトリの命名規約だけでは依存の境界にならない。**
承認された一覧の機械可読な正本は `docs/architecture/module-graph.txt` で、規約検査が `Package.swift` の宣言と突き合わせる（ARC-002・CNF-010）。

---

## 1. 承認されたモジュール

空の「将来用 target」を作らない。**2026-10-26 時点で `Package.swift` の target は 0 本**であり、下の一覧は「承認された形」である（ADR 0004）。
各 target は最初の具体的な責務が生じた PR で足す（Phase 3 の手順 1 で `NeNeWireCore`・`NeNeWireHost` と合成ルートが最初に入る見込み）。

```text
nene-wire (executable)
    合成ルート。時計・乱数（シード）・環境・起動オプションを読み、Core・Render・Terminal・Host を組み立てる。
    1 本のループでキー入力・子プロセスの出力・締め切りを待つ。標準入出力への直書きと終了コードを持つ唯一の場所（ARC-006 / ARC-007）

NeNeWireHost
    外の世界との境目。子プロセス（フィードの取得・翻訳の手段）の起動と入出力・ファイル（記事と設定の保存）。
    外から読んだものはバイト列のまま返し、解釈は Core に任せる。unsafe 系 API を許す区画（SWF-009）

NeNeWireTerminal
    セル格子 → ANSI の差分出力・termios・SIGWINCH・キーと文字の入力の解析。unsafe 系 API を許す区画（SWF-009）

NeNeWireRender
    画面の状態 → 文字セルの格子（全角の幅・折り返し・演出・配色・各画面）。端末も外の世界も知らない。出力は値

NeNeWireCore
    フィード・記事・RSS / Atom の解析・HTML の除去・出だしの切り出し・言語の判定・並べ方・保持期間・取得の間隔と再挑戦・
    翻訳待ち・保存と設定の文字列表現。時刻・乱数源・端末・ネット・Foundation・ファイルを知らない。値型＋純粋関数（時刻は引数で受け取る）
```

テスト target は `<target>Tests`（`NeNeWireCoreTests` 等）で、Swift Testing だけを import できる（SWF-016）。

---

## 2. 許可された依存グラフ

```text
NeNeWireCore      -> （無し）
NeNeWireRender    -> NeNeWireCore
NeNeWireTerminal  -> NeNeWireRender                        ＋ 標準モジュール Glibc
NeNeWireHost      -> NeNeWireCore                          ＋ 標準モジュール Glibc
nene-wire         -> 上の 4 つすべて（明示的な合成のためだけに） ＋ 標準モジュール Glibc
```

ここに無い依存はすべて禁止である。とくに:

- Core / Render -> Foundation・FoundationEssentials・Glibc・Dispatch: **禁止**（標準モジュールはビルドグラフでは塞げないので CNF-011 が塞ぐ）
- 宣言していない推移的な依存の import（例: Terminal -> Core）: **禁止**（SwiftPM は拒まない・M6-e。CNF-011 が塞ぐ）
- Core -> Render、Render -> Terminal 等の逆向き: 禁止（SwiftPM が `no such module` で拒み、CNF-010 が宣言を拒む）
- Render <-> Host・Terminal <-> Host: 禁止（つなぐのは合成ルートだけ）
- 外部プロセスの起動（`posix_spawn` / `fork` / `exec*` / `system` / `popen`）: Host 以外は**禁止**（CNF-023）
- 何か -> 合成ルート: 禁止
- Foundation: どの target からも禁止（SWF-014）

---

## 3. 各モジュールの責務

### `NeNeWireCore`

意味の正本を持つ。フィードの定義・記事（見出し・出だし・リンク・公開時刻・言語）・RSS / Atom の解析と拒否理由・HTML の除去と文字参照の解決・
出だしの切り出し（2〜3 文・250 文字程度）・言語の判定・表示の並べ方（フィードを巡回しながら新しい順）・保持期間・
取得の間隔と再挑戦の規則・翻訳待ちの管理・保存と設定の文字列表現の読み書き。時刻は「いま」を引数で受け取る。

### `NeNeWireRender`

画面の状態から文字セルの 2 次元配列を作る。全角文字の幅の表（Unicode の East Asian Width から作る）と折り返しは Render の 1 か所。
演出（枠・記号から確定する見出し・タイプライター・浮かび上がり・ノイズ・走査線・文字の雨・ブートログ）は「経過時間と乱数の種」から格子を作る純粋な関数。
色は Render の配色表だけが持つ。

### `NeNeWireTerminal`

alternate screen・カーソル非表示・24bit カラー（無ければ 256 色）・前フレームとの差分・1 フレーム 1 回の `write`・SIGWINCH・
**異常終了でも端末を必ず復元**。キー入力を閉じた enum の意図に変え、設定画面の文字の入力（UTF-8）を読む。可変性の隔離区画（ARC-005）。

### `NeNeWireHost`

子プロセスの起動と、その標準出力・終了状態の受け取り（ブロックしない）。ファイルの読み書き（書くときは一時ファイルから rename で置き換える）。
置き場所（XDG の設定・データの場所）の解決は合成ルートが環境変数を読んで渡す。可変性の隔離区画（ARC-005）。

### `nene-wire`

依存を結ぶ。「いつ取りに行くか」「何秒ごとに描くか」はここが時計を読んで決め、Core の規則に時刻を渡す。
端末出力（起動できなかった理由 1 行）と終了コードを扱ってよい唯一の場所（ARC-006）。

---

## 4. ソースの置き場

| 種類 | 置き場 |
| --- | --- |
| production | `Sources/<target>/`（`path:` で変えない・CNF-009） |
| テスト | `Tests/<target>Tests/`（規約検査の対象。決定性・網羅性の禁止も適用する） |
| 検査設定 | `.swiftlint.yml`・`.swift-format`（直下の 2 つだけ・CNF-007） |
| 規約検査とその単体テスト | `eng/conformance.py`・`eng/tests/` |
| 依存グラフの正本 | `docs/architecture/module-graph.txt` |
| 生成コード | 無い（SwiftPM のビルドプラグインを使わない・SWF-009） |
| 道具の置き場 | `.tools/`（git 管理外。`eng/install-tools.sh` が lock の SHA-256 で入れる） |

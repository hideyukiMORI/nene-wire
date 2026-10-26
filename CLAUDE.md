# CLAUDE.md — NeNe Wire

Claude Code / AI エージェントがこのリポジトリで作業するための**中核ハンドブック**。
簡潔な英語版の入口は [AGENTS.md](AGENTS.md)。詳細の正本は `docs/` にあり、ここには複製しない。

---

## 0. まず読むもの（production コードに触れる前に必ず）

1. [docs/ARCHITECTURE_CONSTITUTION.md](docs/ARCHITECTURE_CONSTITUTION.md) — 憲章（ARC-NNN）
2. [docs/PROJECT_LAYOUT.md](docs/PROJECT_LAYOUT.md) — モジュールと依存方向
3. [docs/CODING_RULES.md](docs/CODING_RULES.md) — Swift 6 規約（SWF-NNN）
4. [docs/QUALITY_GATES.md](docs/QUALITY_GATES.md) — **いま何が機械で守られているか**（QLT-NNN / CNF-NNN）
5. [docs/DEVELOPMENT_WORKFLOW.md](docs/DEVELOPMENT_WORKFLOW.md) — 手順
6. [docs/COMMIT_CONVENTIONS.md](docs/COMMIT_CONVENTIONS.md) — Issue・ブランチ・コミット・PR（GIT-NNN）
7. [docs/GLOSSARY.md](docs/GLOSSARY.md) — 用語
8. 該当する ADR（`docs/adr/`）と有効な waiver（`docs/waivers/`）

---

## 1. このリポジトリの統治原則

> **一つのことを実現する方法を 1 つに固定し、そのことを人の記憶ではなく機械に守らせる。**

その帰結として、次の 3 つを常に守る。

1. **正典の経路を先に特定してから編集する。** 「ここで書いたほうが早いから」で第 2 の経路を作らない（ARC-001 / ARC-012）
2. **ゲートを弱めて通さない。** 検査が落ちたらコードを直す。閾値・除外・重大度を触るのは ADR 相当の判断（QLT-010）
3. **`planned` を `active` と書かない。** 未実装の強制を実装済みに見せるのは、この規約体系で唯一「壊す」行為（[ADR 0001](docs/adr/0001-strictness-is-mechanically-enforced.md)）

---

## 2. このプロジェクトで間違えやすい所

### 外の世界に触れるのは Terminal と Host だけ

ネット（フィードの取得）・翻訳の手段・ファイル（記事と設定の保存）は、子プロセスとファイル記述子として **Host** だけが扱う（ADR 0004）。
外部プロセスを起動する API（`posix_spawn` / `fork` / `exec*` / `system` / `popen`）は Host 以外で書くと規約検査（CNF-023）が落とす。
Host は外から読んだバイト列を返すだけで、XML の解析や応答の読み取りは Core が持つ。

### 表示を待たせないのは子プロセスで、スレッドではない

取得と翻訳は「表示の裏で」進める（FR-13）が、どの target でも `async` / `await` / `Task` / `actor` / スレッド / Dispatch を書かない（SWF-013・CNF-022）。
裏で走るのは子プロセスで、合成ルートの 1 本のループが `poll(2)` でキー入力・子プロセスの出力・締め切りを待つ。

### 日本語は 2 桁を占める

全角の文字は端末で 2 桁を占める（FR-04）。何桁かの判定は Render の 1 か所（Unicode の East Asian Width の表）だけで、`String.count` を桁数として使わない。

### 現在時刻・乱数・環境を読む場所は 1 つしかない

時計・乱数・環境変数・起動オプション（`CommandLine`）を読んでよいのは **合成ルート `nene-wire`** だけである（ARC-007）。
Swift ではどれも標準ライブラリだけで書けてしまう（`Int.random`・`ContinuousClock.now`・`CommandLine.arguments`・`Task.sleep`）ので、
規約検査（CNF-012・CNF-022）が字句で落とす。乱数が要る関数は乱数源を `inout` で受け取り、`random(in:using:)` のように `using:` を付けて呼ぶ。
**テストにも同じ禁止がかかる。**

### 網羅性検査を殺す分岐を書かない

`switch` に `default:` / `@unknown default` / `case _:` / `case let x:` を書かない。**括弧で包んだ `case (let x):`・並べた `case .a, _:`・
全位置が `_` のタプル `case (_, _):` も同じ全捕捉**で、コンパイラは何も言わない（M1-j・M1-k・M1-m）。CNF-013 が `case` の選択肢を 1 つずつ見て落とす。
既知ケースを漏らす `@unknown default` は警告エラーでも warning のまま通ってしまう（M1-e）。選択肢が増えたらコンパイルが落ちるのが正しい状態。
閉じた enum を `==` と `else` で分岐すると網羅性が無くなるが、これは機械では塞げない（M1-i）。閉じた enum は `switch` で分岐する。

### 文字列で分岐するなら `if`

`switch` を `String` や `Int` に使うと全捕捉が要るが、全捕捉は CNF-013 が落とす（Gambit の証明 P50 では `case _ where true:` もコンパイラが拒んだ）。
文字列や整数での分岐は `if` で書くか、閉じた enum に直してから `switch` する。

### `init` は型の本体にだけ書く

`private init` は、同じ target の別ファイルの `extension` に `init` を足すと格納プロパティを直接埋めて迂回できる（M4-f）。
`extension` に `init` を書かない（CNF-021）。別の表現から作る経路は、型の本体の `static func`（結果型を返す唯一のファクトリ）にする。

### 警告のエラー化は `Package.swift` にある

target を足すときは `swiftSettings: [.treatAllWarnings(as: .error), .enableUpcomingFeature("ExistentialAny")]` を必ず付ける（CNF-009）。
コマンド行の `-Xswiftc -warnings-as-errors` は manifest の設定に負ける（M8-h）ので、そこに頼らない。
`@preconcurrency import` は並行性の error を、警告エラーでも戻らない warning に下げる（M7-i）ので書かない（CNF-014）。

### 依存の依存は import できてしまう

SwiftPM は、宣言していない**推移的な**依存の import を拒まない（M6-e。`--explicit-target-dependency-import-check error` でも通る・M6-f）。
target が import してよいのは、依存グラフの正本で宣言した直接の依存と標準モジュールだけで、CNF-011 が字句で見る。

### 期待される失敗は例外にしない

読めない局面の文字列・合法でない手などは閉じた enum の結果型で返す。製品コードに `throw` / `try` / `catch` を書かない（ARC-010 / SWF-005・CNF-019）。

### 並行性は使わない

どの target でも `async` / `await` / `Task` / `actor` / スレッド / Dispatch を書かない（SWF-013・CNF-022）。待つのは合成ルートの 1 本のループだけ。

### SwiftPM 自身の警告も失敗になる

`eng/swift-strict.sh` が `swift build` の出力の `warning:` を見て落とす。テスト target を足したらソースも同じ PR で足す（空のテスト target は警告になる）。

### SwiftLint は静的バイナリ

動的バイナリは glibc 2.35 では起動しない（Gambit の実測）。`make bootstrap`（または `make check` の `tools` 段）が `.tools/swiftlint` に静的バイナリを入れる。

## 3. 検証コマンド

```bash
make bootstrap      # clone 直後に 1 回（コミットフックと SwiftLint）
make check          # 唯一の完了定義（ローカルと CI で同じ）
```

開発中は最も狭い検査を使ってよい。フルゲートは **PR を Draft → Ready にする直前**に必ず通す。

🔴 **`make check` が通っていないものを「できた」と報告しない。**
実行していないコマンドの結果を書かない。テストの失敗を隠さない。
テストが本当の欠陥を見つけたら、期待値ではなく production コードを直す。

---

## 4. 変更の進め方

[docs/DEVELOPMENT_WORKFLOW.md](docs/DEVELOPMENT_WORKFLOW.md) が正本。要約すると:

Issue → 正典経路の特定 → ブランチ → （設計を変えるなら先に ADR）→ 最小の実装 →
テスト → 狭い検査 → `make check` → 規則 ID ごとの自己レビュー → PR（draft）→ Ready → squash merge。

コミットは Conventional Commits（`type` と `scope` は英語、説明は日本語、末尾に `(#N)`）。形の正本は GIT-003。

---

## 5. 完了報告の形

作業を終えたら必ず次を報告する。

```text
Issue / 規則 ID:
変更したファイルと振る舞い:
実行した検証コマンドと結果:
ドキュメント・スキーマの変更:
Waivers: none | WVR-NNNN
残るリスク:
```

調査だけを頼まれたときは、編集・コミット・push・PR 作成・外部状態の変更を行わない。

---

## 6. いまの状況

現在のタスクは [docs/todo/current.md](docs/todo/current.md)。GitHub Issue が正で、そこは要約。

- 動くもの: `make check`。`nene-wire --list` が最初の 4 本のフィードを取り、見出し・出だし・リンク・公開時刻を素のまま出す（ADR 0005）。
  `nene-wire` が端末の幅いっぱい・高さ 15 行の帯（起動したら画面を消して最上部に描く）に常駐し、裏で取り直しながら記事を流し続け、どの終わり方でも端末を戻す（ADR 0006・0007）
- 配布: `make release TAG=v<版>` の 1 経路（QLT-014・ADR 0008）。`nene-wire --demo` はネットを使わず架空の記事で動く（画面写真用）。公開は施主の確認を取る
- 動かないもの: 演出・記事の保存・翻訳・設定画面。Phase 3 の次は「演出」
- 施主の決定は [docs/REQUIREMENTS.md](docs/REQUIREMENTS.md) にそろっている。決定を覆したくなった点や、要件に無い機能を足したくなった点は、自分で決めずに施主に聞く

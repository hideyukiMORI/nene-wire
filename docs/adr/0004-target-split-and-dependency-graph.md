# ADR 0004 — target は Core・Render・Terminal・Host・合成ルートの 5 つに分け、外の世界に触れるのは Terminal と Host だけにする

- 状態: 受理
- 日付: 2026-10-26
- Issue: #1
- 影響する規則: ARC-002 / ARC-003 / ARC-006 / ARC-007 / ARC-011 / CNF-010 / CNF-011 / CNF-023

## 文脈

依存方向を物理的にする（ARC-002）には、責務ごとに SwiftPM の target を分け、禁じた向きを「import できない」状態にする必要がある。
兄弟の NeNe Gambit・NeNe Reversi は「端末に描き続けるスクリーンセーバー」を Core・Engine・Render・Terminal・合成ルートの 5 つで作った。

NeNe Wire がそれと違うのは、**外の世界から読むものがある**こと: フィードをネットから取る・翻訳の手段を呼ぶ・記事と設定をファイルに保存する。
一方で、探索のような「Engine」にあたる重い計算は無い。並べ方・取得の間隔・翻訳待ちの管理は、時刻を引数で受け取る純粋な規則として Core に置ける。

Phase 0 の実測で、SwiftPM は兄弟の target の import を拒むが、**推移的な依存の import は拒まない**ことが分かった（M6-a・M6-e・M6-f）。

## 決定

依存グラフの正本は `docs/architecture/module-graph.txt` とし、次の 5 つの target とそれぞれのテスト target を承認する。

```text
NeNeWireCore      フィード・記事・RSS / Atom の解析・HTML の除去・出だしの切り出し・言語の判定・並べ方・保持期間・
                  取得の間隔と再挑戦・翻訳待ち・保存と設定の文字列表現（依存なし。時刻・乱数・ファイル・ネットを知らない）
NeNeWireRender    画面の状態 → 文字セルの格子（全角の幅・折り返し・演出・テーマ・各画面）（-> Core）
NeNeWireTerminal  セル格子 → ANSI の差分出力・termios・シグナル・キーと文字の入力（-> Render ＋ Glibc・unsafe を許す）
NeNeWireHost      外の世界との境目: 子プロセス（取得と翻訳）・ファイル（記事と設定）（-> Core ＋ Glibc・unsafe を許す）
nene-wire         合成ルート。時計・乱数・環境・起動オプションを読み、1 本のループで入力と子プロセスと締め切りを待つ（-> 上の 4 つ ＋ Glibc）
```

- Host は Core の値（取得の要求・翻訳の要求・保存する記事）を受け取り、外から読んだバイト列を返す。解釈（XML の解析・応答の読み取り）は Core が持つ
- Render は Host を知らない。Host は Render を知らない。両者をつなぐのは合成ルートだけ
- target は最初の具体的な責務が生じた PR で `Package.swift` に足す。Phase 1 の `Package.swift` の target は 0 本
- 兄弟が後から広げた Terminal の標準モジュール `Synchronization`（シグナルの旗）は、このリポジトリで同じ必要が生じた PR で、この ADR を置き換える ADR とともに足す

## 強制

- **active** → SwiftPM の target グラフ（兄弟の import と循環を拒む）＋CNF-010（`Package.swift` と正本の一致・正本の循環・合成ルートは 1 つ）＋
  CNF-011（各ファイルの import が、正本で宣言した直接の依存と `std=` の標準モジュールだけであること）＋
  CNF-023（外部プロセスを起動する API は Host だけ）

## 結果

- 「Core は時計もネットもファイルも知らない」「Render は外の世界を知らない」が、レビューではなく import の失敗で守られる
- XML の解析・言語の判定・並べ方などの中心の規則が、ネットにつながずにテストできる
- 失うもの: Host のテストは本物の子プロセス（`/bin/echo` など）を起動する。ネットにはつながない

## 却下した選択肢

| 選択肢 | 却下の理由 |
| --- | --- |
| 兄弟と同じ Engine を置く | 探索のような重い計算が無い。並べ方や取得の間隔は純粋な規則で、Core に置ける。使わない target は作らない |
| ネットとファイルを合成ルートに直接書く | 合成ルートに unsafe 系の API が広がり（CNF-014）、子プロセスの扱いがテストできなくなる |
| 取得・翻訳・ファイルを別々の target にする | どれも「Glibc で外の世界に触れる」同じ種類の責務で、境界を増やしても禁じたい向きが増えない。翻訳の手段の差し替え（FR-28）は Host の中の型で分ける |
| Foundation（URLSession・JSONDecoder）を使う | どの target からも禁止（SWF-014）。静的リンクの配布物で FoundationNetworking は libcurl などへの依存を連れてくる |

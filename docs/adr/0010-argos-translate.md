# ADR 0010 — 翻訳は Argos Translate を torch 抜きで入れ、子プロセスでまとめて訳す。訳せなければ原文で流す

- 状態: 受理
- 日付: 2026-10-26
- Issue: #18
- 影響する規則: ARC-006 / ARC-007 / SWF-013 / CNF-022 / CNF-023 / FR-05 / FR-09 / FR-10 / FR-13 / FR-14 / FR-15 / FR-27 / FR-28 / FR-29 / Q5

## 文脈

施主は「翻訳はArgos Translateがいいんじゃない？」と決めた（REQUIREMENTS の Q5）。Argos Translate は登録の要らないオフラインの翻訳（FR-05）。

実測（2026-10-26・この WSL の Ubuntu 22.04・Python 3.10.12）:

| 項目 | 結果 |
| --- | --- |
| argostranslate 1.11.0 の依存 | `stanza==1.10.1` を要求し、stanza は torch を連れてくる（数百 MB〜数 GB） |
| torch を入れない形 | Argos を依存なしで入れ、ctranslate2・sentencepiece・minisbd・sacremoses・packaging だけを足すと動く。文の区切りを MINISBD にする公式の設定（`ARGOS_CHUNK_TYPE=MINISBD`）を使い、Argos が最初に行う `import stanza` は空のモジュールで満たす |
| 大きさ | Python の置き場 345 MB＋en→ja のモデル 129 MB |
| 速さ | 読み込み 0.19 秒・1 件 0.1 秒ほど。実際のフィードの 98 件（英語 91 件）を 20 秒ほどで訳し終えた |
| 訳の質 | 「Night trains return to the coastal line after a decade」→「夜行列車は10年後に海岸線に戻ります」・「Brazil's left-wing President Lula elected for fourth term」→「ブラジルの左翼社長ローラが4学期に選出」。見出しの意味はつかめる（FR-27 の求める程度）が、固有名詞や語の選び方は崩れることがある |
| `python3 -m venv` | Ubuntu では `python3-venv` が無いと失敗する。`pip --target` の置き場なら要らない |

## 決定

1. **入れ方**: `install-translator.sh`（リポジトリの直下・`curl … | bash` でも入る）。`~/.local/share/nene-wire/argos/lib` に `pip --target` で、版を固定して入れる（argostranslate 1.11.0 を依存なしで・ctranslate2 4.8.4・sentencepiece 0.2.2・minisbd 0.9.5・sacremoses 0.1.1・packaging 26.3）。
   en→ja のモデルは Argos の置き場（`~/.local/share/argos-translate`）に Argos 自身の方法で入れ、最後に 1 文を試しに訳す
2. **呼び方**: Host の `TranslateCommand` が `python3 -c <台本> en ja <文字列…>` を子プロセスで起動する（`PYTHONPATH` に置き場・`ARGOS_CHUNK_TYPE=MINISBD`・`PYTHONIOENCODING=utf-8`）。台本は 1 行 1 件で `<番号>\t<訳>` を出し、使えなければ `ERR\timport` か `ERR\tmodel`。
   出力を読むのは Core の `TranslationReply` の 1 か所。翻訳の手段を替えるときは、この 2 つを替える（FR-28）
3. **待ち行列**（Core の `TranslationQueue`）: 取れた記事の言語を文字の種類で判定し（FR-09・`LanguageGuess`。かなか漢字が 2 割以上なら日本語、ラテン文字が 8 割以上なら英語）、表示の言語（日本語）と違う記事を待たせる。
   1 回に 8 件までをまとめて訳す（モデルの読み込みを 1 回で済ませる）。訳は控えて訳し直さない（FR-10）。失敗したら 10 分あけて取り直す。控えは巡りにある記事の分だけを残す（FR-02）
4. **裏で**: 合成ルートの `Translator` が取得と同じ形で子プロセスを起動し、表示のループが取得の出力と一緒に `poll` で待つ（FR-13・並行性は使わない）
5. **表示**: 記事を見せ始めたときの訳で文面を固定する（見せている途中で訳が届いても文面を跳ねさせない）。訳した記事は見出しと出だしを訳で出し、枠の中に `原文 <原文の見出し>` を添える（FR-14）。
   訳せていない外国語の記事は原文のまま、受信の行に `未翻訳`（FR-10）。状態の行に `TRANS en>ja ● 待ち N`（FR-15）。矢印は端末によって 2 桁に描かれるので ASCII の `>` にした
6. **未導入**（FR-29）: 置き場が無ければ一度も起動せず、原文のまま流す。ブートログに「翻訳エンジン …… 未導入（install-translator.sh で入る）」、状態の行に `TRANS 未導入`、モデルが無いと分かったときは MSG に入れ方を出す

## 強制

- **active** → CNF-023（子プロセスの起動は Host だけ）＋CNF-022（並行性の禁止）＋CNF-012（言語の判定と待ち行列は時刻を引数で受け取る）
- テストで確かめる（`make check` の `test` 段）: 言語の判定・出力の読み方と使えない理由・待ち行列（外国語だけ・1 回だけ・8 件まで・失敗は 10 分・控えの刈り込み）・訳した記事が原文の見出しを持つ・
  本物の python3 で台本を走らせ、偽の `argostranslate` を読ませて 1 行 1 件で訳が返る・言語の組が無い／パッケージが無いを名指しする・表示（原文の行・未翻訳・状態の行）
- 実機で確かめた（2026-10-26）: 本物のフィードで英語の記事が日本語で出て、原文の見出しが添えられる。HOME を空の所にすると、ブートログと状態の行が「未導入」を出し、英語の記事に `未翻訳` が付き、止まらずに流れ続ける

## 結果

- 英語の見出しが日本語で読める。ネットにもアカウントにも頼らない（モデルを落とす最初の 1 回を除く）
- 失うもの: 470 MB ほどの置き場。訳の質は機械翻訳の水準（固有名詞の崩れ）。いまは英語から日本語だけ（表示の言語の設定は手順 6）

## 却下した選択肢

| 選択肢 | 却下の理由 |
| --- | --- |
| `pip install argostranslate`（依存込み） | torch を連れてきて数百 MB〜数 GB 増える。stanza は MINISBD にすれば使わない |
| venv に入れる | Ubuntu では `python3-venv` を別に入れないと作れない |
| 記事 1 件ごとに子プロセスを起動する | 毎回モデルを読み込む。8 件ずつまとめれば読み込みは 1 回 |
| 常駐する翻訳のプロセスと標準入力でやり取りする | 書き込みと読み出しを同時に扱う必要があり、子プロセスの経路が 2 つになる。まとめて訳せば 1 回 1 秒ほどで足りる |
| 見せている途中で訳が届いたら文面を差し替える | 文面が跳ねて読みにくい。次に巡ってきたときに訳で出る |

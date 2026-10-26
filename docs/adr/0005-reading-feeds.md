# ADR 0005 — フィードは外部の curl で取り、XML は Core の自前の字句解析で読み、出だしは段落と文で切る

- 状態: 受理
- 日付: 2026-10-26
- Issue: #3
- 影響する規則: ARC-001 / ARC-003 / ARC-006 / ARC-008 / ARC-010 / SWF-005 / SWF-014 / CNF-023 / FR-07 / FR-08 / FR-26

## 文脈

上流指示の進め方の 1 段目は「フィードを取って、見出しと出だしを素のまま一覧で出せる」。Foundation はどの target からも使わない（SWF-014）ので、
`URLSession` も `XMLParser` も無い。HTTP と XML をどう扱うかを決める必要がある。

実際のフィードを確かめた（2026-10-26）:

| フィード | 形式 | 様子 |
| --- | --- | --- |
| BBC World・NPR News・The Guardian World | RSS 2.0 | 今日の記事が入っている。Guardian の要約欄は複数の `<p>` で、最初の段落は句点で終わらない。U+2060（単語結合子）・U+200B（ゼロ幅スペース）が混じる |
| NHK 旧 URL `www3.nhk.or.jp/rss/news/cat0.xml` | RSS 2.0 | 応答は 200 だが **2026-08-08 で更新が止まっている**（Last-Modified も 8 月 8 日）。保持期間 1 週間では全部捨てられる |
| NHK 公開 URL `www.nhk.or.jp/rss/news/cat0.xml` | RSS 2.0 | `news.web.nhk/...` へ 301 で転送され、今日の記事が入っている。要約欄の終わりは NHK が `…` で切っている |
| 朝日新聞 `newsheadlines.rdf` | RSS 1.0（RDF） | 今日の記事。`dc:date` |

## 決定

1. **HTTP は外部の `curl` を子プロセスで呼ぶ**（Host の `FetchCommand`・`ChildProcess`）。引数は `--silent --show-error --location --max-redirs 5 --max-time 20 --compressed --proto =http,https --proto-redir =http,https --user-agent <名乗り> --dump-header -`。
   名乗りは `nene-wire (+https://github.com/hideyukiMORI/nene-wire)`（提供元が誰の取得か分かるように。当初は `nene-wire/0.1` と版を入れていたが、版の入力を 1 か所にするため v0.2.0 で外した・ADR 0008）。標準出力にヘッダの列とボディが続けて出る
2. **curl の結果の解釈は Core の `FetchInterpreter` の 1 か所**: 終了コードが 0 でなければ curl の失敗（標準エラーの 1 行目を理由にする）、
   転送を含むヘッダの塊の**最後**が最終の応答（`HTTPResponse`）、304 は更新なし、200 以外は状態の失敗、200 ならボディをフィードとして読む
3. **XML は Core の自前の字句解析**（`MarkupScanner`）で、開きタグ・閉じタグ・文字列の出来事にする。処理命令・コメント・文書型宣言は読み飛ばし、CDATA の中身はそのまま。
   妥当性（タグの対応・名前空間）は検査せず、壊れた入力でも止まらずに読めたところまでを返す。XML 宣言の文字コードが UTF-8 以外なら拒む（UTF-8 だけを読む）
4. **フィードの解析は `FeedParser` の 1 か所**: 根の要素（`rss` / `RDF` / `feed`）で形式を決め、記事の要素（`item` / `entry`）の**直下の子**だけを拾う（`media:title` を見出しと取り違えない）。
   見出しは `title`、リンクは RSS は `link` の中身・Atom は `rel` が無いか `alternate` の `href`、要約は `description` / `summary`（空なら `content` / `content:encoded`）、
   日付は `published` を優先し、無ければ `pubDate` / `dc:date` / `updated`、識別子は `guid` / `id`（無ければリンク）
5. **要約欄の HTML の除去は `PlainText` の 1 か所**: タグを除き、もう 1 段の文字参照を解決し、空白をまとめる。段落の区切りのタグ（`p` `br` `li` `div` `h1`〜`h6` など）は段落の切れ目にし、
   **書式文字（Unicode の Cf）は除く**（幅 0 の文字は端末の桁を狂わせる・FR-04）
6. **出だしは `Lede` の 1 か所**: 段落ごとに文に分け（`。` `！` `？` の直後、`.` `!` `?` は直後が空白か終わり）、先頭から 3 文まで・合計 250 文字以内で足していく。
   日本語の句点で終わる文の後ろは空白なしでつなぐ。最初の 1 文だけで 250 文字を超えるなら 249 文字で切って `…` を付ける。要約が空か見出しと同じ（見出しに含まれる）なら出だしは無い
7. 日付は RFC 822（RSS）と ISO 8601（Atom・RSS 1.0）を読み、UTC の秒（`Timestamp`）にする。暦の計算は Howard Hinnant の days_from_civil / civil_from_days の式。文字にする正本の形は ISO 8601 の UTC（`Timestamp.iso8601`）
8. **最初のフィード（FR-26）は NHK・BBC World・NPR News・The Guardian World の 4 本**。NHK は公開 URL（転送をたどる）を登録する。NHK が場所をまた移しても、公開 URL の転送で追いつけるため
9. 合成ルートの `nene-wire --list` が 4 本を順に取り、フィードごとに見出し・出だし・リンク・公開時刻を標準出力に出す（ARC-006 の「合成ルートが出してよいもの」に一覧を足す）。
   取れなかったフィードは理由を 1 行出して続ける。curl に渡す環境変数（`PATH`・プロキシ・証明書の場所など）は合成ルートが読んで渡す（ARC-007）
10. 子プロセスは、親のシグナルのマスクと「無視」の設定を受け継がないよう、マスクを空にし、SIGTERM・SIGINT・SIGHUP・SIGQUIT・SIGPIPE を既定の動作に戻して起動する
    （テストの実行環境が SIGTERM を塞いでいて、`kill -TERM` した子が終わらなかった。取得や翻訳の子を止められないと困る）
11. 依存グラフの正本の合成ルートの行は、ADR 0004 で承認した 4 つのうち Package.swift にあるもの（Core・Host）だけを書く。Render と Terminal は手順 2 で足す

## 強制

- テスト（`make check` の新しい `test` 段・`swift test`）: 手で作った RSS 2.0 / RSS 1.0 / Atom の解析・HTML のページと Shift_JIS の拒否・文字参照・段落と書式文字・
  出だしの 3 文と 250 文字と日本語のつなぎと「見出しと同じなら無し」・日付の 2 つの形・URL の検証・転送を含む応答・curl の結果の読み替え・
  子プロセス（標準出力・標準エラー・終了コード・渡した環境だけ・大きな出力・シグナル・見つからない実行ファイル）
- **active**（QLT-001 の一部）: 証明 P48（テストの期待値を 1 つ変えると `make check` の `test` 段が落ちる）
- CNF-023: `posix_spawnp` は Host の `ChildProcess` だけ
- テストの XML は手で作ったもので、実際の記事をリポジトリに入れない（REQUIREMENTS の Q6）

## 結果

- 実行（2026-10-26）: `nene-wire --list` で NHK 7 件・BBC World 32 件・NPR News 10 件・The Guardian World 45 件が出た。書式文字は 0
- 失うもの: `curl` が入っていない環境では取得できない（Ubuntu には標準で入っている。入っていなければ理由を 1 行出す）。UTF-8 以外のフィードは読めない
- 条件付きの取得（`If-None-Match` / `If-Modified-Since`）・再挑戦の間隔・裏での取得は手順 4 で、この ADR の `FetchInterpreter` と `FetchCommand` を広げる

## 却下した選択肢

| 選択肢 | 却下の理由 |
| --- | --- |
| Foundation の `URLSession` / `XMLParser` | どの target からも禁止（SWF-014）。静的リンクの配布物では FoundationNetworking が libcurl などを連れてくる |
| libcurl を Swift から直接呼ぶ（C のモジュールとして） | 外部依存を足すことになる（ADR・許可リスト・規約の表の 3 点）。curl のコマンドなら子プロセスとして閉じ込められ、Host の外へ漏れない |
| ソケットと TLS を自前で書く | 証明書の検証を自前で持つことになる。安全でない |
| XML の完全な解析器（名前空間・妥当性）を書く | フィードを読むのに要らない。壊れたフィードでも読めたところまで出すほうが「止まらない」（FR-02）に合う |
| 要約欄を文字数だけで切る | 句点で終わらないリード文と本文が 1 つにつながり、途中で切れた（Guardian で実際に起きた） |
| NHK の旧 URL（`www3.nhk.or.jp`）を登録する | 応答は返るが更新が止まっている（「取得できる」の確認が応答の有無だけでは足りない例） |

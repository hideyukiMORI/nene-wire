# 用語集 — NeNe Wire

> Status: normative（規範）/ 2026-10-26 初版
> ここに載っている語は、コード・ドキュメント・Issue で**同じ意味**で使う。同義語を発明しない。

| 語 | 意味 | 型／場所 |
| --- | --- | --- |
| 結果（outcome） | 期待される成功・失敗を表す閉じた型 | `*Outcome` |
| 拒否理由（rejection / failure） | 結果に添える閉じた理由の集合 | `*Rejection` / `*Failure` |
| 合成ルート | 依存を結ぶ唯一の場所。時計・乱数・環境を読み、標準入出力と終了コードを持つ | `nene-wire`（executable target） |
| 描画（render） | 画面の状態から文字セルの格子という値を作ること。端末への書き出しは含まない | `NeNeWireRender` |
| 隔離区画 | 可変性を許した場所 | ARC-005 の表 |
| 規約検査（conformance） | NeNe Wire 固有の自作ゲート | `eng/conformance.py`（CNF-NNN） |
| waiver | 1 つの規則に対する期限付きの狭い例外 | `docs/waivers/WVR-NNNN-*.md` |
| 機械強制の状態 | active / planned / 不能 / 不採用 | `docs/QUALITY_GATES.md` の強制マトリクス |
| negative proof | ゲートが意図した規則で落ちることの実測 | `docs/quality/gate-proofs.md` |
| フィード（feed） | 記事を配る RSS / Atom の URL と、その名前・有効かどうか | `NeNeWireCore` |
| 取得（fetch） | フィードを取りに行くこと。更新が無ければ中身を取り直さない（条件付きの取得）。失敗したら間隔を空けて再挑戦する | 規則は Core・子プロセスは Host |
| 記事（article） | フィードの 1 項目。見出し・出だし・リンク・公開時刻・言語を持つ | `NeNeWireCore` |
| 見出し（headline） | 記事の題 | `NeNeWireCore` |
| 出だし（lede） | 記事の要約欄から HTML を取り除き、先頭の 2〜3 文・250 文字程度に切り出したもの。空か見出しと同じなら無い | `NeNeWireCore` |
| 言語の判定（language detection） | 記事の言語を文字の種類と語の出現から推定すること。判定できなければ「不明」 | `NeNeWireCore` |
| 表示の言語 | 記事を見せたい言語（既定は日本語）。記事の言語と違えば翻訳に回す | 設定 |
| 翻訳（translation） | 見出しと出だしを表示の言語に訳すこと。一度訳した結果は保存して訳し直さない | 規則は Core・手段は Host |
| 翻訳の手段（translator） | 翻訳を実際に行う外部の仕組み（ローカルの翻訳モデル・ローカル LLM など）。差し替えられる | `NeNeWireHost` |
| 未翻訳 | 翻訳できなかった記事の印。原文のまま表示し、あとで再挑戦する | `NeNeWireCore` |
| 保持期間 | 記事を手元に残す期間（1 週間程度）。過ぎたら捨てる | `NeNeWireCore` |
| 並べ方（rotation） | 表示の順番。フィードを順に巡回しながら新しいものから並べる。最後まで行ったら最新の内容で並べ直す | `NeNeWireCore` |
| 記事ブロック | 表示画面の中央の、枠で囲んだ 1 件分の領域 | `NeNeWireRender` |
| 演出（effect） | 枠・記号から確定する見出し・タイプライター・浮かび上がり・ノイズ・走査線・文字の雨・ブートログ。経過時間と乱数の種から格子を作る | `NeNeWireRender` |
| 帯（strip） | NeNe Wire が描く場所。端末の幅いっぱい・高さ 15 行で、起動したら画面を消して最上部に描く（ADR 0006・0007） | `StripRenderer` |
| メッセージの行（message line） | 帯の下から 2 行目。取得の様子（取得中・件数と新着・更新なし・失敗と取り直すまで）を 1 行で出す | `StripLayout.drawMessage` |
| DATA の窓 | 帯の右の窓。フィードごとの様子を 1 行ずつ出す | `DataWindow` |
| 演出の時計（motion） | 記事を見せ始めてからの時間・起動してからの時間・記事ごとの種。演出はこれだけから決まる | `Motion`・`Choreography` |
| くるくる確定（spin） | 文字が記号のくるくるを経て正しい文字に止まる演出。止まり方は 1 文字ずつ・左から・ばらばらの 3 種 | `SpinEffect` |
| 電脳ノイズ（glitch） | 静止中に一瞬だけ信号が乱れる演出 | `GlitchEffect` |
| 緊急傍受（intercept） | 速報が割り込む前の警告の演出 | `InterceptEffect` |
| 速報（breaking） | 取り直して新しく現れた記事。次の 1 件に割り込み、受信の行に印が付く | `Rotation` |
| 設定画面（settings） | `s` で開く、フィードの一覧と表示の設定を直す画面。帯と同じ 15 行 | `SettingsEditor`（規則）・`SettingsRenderer`（描画） |
| 下書き（draft） | 設定画面で直している、まだ保存していない設定 | `SettingsEditor.settings` |
| 状態の行（status line） | 帯の最下行。何件目か・ネット・翻訳・取得の失敗 | `StripLayout` |
| 全角の幅（cell width） | 文字が端末で占める桁数。Unicode の East Asian Width の W・F は 2 桁、曖昧（A）は 1 桁 | `CellWidth`・`EastAsianWidth`（生成物） |
| 表示画面・設定画面 | 画面は 2 つ。表示画面は起動直後から、設定画面は表示画面から開く | `NeNeWireRender` |
| セル格子 | 端末の 1 画面分の文字セルの 2 次元配列。Render が作り、Terminal が差分で書く | `NeNeWireRender` |
| 全角の幅 | 1 文字が端末で何桁を占めるか（1 か 2）。Unicode の East Asian Width から決める | `NeNeWireRender` |
| 子プロセス | 取得や翻訳のために起動する外部のプログラム。表示を待たせないよう、ループは出力をブロックせずに待つ | `NeNeWireHost` |

## 使ってはいけない語

`Manager` / `Helper` / `Util` / `Utils` / `Common` を型名の語尾に使わない（SWF-010）。
役割を語る名前が思いつかないときは、その型が 2 つの責務を持っている可能性が高い。

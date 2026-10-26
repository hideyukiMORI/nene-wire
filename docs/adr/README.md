# アーキテクチャ決定記録（ADR）

トレードオフのある判断を、**理由ごと**残す場所。正本ドキュメントが「いま何が規範か」を書くのに対し、
ADR は「なぜそう決めたか」「何を却下したか」を書く。

## 書き方

- 連番 4 桁 ＋ kebab の題名: `NNNN-short-kebab-title.md`
- `0000-template.md` を複製して書く
- 状態は `提案` / `受理` / `却下` / `置換（→ NNNN）`
- **却下した選択肢を必ず書く。** 再提案は、その理由への反論から始めること
- 受理された ADR を後から書き換えない。変えるときは新しい ADR で置き換える
- 文脈は可能な限り実データ（コード・履歴・計測・コンパイラの出力）で裏を取る

## 一覧

| ADR | 題名 | 状態 |
| --- | --- | --- |
| [0001](0001-strictness-is-mechanically-enforced.md) | 厳格さは機械で強制する | 受理 |
| [0002](0002-swift-testing-only.md) | テスト枠組みは Swift Testing だけにする | 受理 |
| [0003](0003-port-gates-from-reversi.md) | ゲートと規約検査は NeNe Reversi の足場から移植し、証明はこのリポジトリで取り直す | 受理 |
| [0004](0004-target-split-and-dependency-graph.md) | target は Core・Render・Terminal・Host・合成ルートの 5 つに分け、外の世界に触れるのは Terminal と Host だけにする | 受理 |
| [0005](0005-reading-feeds.md) | フィードは外部の curl で取り、XML は Core の自前の字句解析で読み、出だしは段落と文で切る | 受理 |
| [0006](0006-full-width-strip-display.md) | 表示は端末の幅いっぱい・高さ 15 行の帯に描き、端末を占有しない。幅は Unicode の East Asian Width の表で数える | 受理（帯の置き方・割り付け・取得は 0007 で置き換え） |
| [0007](0007-always-on-ticker.md) | 常駐して裏で取り直し続け、取得の様子は帯の中（メッセージの行と DATA の窓）に出す。新しく現れた記事は速報として割り込む | 受理 |
| [0008](0008-release-pipeline-and-demo.md) | 版は Version.swift の 1 か所、配布物は 1 本のスクリプトで検査してから作る。画面写真は架空の記事で動く --demo で撮る | 受理 |
| [0009](0009-cyber-effects.md) | 演出は「時計と種」から格子を作る Render の純粋な関数にし、デザインのキャンバスの案をすべて入れる | 受理 |
| [0010](0010-argos-translate.md) | 翻訳は Argos Translate を torch 抜きで入れ、子プロセスでまとめて訳す。訳せなければ原文で流す | 受理 |
| [0011](0011-settings-screen.md) | 設定画面は帯と同じ 15 行に描き、編集の規則は Core の状態機械、保存は版付きの文字列にする | 受理 |
| [0012](0012-powershell-installer.md) | PowerShell からは install.ps1 で WSL の中に入れ、Windows 側には wsl.exe で起動する nene-wire.cmd だけを置く | 受理 |
| [0013](0013-translation-toggle.md) | 翻訳のオン／オフは設定の 1 項目にし、設定画面と帯の表示中の t の両方から切り替える | 受理 |

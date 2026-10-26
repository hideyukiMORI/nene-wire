# いまのタスク — NeNe Wire

> GitHub Issue が正。ここは要約であり、Markdown のチェックリストをタスク状態として扱わない。
> 更新は実測でだけ行う（「動くもの」は `make check` が通ったもの）。

## 段階

| 段階 | 状態 |
| --- | --- |
| Phase 0 言語の実測 | ✅ 2026-10-26（75 ケース・NeNe Reversi と全件一致・ADR 0001） |
| Phase 1 文書とゲートの足場 | ✅ 2026-10-26（Issue #1・ruleset 25851529） |
| Phase 2 negative proof | ✅ 2026-10-26（60 件すべて pass・GitHub 側 2 件・docs/quality/gate-proofs.md） |
| Phase 3-1 フィードを取って見出しと出だしを素のまま一覧 | ✅ 2026-10-26（Issue #3・ADR 0005） |
| Phase 3-2 表示画面で一件ずつ（幅 100%・高さ 15 行の帯・端末の復元を確実に） | ✅ 2026-10-26（Issue #5・ADR 0006） |
| Phase 3-2b 常駐して裏で取り直し、取得の様子を帯の中に（施主の指示で手順 4 の取得を前倒し） | ✅ 2026-10-26（Issue #7・#9・ADR 0007） |
| Phase 3-3 演出（全部入れる・Q13） | ✅ 2026-10-26（Issue #16・ADR 0009） |
| Phase 3-4 記事の保存（裏での取得は 3-2b で前倒し） | 🔲 別 Issue |
| Phase 3-5 翻訳（Argos Translate・Q5） | ✅ 2026-10-26（Issue #18・ADR 0010） |
| Phase 3-6 設定画面 | 🔄 Issue #23（ADR 0011） |
| Phase 4 公開（v0.1.0 ベータを施主の指示で前倒し・Q12） | ✅ 2026-10-26 v0.1.0（Issue #11・#14・ADR 0008） |

## 動くもの

- `make check`（道具の版・`swift build`・整形・lint・規約検査とその単体テスト・`swift test`・コミットの形）
- `nene-wire --list`: 最初の 4 本のフィードを取り、見出し・出だし・リンク・公開時刻を素のまま出す
- `nene-wire`: 端末の幅いっぱい・高さ 15 行の帯に常駐し、裏でフィードを 15 分おきに取り直しながら記事を 12 秒ごとに流す。新しく現れた記事は速報として割り込む。取得の様子はメッセージの行と DATA の窓に出す（`q` 終了・空白 一時停止・←→ 前後）。どの終わり方でも端末を戻す

## 公開

- v0.1.0（ベータ・2026-10-26）: タグ `v0.1.0` は `a4967fa`。配布物 `nene-wire-0.1.0-linux-x86_64.tar.gz` の SHA-256 は `c4ca1d6e2d0d40fbeecfa5a6a575bc23d84f2d77fa712a368af33d53b2eaf6ed`。
  再ダウンロードして照合し、`install.sh` を `curl … | bash` で通した。https://github.com/hideyukiMORI/nene-wire/releases/tag/v0.1.0

- v0.2.0（ベータ・2026-10-26・演出と翻訳）: タグ `v0.2.0` は `edebf35`。配布物 `nene-wire-0.2.0-linux-x86_64.tar.gz` の SHA-256 は `abd8d63daa84b312aa8405a2daea7911e195f943b244e3532b71938630b61e43`。
  再ダウンロードして照合し、`install.sh` を `curl … | bash` で通した。https://github.com/hideyukiMORI/nene-wire/releases/tag/v0.2.0

- `install.ps1`: PowerShell から WSL の中に入れ、`nene-wire.cmd` で PowerShell・cmd から起動（ADR 0012）

## 動かないもの

- 記事と訳の保存（起動し直すと一から取り直して訳し直す）

## 次の 1 手

設定画面（#23）を統合したら、手順 4 の記事と訳の保存、手順 3「演出」の Issue を立てる（デザインのキャンバスの形: 記号から確定する見出し・タイプライター・走査線・DATA の窓の文字の雨）。

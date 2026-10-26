# いまのタスク — NeNe Wire

> GitHub Issue が正。ここは要約であり、Markdown のチェックリストをタスク状態として扱わない。
> 更新は実測でだけ行う（「動くもの」は `make check` が通ったもの）。

## 段階

| 段階 | 状態 |
| --- | --- |
| Phase 0 言語の実測 | ✅ 2026-10-26（75 ケース・NeNe Reversi と全件一致・ADR 0001） |
| Phase 1 文書とゲートの足場 | ✅ 2026-10-26（Issue #1・ruleset 25851529） |
| Phase 2 negative proof | ✅ 2026-10-26（60 件すべて pass・GitHub 側 2 件・docs/quality/gate-proofs.md） |
| Phase 3-1 フィードを取って見出しと出だしを素のまま一覧 | 🔲 別 Issue |
| Phase 3-2 表示画面で一件ずつ（端末の復元を確実に） | 🔲 別 Issue |
| Phase 3-3 演出 | 🔲 別 Issue |
| Phase 3-4 取得を裏で・記事の保存 | 🔲 別 Issue |
| Phase 3-5 翻訳 | 🔲 別 Issue |
| Phase 3-6 設定画面 | 🔲 別 Issue |
| Phase 4 公開 | 🔲 別 Issue |

## 動くもの

- `make check`（道具の版・`swift build`・整形・lint・規約検査とその単体テスト・コミットの形）。target は 0 本で、製品コードは無い

## 動かないもの

- 製品そのもの

## 次の 1 手

Issue #1 を閉じたあと、Phase 3 の手順 1「フィードを取って、見出しと出だしを素のまま一覧で出す」の Issue を立てる。
RSS / Atom の解析は Core に自前で書く（Foundation を使わない）。取得は Host から外部の `curl` を子プロセスで呼ぶ。

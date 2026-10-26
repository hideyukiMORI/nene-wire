# コミットとリポジトリの規約 — NeNe Wire

> Status: normative（規範）/ 2026-10-26 初版
> 出典: NeNeCommander `docs/COMMIT_CONVENTIONS.md`（GIT-001〜004・`commit-msg` フックで機械強制）

変更の経路は一つである: Issue → 焦点を持つブランチ → 一貫したコミット → PR → 必須 check → squash merge → 同期した綺麗な `main`。

読み方（**active / planned / 不能 / 不採用**）は [ARCHITECTURE_CONSTITUTION.md](ARCHITECTURE_CONSTITUTION.md) 第 0 節と同じ。

---

### GIT-001 — すべての変更は 1 つの Issue から始まる

Issue には問題と根拠・意図する結果・影響する規則 ID とモジュール・受け入れ条件・検証の計画・**やらないこと**を書く。
読み取りだけの調査は Issue 無しでよい。リポジトリの初期化コミットだけが例外。

- 機械強制: **planned**（PR 本文の `Closes #N` は人が書く。PR 本文を見る検査は CI にしか置けず、CI にだけある検査は作らない）

### GIT-002 — ブランチ名は一つの形

```text
<type>/<issue番号>-<short-kebab-summary>
```

例: `feat/2-legal-move-generation`。`main` での直接開発・force push・既定ブランチの削除は禁止。

- 機械強制: **planned**（`main` の保護は ruleset が見る。ブランチ名の形を見る検査は無い）

### GIT-003 — コミットメッセージは一つの形

Conventional Commits を、この正確な形で書く。

```text
<type>(<scope>): <日本語の説明> (#<issue番号>)
```

- `type` は `feat` / `fix` / `docs` / `refactor` / `test` / `build` / `ci` / `chore` のいずれか
- `type`・`scope`（小文字・省略可）・`BREAKING CHANGE` 等の Conventional Commits の語は英語。**説明と本文は日本語**
- 件名は 100 文字以内。末尾に `(#N)` を必ず付ける。件名と本文の間は空行
- 互換性を壊す公開契約の変更は `:` の前に `!` を付け、フッタに `BREAKING CHANGE:` を書く
- 件名には「何を」ではなく**判断**を置く（例: `警告のエラー化は manifest に置き、コマンド行には書かない`）

- 機械強制: **active** → `.githooks/commit-msg` と `make commits`（`$(BASE)..HEAD` の全コミット）が同じ `eng/validate-commit-message.py` を呼ぶ

### GIT-004 — `main` への変更は PR の squash merge だけ

`main` に入る変更は PR を経た squash merge だけで、必須 check `check` が成功していなければならない。
PR には目的・変更の要約・使った正典経路・規則 ID・検証結果・waiver・残るリスク・`Closes #N` を書く（DEVELOPMENT_WORKFLOW 第 7 節）。
実装中とレビュー中は draft。Draft → Ready がフルゲートの要求である。

- 機械強制: **active** → ruleset（PR 必須・squash のみ・必須 check・force push と削除の禁止）。PR 本文の中身はレビュー事項

### GIT-005 — PR のタイトルは GIT-003 の件名と同じ形

squash merge の件名は PR のタイトルから作られる。**マージ時の件名が最後の穴**なので、PR のタイトルを GIT-003 の件名の形に揃える。

- 機械強制: **planned**（PR タイトルを見る検査は CI にしか置けない。いまは人が揃える）

---

## フックの導入

フックはリポジトリが所有する（`.githooks/`）。clone 直後に 1 回、次を実行する。

```bash
make bootstrap     # core.hooksPath=.githooks を設定し、道具の版を確かめる（SwiftLint を .tools/ に入れる）
```

`make bootstrap` はグローバルの git 設定を変えない。フックはコミットメッセージだけを見て、**フルゲートの代わりにならない**。

🔴 フックはローカルでしか動かず `--no-verify` で迂回できる。だから `make check` の `commits` 段が PR の全コミットを同じ検証器で見る。

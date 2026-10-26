# ADR 0008 — 版は Version.swift の 1 か所、配布物は 1 本のスクリプトで検査してから作る。画面写真は架空の記事で動く --demo で撮る

- 状態: 受理
- 日付: 2026-10-26
- Issue: #11
- 影響する規則: ARC-006 / QLT-014 / Q6 / Q7 / Q12

## 文脈

施主は「ベータ版をタグ切ってリリースして。インストールワンライナーとスクリーンショット、readme も gambit に合わせて」と言った（2026-10-26・REQUIREMENTS の Q12）。
兄弟の NeNe Reversi は v0.1.0 を、Gambit から移植した 1 本の公開スクリプト（Reversi の ADR 0013・QLT-014）で出した。

README の画面写真に実際のフィードの記事を写すと、記事の見出しと出だしをリポジトリに入れて再配布することになり、Q6（記事や翻訳結果をリポジトリに入れない）に反する。

## 決定

1. **版**: `Sources/nene-wire/Version.swift` の `Version.current` の 1 か所。`nene-wire --version` は `nene-wire <版>` の 1 行を出して終わる（ARC-006 で許す出力に足す）
2. **配布物**: NeNe Reversi の `eng/package-release.sh`（コミット dc418eb）を移植し、`make release TAG=v<版>` の 1 経路だけで作る（QLT-014）。
   `.release/build` で規約検査・release 構成のテスト・`--static-swift-stdlib` のビルドを通し、x86-64 の ELF・宣言外の動的依存（許すのは libc・libm・libstdc++・libgcc_s・ld-linux）・
   `--version` とタグ・同梱物（`nene-wire` `README.txt` `LICENSE`）を検査してから、再現可能な tar.gz と `SHA256SUMS` を作る
3. **install.sh**: Reversi と同じ形。最新の Release（または `NENE_WIRE_VERSION`）を落とし、`SHA256SUMS` で照合してから `~/.local/bin`（`NENE_WIRE_PREFIX`）に入れる。照合に落ちたら何も入れない
4. **`--demo`**: ネットを使わず、架空のフィード 4 本（NEON TIMES・GRID DAILY・PORT WIRE・ORBITAL NEWS）と架空の記事で帯を動かす。
   取得は本物と同じ `Fetcher` → `FetchSchedule` → `Rotation` の経路を通り、curl の代わりに筋書き（`DemoScript`）の結果を記録する。20 秒後に 1 本目へ新しい記事が届き、速報として割り込む。
   実在の媒体の名前は使わず、リンクは `example.com`。README の画面写真はこれで撮る
5. **公開**: squash 統合後の `main` から作り直し、`v<版>` のタグと同名の Release に添付し、再ダウンロードして照合する。公開は施主の確認を取ってから（Q7。今回は Q12 で施主が指示した）

## 強制

- **active** → `eng/package-release.sh`（QLT-014・証明 P67〜P70: 版と違うタグ・静的リンクを外す・同梱物を足す・`--version` を変える、のそれぞれで落ちる）
- `--demo` の見た目は実機で確かめた（2026-10-26・Windows Terminal・120×30）: 架空の 4 本が DATA の窓に出て、20 秒後に `速報` の印の付いた記事が割り込み、MSG の行に `新着 1` が出る

## 結果

- 利用者は 1 行で入れられ、照合に落ちれば何も入らない。Swift は要らない
- 画面写真に実際の記事が写らない。ネットの無い所でも見た目を試せる
- 失うもの: `--demo` は製品の中に架空の文面を持つ（合成ルートの `DemoScript` の 1 ファイルだけ）

## 却下した選択肢

| 選択肢 | 却下の理由 |
| --- | --- |
| 実際のフィードを写した画面写真を README に入れる | Q6 に反する（記事の見出しと出だしの再配布） |
| 画面写真を画像処理で作る（Render の格子から絵を起こす） | 実機の端末で動いている姿ではない。Gambit・Reversi の README は実機の写真 |
| 写真の記事を後から塗りつぶす | 何のアプリか伝わらない |
| 手元のファイルや別の URL をフィードとして読ませる起動オプション | 施主が言っていない機能が増える。設定画面（手順 6）で決める |

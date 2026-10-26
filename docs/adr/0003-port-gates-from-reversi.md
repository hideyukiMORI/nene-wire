# ADR 0003 — ゲートと規約検査は NeNe Reversi の足場から移植し、証明はこのリポジトリで取り直す

- 状態: 受理
- 日付: 2026-10-26
- Issue: #1
- 影響する規則: QLT-001 / QLT-007 / CNF-001〜CNF-023 / GIT-003

## 文脈

NeNe Reversi（https://github.com/hideyukiMORI/nene-reversi）と NeNe Gambit は、同じ施主・同じ MIT ライセンス・同じ厳格規約で作った兄弟のリポジトリである。
Reversi は Gambit のゲートを移植し、Phase 0 の実測で見つけた 7 つの穴を塞いだうえで、2026-10-26 に v0.1.0 を公開した。
NeNe Wire は端末に描き続けるツールという点で兄弟と同じ土台（単一ゲート・規約検査・端末の復元）を要るが、中身（ニュースの取得・翻訳・保存）は違う。

Reversi のゲートの最新版は製品の target に違反を仕込む形になっていて、target が 0 本の Phase 1 では動かない。
Reversi の Phase 1・2 を終えた時点（コミット `b3dac02`・製品コードの入る前）は、足場を置いて仕込む形で、いまの NeNe Wire と同じ段にある。

## 決定

Issue #1 で、NeNe Reversi のコミット `b3dac02` の木（`LICENSE` を除く）を写し、次のように変えた。

| このリポジトリのファイル | 変えたこと |
| --- | --- |
| `eng/measure-language.py` | 名前を合わせた（一時ディレクトリの接頭辞）。ケースは変えていない（75 ケースを測り直した・ADR 0001） |
| `eng/conformance.py` | CNF-023 を置き換えた: Reversi の「登録商標のゲーム名を書かない」は NeNe Wire に当てはまらないので消し、「外部プロセスを起動する API は `spawn=allowed` の target だけ」にした（ADR 0004）。依存グラフの正本に `spawn=allowed` の属性を足した |
| `eng/tests/test_conformance.py` | CNF-023 の正例・反例を新しい規則に合わせた。例の依存グラフに Host を足した |
| `eng/prove-gates.py` | 足場の target を NeNe Wire の依存グラフ（Core・Render・Terminal・Host・合成ルート）に合わせた。CNF-023 の証明を新しい規則に置き換えた |
| `Package.swift`・`Makefile`・`eng/*.sh`・`.github/`・`.githooks/`・`.swift-format`・`.swiftlint.yml` | 名前を合わせた。中身は変えていない |
| `docs/` の各文書・`CLAUDE.md`・`AGENTS.md`・`README.md` | 中身は NeNe Wire の要件と、このリポジトリの実測で書き直した |

持ってこなかったもの: リバーシのルール・探索・キャスト・テーマ（製品の中身）。端末と描画の土台・`eng/smoke-terminal.py`・`eng/package-release.sh`・`install.sh`
は Reversi の main の HEAD（`dc418eb`）から、使う PR で移植してこの表に足す。

**証明はすべてこのリポジトリで取り直した**（`python3 eng/prove-gates.py`・[gate-proofs.md](../quality/gate-proofs.md)）。Reversi の証明の結果は一つも写していない。
GitHub 側の証明（ruleset・draft の CI）もこのリポジトリの PR と run で取る。

## 強制

- **active**: 移植した検査はすべて、このリポジトリの証明が通ってから強制マトリクスで active にした（CNF-006 が証明行の無い active を拒否する）
- **不能**: 「移植元を理解して写したか」はレビュー事項である。この表は、次に誰かが Reversi の修正を取り込むときの照合元として置く

## 結果

- 4 回分の実測と事故（draft の CI のスキップ・SwiftPM の警告・静的バイナリが黙って規則を飛ばす・draft の本文の編集で必須 check が上書きされる）から生まれた検査と手順を、最初から持てる
- 失うもの: Reversi の検査器が直されても、このリポジトリには自動では入らない。検査器は別々に保守する

## 却下した選択肢

| 選択肢 | 却下の理由 |
| --- | --- |
| Reversi の main の HEAD を移植する | 製品の target に違反を仕込む形で、target が 0 本の足場では動かない。足場を置いて仕込む `b3dac02` の形を移植した |
| Gambit から移植する | Reversi が Gambit の検査の穴（CNF-013 ほか）を塞いだあとの形を写すほうが、同じ穴を写さずに済む |
| 検査器を共有のパッケージや submodule にする | 依存を足すことになり（CODING_RULES 第 5 節の 3 点が要る）、片方の都合の変更がもう片方のゲートを黙って変える。規約は製品ごとの「守るべきこと」を含む |
| Reversi の CNF-023（登録商標のゲーム名）を残す | NeNe Wire はリバーシを扱わない。何も守らない規則は置かない |
| Reversi の gate-proofs の結果を写す | 「設定が在ることは検査が効いている証明ではない」（ポリシー P-09）。このリポジトリの木で落ちるのを見ていない |

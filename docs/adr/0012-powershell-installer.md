# ADR 0012 — PowerShell からは install.ps1 で WSL の中に入れ、Windows 側には wsl.exe で起動する nene-wire.cmd だけを置く

- 状態: 受理
- 日付: 2026-10-26
- Issue: #25
- 影響する規則: FR-30 / QLT-014 / Q15

## 文脈

施主は WSL2 で入れたあと、PowerShell でも同じワンライナー（`curl … install.sh | bash`）を打った。PowerShell の `bash` は WSL の入口（`bash.exe`）なので、
スクリプトは WSL の中で動き、同じ `~/.local/bin` に入っただけで、PowerShell から `nene-wire` は使えなかった。施主は「PowerShell版もインストールコマンド工夫すればできる？」と聞き、
案 1（WSL の中に入れ、Windows 側に起動用のコマンドを置く）を選んだ（REQUIREMENTS の Q15）。動作環境は WSL2 の Ubuntu＋Windows Terminal のまま（FR-30）。

実測（2026-10-26）: PowerShell の窓（Windows Terminal）から `wsl.exe -e <nene-wire> --demo` で起動すると、帯・演出・翻訳が WSL のタブと同じに表示される。

## 決定

1. **`install.ps1`**（`irm https://raw.githubusercontent.com/hideyukiMORI/nene-wire/main/install.ps1 | iex`）: `wsl.exe` と WSL のディストリビューションがあるかを確かめ、
   WSL の中で `install.sh` を流す（照合してから入れる仕組みはそのまま・QLT-014 の配布物）。成功したら `%LOCALAPPDATA%\nene-wire\bin\nene-wire.cmd` を書き、そのフォルダをユーザーの PATH に足す
2. **`nene-wire.cmd`** の中身は `wsl.exe [-d <ディストリビューション>] --cd ~ -e .local/bin/nene-wire %*` の 1 行。PowerShell からも cmd からも `nene-wire` で起動できる。`--cd ~` で WSL のホームから始めるので、パスの展開にシェルが要らない
3. **失敗の仕方**: スクリプト全体を関数に包み、失敗は `return` で返す（`irm | iex` で `exit` すると窓が閉じる）。WSL の中のインストールが失敗したら、Windows 側には何も置かない
4. **選べること**（環境変数）: `NENE_WIRE_DISTRO`（既定のディストリビューション以外）・`NENE_WIRE_VERSION`（版）。`NENE_WIRE_PATH_SCOPE` はテストでユーザーの PATH を触らないためだけのもの
5. **ASCII だけで書く**: Windows PowerShell 5.1 は BOM の無いスクリプトを地域の文字コードで読む
6. **install.sh の案内**: `bash.exe` や `wsl -e` から流すとログインしていないシェルになり、Ubuntu が `~/.local/bin` を PATH に足す前なので「PATH にない」と出る。
   「Ubuntu はログインのときに足すので、新しい端末なら入っていることが多い」と書き添えた

## 強制

- 機械では見ていない（**planned**: `make check` は PowerShell を動かせない）。実機で確かめた（2026-10-26）:
  Windows PowerShell 5.1 と PowerShell 7.6.9 で `Get-Content -Raw install.ps1 | iex`（ディストリビューション Ubuntu-22.04・一時的な LOCALAPPDATA・PATH は Process だけ）→
  WSL の中に v0.2.0 が入り、`nene-wire.cmd` が書かれ、cmd からも PowerShell からも `nene-wire --version` → `nene-wire 0.2.0`。ユーザーの PATH は変わらなかった

## 結果

- PowerShell から 1 行で入り、PowerShell でも cmd でも `nene-wire` で起動できる。実体は 1 つ（WSL の中）
- 失うもの: Windows 側にファイルと PATH の項目が 1 つずつ増える（消し方を install.ps1 の頭と README に書いた）

## 却下した選択肢

| 選択肢 | 却下の理由 |
| --- | --- |
| Windows ネイティブ版を作る | 端末の制御・子プロセス・シグナル・配布物・翻訳をすべて作り直すことになり、動作環境（FR-30）を変える。施主は案 1 を選んだ |
| PowerShell の `$PROFILE` に関数を足す | PowerShell からしか使えない。cmd からも使えるよう `.cmd` にした |
| Windows 側に実行ファイルを複製する | Linux の実行ファイルなので Windows では動かない |

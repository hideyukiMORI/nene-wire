NeNe Wire @VERSION@ (Linux x86_64)
===================================

端末の最上部に、幅いっぱい・高さ 15 行の帯で、登録したニュースのフィードの見出しと出だしを流し続ける常駐型のニュースティッカー。
裏で 15 分おきにフィードを取り直し、新しく現れた記事は「速報」として割り込む。q を押すまで続く。

動作環境: WSL2 の Ubuntu（Windows Terminal）など、x86_64 の Linux で glibc 2.35 以上（Ubuntu 22.04 以降）。
フィードの取得に curl を使う。Swift は要らない（標準ライブラリを静的にリンクしてある）。

PowerShell から（WSL が入っていること）
  irm https://raw.githubusercontent.com/hideyukiMORI/nene-wire/main/install.ps1 | iex
  WSL の中に入れ、PowerShell と cmd から nene-wire で起動できるようにする。

ダウンロードと確認
------------------
1. GitHub の Release から次の 2 つを同じフォルダに落とす
     nene-wire-@VERSION@-linux-x86_64.tar.gz
     SHA256SUMS
2. 照合する（OK と出ること）
     sha256sum --check SHA256SUMS
3. 展開して起動する
     tar -xzf nene-wire-@VERSION@-linux-x86_64.tar.gz
     ./nene-wire-@VERSION@-linux-x86_64/nene-wire

キー
----
  q       終了（Ctrl+C でもよい。どう終わっても端末は元に戻る）
  空白    一時停止 / 再開
  → / ←   次の記事 / 前の記事
  t       翻訳のオン／オフ（保存する）
  s       設定画面（フィードの追加・有効／無効・直す・消す・試す、表示の言語・翻訳・時間・テーマ・文字の雨・原文の見出し）。
          設定画面の中は ↑↓ 選ぶ・Tab 欄を替える・w 保存・Esc 閉じる（キーの行に出る）。~/.config/nene-wire/settings.txt に保存する

起動オプション
--------------
  --demo      ネットを使わず、架空のフィードと記事で動かす（20 秒後に速報が 1 件届く）
  --list      フィードを取って、見出しと出だしを素のまま一覧で出して終わる
  --version   版を出して終わる

最初のフィード: NHK・BBC World・NPR News・The Guardian World（設定画面で足したり外したりできる）。
演出（記号から確定する見出し・電脳ノイズ・速報の割り込み・パラパラ落ちる切り替え など）が入っている。

翻訳: 英語の記事を日本語で出すには、翻訳の手段（Argos Translate）を入れる（Python 3 と pip が要る・470 MB ほど）。
     curl -fsSL https://raw.githubusercontent.com/hideyukiMORI/nene-wire/main/install-translator.sh | bash
入れていなければ原文のまま流し、英語の記事に「未翻訳」と出る。

記事と訳は ~/.local/state/nene-wire/archive.txt に保存する。次に起動するとそれですぐ流れ始め、同じ記事を二度訳さない。
7 日より古い記事は捨てる。

端末は 72x15 以上。

ライセンス: MIT（同梱の LICENSE）
ソース: https://github.com/hideyukiMORI/nene-wire

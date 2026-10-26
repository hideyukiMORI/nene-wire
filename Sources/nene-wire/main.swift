// 合成ルート（ARC-006）。時計・環境・起動オプションを読み（ARC-007）、Core・Render・Terminal・Host を組み立てる。
// 起動すると端末の幅いっぱい・高さ 15 行の帯に常駐し、裏でフィードを定期的に取り直しながら記事を一件ずつ流し続ける（ADR 0006・0007）。
// `--list` は取った記事を素のまま一覧で出す（ADR 0005）。`--demo` はネットを使わず架空の記事で動き、`--version` は版を出す（ADR 0008）。

import Glibc
import NeNeWireCore
import NeNeWireRender
import NeNeWireTerminal

let arguments = Array(CommandLine.arguments.dropFirst())
if arguments == ["--version"] {
    print("nene-wire \(Version.current)")
    exit(0)
}
guard arguments.isEmpty || arguments == ["--list"] || arguments == ["--demo"] else {
    Console.reportFailure(
        "nene-wire: 使い方は `nene-wire`（表示）・`nene-wire --demo`（架空の記事で試す）・`nene-wire --list`（一覧）・`nene-wire --version`")
    exit(2)
}

/// curl に渡す環境変数。プロキシと証明書の場所は利用者の環境に従う。
let passedNames: [String] = [
    "PATH", "HOME", "LANG", "LC_ALL", "http_proxy", "https_proxy", "HTTP_PROXY", "HTTPS_PROXY", "no_proxy", "NO_PROXY",
    "SSL_CERT_FILE", "SSL_CERT_DIR", "CURL_CA_BUNDLE",
]
let environment = passedNames.compactMap { name in getenv(name).map { "\(name)=\(String(cString: $0))" } }
let feeds = Feed.defaults.filter(\.enabled)

if arguments == ["--list"] {
    for line in Listing.lines(for: feeds, environment: environment) {
        print(line)
    }
    exit(0)
}

switch Console.open() {
case .opened:
    break
case .notATerminal:
    Console.reportFailure("nene-wire: 端末の中で起動してください（標準入力と標準出力が端末でない）")
    exit(1)
case .failed:
    Console.reportFailure("nene-wire: 端末の設定を読み書きできない")
    exit(1)
}

/// 24 ビットの色を使うか。`COLORTERM` が truecolor / 24bit を名乗るか、Windows Terminal（`WT_SESSION` がある）なら使い、
/// それ以外は 256 色へ落とす（NeNe Reversi の main.swift と同じ判定）。
let colors: ColorMode = {
    if getenv("WT_SESSION") != nil {
        return .trueColor
    }
    guard let raw = getenv("COLORTERM") else {
        return .palette256
    }
    return ["truecolor", "24bit"].contains(String(cString: raw)) ? .trueColor : .palette256
}()

/// 罫線の文字が 1 桁で描かれる端末だけ罫線の枠を使い、それ以外（2 桁・答えが無い）は ASCII の枠へ落とす（ADR 0006）。
let traits = TerminalTraits(frame: Console.columnsAdvanced(by: "─") == 1 ? .boxDrawing : .ascii, colors: colors)

let fetcher =
    arguments == ["--demo"]
    ? Fetcher(demo: DemoScript(), now: LocalTime.timestamp())
    : Fetcher(feeds: feeds, environment: environment, now: LocalTime.timestamp())
// 翻訳の手段（Argos Translate）は `install-translator.sh` が HOME の下に入れる。無ければ原文のまま流す（FR-29・ADR 0010）
let home = getenv("HOME").map { String(cString: $0) } ?? ""
let translator = Translator(library: Translator.library(home: home), environment: environment)
var viewer = Viewer(fetcher: fetcher, translator: translator, traits: traits, version: Version.current)
viewer.run()
Console.close()
exit(0)

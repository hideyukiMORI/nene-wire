// 合成ルート（ARC-006）。環境・起動オプションを読み（ARC-007）、Core と Host を組み立てる。
// いまは Phase 3 の手順 1: `--list` で最初のフィードを取り、見出しと出だしを素のまま一覧で出す（ADR 0005）。

import Glibc
import NeNeWireCore

let arguments = Array(CommandLine.arguments.dropFirst())
guard arguments == ["--list"] else {
    let line = "nene-wire: いまは --list だけ（フィードを取って一覧を出す）。表示画面は次の段で入る\n"
    _ = write(STDERR_FILENO, line, line.utf8.count)
    exit(2)
}

/// curl に渡す環境変数。プロキシと証明書の場所は利用者の環境に従う。
let passedNames: [String] = [
    "PATH", "HOME", "LANG", "LC_ALL", "http_proxy", "https_proxy", "HTTP_PROXY", "HTTPS_PROXY", "no_proxy", "NO_PROXY",
    "SSL_CERT_FILE", "SSL_CERT_DIR", "CURL_CA_BUNDLE",
]
let environment = passedNames.compactMap { name in getenv(name).map { "\(name)=\(String(cString: $0))" } }

for line in Listing.lines(for: Feed.defaults, environment: environment) {
    print(line)
}
exit(0)

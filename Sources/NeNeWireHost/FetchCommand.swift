import NeNeWireCore

/// フィードを取りに行く curl の呼び方（ADR 0005）。応答のヘッダとボディは `HTTPResponse` が読む。
public enum FetchCommand {
    /// 実行ファイルの名前（`PATH` から探す）。
    public static let executable = "curl"
    /// 名乗る名前。提供元が誰の取得か分かるように、リポジトリの URL を添える。
    public static let userAgent = "nene-wire/0.1 (+https://github.com/hideyukiMORI/nene-wire)"

    /// フィードを 1 本取る子プロセス。転送は 5 回まで・20 秒で打ち切る・圧縮を受け取る・http(s) 以外へは転送しない。
    /// 前の応答の手がかりがあれば条件付きで取る（更新が無ければ 304 で中身を取り直さない・FR-07）。
    public static func command(for url: FeedURL, validators: Validators, environment: [String]) -> ChildCommand {
        ChildCommand(
            executable: executable, arguments: arguments(for: url, validators: validators), environment: environment)
    }

    static func arguments(for url: FeedURL, validators: Validators) -> [String] {
        var conditions: [String] = []
        if let tag = validators.entityTag {
            conditions += ["--header", "If-None-Match: \(tag)"]
        }
        if let date = validators.lastModified {
            conditions += ["--header", "If-Modified-Since: \(date)"]
        }
        return conditions + [
            "--silent", "--show-error", "--location", "--max-redirs", "5", "--max-time", "20", "--compressed",
            "--proto", "=http,https", "--proto-redir", "=http,https", "--user-agent", userAgent, "--dump-header", "-",
            url.text,
        ]
    }
}

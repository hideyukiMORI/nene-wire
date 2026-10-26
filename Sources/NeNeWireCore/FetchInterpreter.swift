/// curl の終わり方と出力を、取得の結果に読み替える（ADR 0005）。curl の結果を解釈する経路はここ 1 つ（ARC-001）。
public enum FetchInterpreter {
    /// `exitCode` は curl の終了コード（シグナルで終わったなど、終了コードが無ければ nil）。
    public static func interpret(exitCode: Int32?, output: [UInt8], errorOutput: [UInt8]) -> FetchOutcome {
        guard let code = exitCode, code == 0 else {
            let message = String(decoding: errorOutput, as: UTF8.self).split(separator: "\n").first.map(String.init)
            return .failed(.transport(code: exitCode ?? -1, message: (message ?? "").trimmingSpaces))
        }
        switch HTTPResponse.parse(output) {
        case .rejected(let reason):
            return .failed(.unreadable(reason))
        case .parsed(let response):
            return interpret(response)
        }
    }

    private static func interpret(_ response: HTTPResponse) -> FetchOutcome {
        if response.status == 304 {
            return .notModified
        }
        guard response.status == 200 else {
            return .failed(.status(response.status))
        }
        switch FeedParser.parse(String(decoding: response.body, as: UTF8.self)) {
        case .rejected(let reason):
            return .failed(.notFeed(reason))
        case .parsed(let document):
            return .fetched(document, headers: response.headers)
        }
    }
}

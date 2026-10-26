import NeNeWireCore
import NeNeWireHost

/// `--list` の一覧（Phase 3 の手順 1・ADR 0005）。フィードを 1 本ずつ取り、見出し・出だし・リンク・公開時刻を素のまま並べる。
/// 取れなかったフィードは理由を 1 行出して続ける。
enum Listing {
    static func lines(for feeds: [Feed], environment: [String]) -> [String] {
        feeds.flatMap { feed in lines(for: feed, outcome: fetch(feed, environment: environment)) + [""] }
    }

    private static func fetch(_ feed: Feed, environment: [String]) -> FetchOutcome {
        switch ChildProcess.run(FetchCommand.command(for: feed.url, environment: environment)) {
        case .failedToStart(let code):
            return .failed(.transport(code: -1, message: "curl を起動できない（errno \(code)）"))
        case .finished(let result):
            return FetchInterpreter.interpret(
                exitCode: exitCode(result.termination), output: result.output, errorOutput: result.errorOutput)
        }
    }

    private static func exitCode(_ termination: ChildTermination) -> Int32? {
        switch termination {
        case .exited(let code):
            return code
        case .signaled:
            return nil
        }
    }

    private static func lines(for feed: Feed, outcome: FetchOutcome) -> [String] {
        switch outcome {
        case .notModified:
            return ["== \(feed.name) (\(feed.url.host)): 更新なし"]
        case .failed(let failure):
            return ["!! \(feed.name) (\(feed.url.host)): \(describe(failure))"]
        case .fetched(let document, _):
            let articles = document.items.compactMap { Article.from($0, feed: feed) }
            let header = "== \(feed.name) (\(feed.url.host)) \(document.format) \(articles.count) 件"
            return [header] + articles.flatMap(describe)
        }
    }

    private static func describe(_ article: Article) -> [String] {
        var lines = ["- " + article.headline]
        if let lede = article.lede {
            lines.append("  " + lede)
        }
        lines.append("  " + article.link)
        lines.append("  " + (article.published?.iso8601 ?? "（公開時刻なし）"))
        return lines
    }

    private static func describe(_ failure: FetchFailure) -> String {
        switch failure {
        case .transport(let code, let message):
            return "取得に失敗（curl \(code)）\(message)"
        case .status(let status):
            return "HTTP \(status)"
        case .unreadable:
            return "HTTP の応答として読めない"
        case .notFeed(.notFeed):
            return "フィード（RSS / Atom）ではない"
        case .notFeed(.unsupportedEncoding(let encoding)):
            return "文字コード \(encoding) は読めない（UTF-8 だけ）"
        }
    }
}

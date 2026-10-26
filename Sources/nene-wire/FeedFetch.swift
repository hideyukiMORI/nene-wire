import NeNeWireCore
import NeNeWireHost

/// フィードを 1 本取って結果を読む（Host の curl ＋ Core の解釈・ADR 0005）。`--list` と表示画面の両方がここを通る。
enum FeedFetch {
    /// 取った結果。
    static func outcome(_ feed: Feed, environment: [String]) -> FetchOutcome {
        switch ChildProcess.run(FetchCommand.command(for: feed.url, environment: environment)) {
        case .failedToStart(let code):
            return .failed(.transport(code: -1, message: "curl を起動できない（errno \(code)）"))
        case .finished(let result):
            return FetchInterpreter.interpret(
                exitCode: exitCode(result.termination), output: result.output, errorOutput: result.errorOutput)
        }
    }

    /// 取れなかった理由（1 行）。
    static func describe(_ failure: FetchFailure) -> String {
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

    private static func exitCode(_ termination: ChildTermination) -> Int32? {
        switch termination {
        case .exited(let code):
            return code
        case .signaled:
            return nil
        }
    }
}

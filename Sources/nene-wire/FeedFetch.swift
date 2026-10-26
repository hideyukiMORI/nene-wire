import NeNeWireCore
import NeNeWireHost

/// フィードを 1 本取って結果を読む（Host の curl ＋ Core の解釈・ADR 0005）。`--list` と表示画面の両方がここを通る。
enum FeedFetch {
    /// 取り終えるまで待った結果（`--list`）。
    static func outcome(_ feed: Feed, environment: [String]) -> FetchOutcome {
        switch ChildProcess.run(FetchCommand.command(for: feed.url, validators: .none, environment: environment)) {
        case .failedToStart(let code):
            return notStarted(code)
        case .finished(let result):
            return interpret(result)
        }
    }

    /// 待たずに取りに行く（表示のループ・ADR 0007）。
    static func start(_ feed: Feed, validators: Validators, environment: [String]) -> ChildStart {
        ChildProcess.start(FetchCommand.command(for: feed.url, validators: validators, environment: environment))
    }

    /// 終わった curl の結果を読む。
    static func interpret(_ result: ChildResult) -> FetchOutcome {
        FetchInterpreter.interpret(
            exitCode: exitCode(result.termination), output: result.output, errorOutput: result.errorOutput)
    }

    /// curl を起動できなかったとき。
    static func notStarted(_ code: Int32) -> FetchOutcome {
        .failed(.transport(code: -1, message: "curl を起動できない（errno \(code)）"))
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

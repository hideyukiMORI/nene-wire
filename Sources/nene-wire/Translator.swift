import Glibc
import NeNeWireCore
import NeNeWireHost
import NeNeWireRender

/// 裏での翻訳（FR-10・FR-13・FR-29・ADR 0010）。待ち行列（Core の `TranslationQueue`）から訳す記事を取り、Argos Translate を子プロセスで走らせ、
/// 表示のループが待つ間に出力を集める。翻訳の手段が無ければ一度も起動せず、原文のまま出す。
struct Translator {
    /// 1 回の翻訳の報告。
    struct Report {
        let articles: Int
        let outcome: TranslationOutcome
    }

    /// Argos の置き場（`install-translator.sh` が入れる所）。
    static func library(home: String) -> String {
        home + "/.local/share/nene-wire/argos/lib"
    }

    private(set) var queue = TranslationQueue.empty(target: LanguageGuess.japanese)
    /// 使えない理由。使えるなら nil。
    private(set) var problem: TranslatorProblem?
    private let library: String
    private let environment: [String]
    private var running: (jobs: [TranslationJob], child: RunningChild)?

    init(library: String, environment: [String], target: String) {
        self.library = library
        self.environment = environment
        queue = .empty(target: target)
        problem = access(library, F_OK) == 0 ? nil : .notInstalled
    }

    /// 表示の言語を替える（設定画面・FR-24）。訳の控えは捨てて、新しい言語で訳し直す。
    mutating func retarget(_ language: String, keeping articles: [Article]) {
        guard language != queue.target else {
            return
        }
        stop()
        queue = .empty(target: language)
        if problem == .missingModel {
            problem = nil
        }
        queue.enqueue(articles)
    }

    /// 表示のループが一緒に待つ読み口。
    var descriptors: [Int32] {
        running?.child.descriptors ?? []
    }

    /// 状態の行に出す様子。
    var status: TranslatorStatus {
        guard problem == nil else {
            return .off
        }
        let route = (running?.jobs.first?.source ?? LanguageGuess.english) + ">" + queue.target
        return .ready(route: route, pending: queue.pending, busy: running != nil)
    }

    /// 訳の控えのすべて（保存するため）。
    var translations: [String: Translation] {
        queue.translations
    }

    /// 保存した訳の控えを読み戻す。
    mutating func remember(_ saved: [String: Translation]) {
        queue.remember(saved)
    }

    /// 取れた記事を待ち行列に足し、巡りに無くなった記事の控えを捨てる。
    mutating func take(_ articles: [Article], keeping identifiers: Set<String>) {
        queue.enqueue(articles)
        queue.keep(only: identifiers)
    }

    /// 訳してあれば訳した記事、なければそのまま。
    func show(_ article: Article) -> Article {
        queue.translation(for: article.identifier).map(article.translated) ?? article
    }

    /// 表示の言語と違うのに、訳せていないか。
    func isUntranslated(_ article: Article) -> Bool {
        guard queue.translation(for: article.identifier) == nil,
            let source = LanguageGuess.of(article.headline + " " + (article.lede ?? ""))
        else {
            return false
        }
        return source != queue.target
    }

    /// 走っていなければ、訳してよい記事をまとめて訳しに行く。
    mutating func startIfDue(at now: Timestamp) -> Report? {
        guard problem == nil, running == nil else {
            return nil
        }
        let jobs = queue.nextBatch(at: now)
        guard let first = jobs.first else {
            return nil
        }
        let command = TranslateCommand.command(
            texts: jobs.flatMap(\.texts), route: (first.source, queue.target), library: library,
            environment: environment)
        switch ChildProcess.start(command) {
        case .running(let child):
            running = (jobs, child)
            return nil
        case .failedToStart:
            return settle(jobs, outcome: .unavailable(.notInstalled), at: now)
        }
    }

    /// 走っている翻訳の出力を読めるだけ読み、終わっていれば結果を返す。
    mutating func collect(at now: Timestamp) -> Report? {
        guard var current = running else {
            return nil
        }
        guard let result = current.child.pump() else {
            running = current
            return nil
        }
        running = nil
        let exit: Int32?
        switch result.termination {
        case .exited(let code):
            exit = code
        case .signaled:
            exit = nil
        }
        let count = current.jobs.reduce(0) { $0 + $1.texts.count }
        return settle(
            current.jobs, outcome: TranslationReply.interpret(exitCode: exit, output: result.output, count: count),
            at: now)
    }

    /// 終了するとき、走っている翻訳を止める。
    mutating func stop() {
        running?.child.stop()
        running = nil
    }

    private mutating func settle(_ jobs: [TranslationJob], outcome: TranslationOutcome, at now: Timestamp) -> Report {
        switch outcome {
        case .translated(let texts):
            queue.record(jobs, texts: texts)
        case .unavailable(.notInstalled), .unavailable(.missingModel):
            if case .unavailable(let reason) = outcome {
                problem = reason
            }
        case .unavailable(.crashed):
            queue.fail(jobs, at: now)
        }
        return Report(articles: jobs.count, outcome: outcome)
    }
}

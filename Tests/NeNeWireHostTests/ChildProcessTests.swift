import NeNeWireCore
import Testing

@testable import NeNeWireHost

/// 子プロセスの起動と出力の受け取り（ADR 0005）。本物の子プロセスを起動する（ネットにはつながない）。
struct ChildProcessTests {
    static func run(_ executable: String, _ arguments: [String], environment: [String] = []) -> ChildOutcome {
        ChildProcess.run(ChildCommand(executable: executable, arguments: arguments, environment: environment))
    }

    @Test func capturesStandardOutputAndTheExitCode() {
        #expect(
            Self.run("echo", ["hello"], environment: ["PATH=/usr/bin:/bin"])
                == .finished(ChildResult(termination: .exited(0), output: Array("hello\n".utf8), errorOutput: [])))
    }

    @Test func capturesStandardErrorAndANonZeroExit() {
        let outcome = Self.run("/bin/sh", ["-c", "echo out; echo err 1>&2; exit 3"])
        #expect(
            outcome
                == .finished(
                    ChildResult(termination: .exited(3), output: Array("out\n".utf8), errorOutput: Array("err\n".utf8)))
        )
    }

    @Test func passesOnlyTheGivenEnvironment() {
        let outcome = Self.run("/bin/sh", ["-c", "echo \"$NENE_PROBE:$HOME\""], environment: ["NENE_PROBE=yes"])
        #expect(
            outcome == .finished(ChildResult(termination: .exited(0), output: Array("yes:\n".utf8), errorOutput: [])))
    }

    @Test func drainsLargeOutputWithoutBlocking() {
        guard
            case .finished(let result) = Self.run(
                "/bin/sh", ["-c", "head -c 300000 /dev/zero; head -c 100000 /dev/zero 1>&2"])
        else {
            Issue.record("起動できない")
            return
        }
        #expect(result.output.count == 300_000)
        #expect(result.errorOutput.count == 100_000)
    }

    @Test func reportsSignalsAndMissingExecutables() {
        guard case .finished(let result) = Self.run("/bin/sh", ["-c", "kill -TERM $$"]) else {
            Issue.record("起動できない")
            return
        }
        #expect(result.termination == .signaled(15))
        #expect(Self.run("/nonexistent/nene-wire-probe", []) == .failedToStart(2))
    }

    @Test func fetchCommandNamesItselfAndAsksForHeaders() throws {
        let url = try #require(FeedURL.parse("https://example.com/feed"))
        let command = FetchCommand.command(for: url, validators: .none, environment: ["A=b"])
        #expect(command.executable == "curl")
        #expect(command.arguments.last == "https://example.com/feed")
        #expect(command.arguments.contains("--dump-header"))
        #expect(command.arguments.contains(FetchCommand.userAgent))
        #expect(command.environment == ["A=b"])
        #expect(!command.arguments.contains("--header"))
    }

    @Test func fetchCommandAsksConditionallyWhenItHasValidators() throws {
        let url = try #require(FeedURL.parse("https://example.com/feed"))
        let raw = "HTTP/1.1 200 OK\r\nETag: \"abc\"\r\nLast-Modified: Mon, 26 Oct 2026 04:00:00 GMT\r\n\r\n"
        guard case .parsed(let response) = HTTPResponse.parse(Array(raw.utf8)) else {
            Issue.record("応答を読めない")
            return
        }
        let headers = response.headers
        let arguments = FetchCommand.command(for: url, validators: Validators.from(headers), environment: []).arguments
        #expect(arguments.contains("If-None-Match: \"abc\""))
        #expect(arguments.contains("If-Modified-Since: Mon, 26 Oct 2026 04:00:00 GMT"))
    }

    @Test func runningChildCanBePumpedWithoutWaitingAndStopped() throws {
        guard
            case .running(var child) = ChildProcess.start(
                ChildCommand(executable: "/bin/sh", arguments: ["-c", "printf hi; sleep 0.2"], environment: []))
        else {
            Issue.record("起動できない")
            return
        }
        #expect(!child.descriptors.isEmpty)
        var result: ChildResult?
        #expect(child.pump() == nil)
        for _ in 0..<100 where result == nil {
            result = child.pump(waiting: 50)
        }
        #expect(result?.output == Array("hi".utf8))
        #expect(result?.termination == .exited(0))
        guard
            case .running(let sleeper) = ChildProcess.start(
                ChildCommand(executable: "/bin/sleep", arguments: ["30"], environment: []))
        else {
            Issue.record("起動できない")
            return
        }
        sleeper.stop()
    }
}

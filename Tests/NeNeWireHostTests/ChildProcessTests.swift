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
        let command = FetchCommand.command(for: url, environment: ["A=b"])
        #expect(command.executable == "curl")
        #expect(command.arguments.last == "https://example.com/feed")
        #expect(command.arguments.contains("--dump-header"))
        #expect(command.arguments.contains(FetchCommand.userAgent))
        #expect(command.environment == ["A=b"])
    }
}

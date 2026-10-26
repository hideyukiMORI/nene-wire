import Testing

@testable import NeNeWireHost

/// 文字列のファイルの読み書き（ADR 0011）。一時ディレクトリの中だけで行う。
struct TextFileTests {
    private static func temporaryDirectory() -> String? {
        guard
            case .finished(let result) = ChildProcess.run(
                ChildCommand(executable: "/bin/mktemp", arguments: ["-d"], environment: [])),
            result.termination == .exited(0)
        else {
            return nil
        }
        return String(decoding: result.output, as: UTF8.self).split(separator: "\n").first.map(String.init)
    }

    @Test func writtenTextReadsBackAndParentsAreMade() throws {
        let dir = try #require(Self.temporaryDirectory())
        defer { _ = ChildProcess.run(ChildCommand(executable: "/bin/rm", arguments: ["-rf", dir], environment: [])) }
        let path = dir + "/a/b/settings.txt"
        #expect(TextFile.read(path) == .missing)
        #expect(TextFile.write(path, text: "nene-wire-settings 1\n朝日\n") == .written)
        #expect(TextFile.read(path) == .text("nene-wire-settings 1\n朝日\n"))
        #expect(TextFile.write(path, text: "x\n") == .written)
        #expect(TextFile.read(path) == .text("x\n"))
        #expect(TextFile.read(path + ".tmp") == .missing)
    }

    @Test func unwritablePlacesFailWithAnErrno() {
        guard case .failed(let code) = TextFile.write("/proc/nene-wire/x.txt", text: "x") else {
            Issue.record("書けてしまった")
            return
        }
        #expect(code != 0)
    }
}

import NeNeWireCore
import Testing

@testable import NeNeWireHost

/// 翻訳の手段の呼び方（ADR 0010）。本物の python3 で台本を走らせ、Argos の代わりに一時的な偽のパッケージを読ませる（ネットもモデルも使わない）。
struct TranslateCommandTests {
    /// 偽の `argostranslate` を一時ディレクトリに作り、その置き場を返す。`pairs` は入っている言語の組。
    private static func fakeLibrary(pairs: String) -> String? {
        let script = """
            dir=$(mktemp -d) && mkdir "$dir/argostranslate" && touch "$dir/argostranslate/__init__.py" && cat > "$dir/argostranslate/translate.py" <<'PY'
            class Pair:
                def translate(self, text):
                    return '訳:' + text + '\\n  改行'
            class Language:
                def __init__(self, code):
                    self.code = code
                def get_translation(self, other):
                    return Pair() if (self.code, other.code) in [\(pairs)] else None
            def get_installed_languages():
                return [Language('en'), Language('ja')]
            PY
            echo "$dir"
            """
        guard
            case .finished(let result) = ChildProcess.run(
                ChildCommand(executable: "/bin/sh", arguments: ["-c", script], environment: [])),
            result.termination == .exited(0)
        else {
            return nil
        }
        return String(decoding: result.output, as: UTF8.self).split(separator: "\n").first.map(String.init)
    }

    /// 偽のパッケージを消す（mktemp が作った所だけ）。
    private static func remove(_ library: String) {
        guard library.hasPrefix("/tmp/") else {
            return
        }
        _ = ChildProcess.run(ChildCommand(executable: "/bin/rm", arguments: ["-rf", library], environment: []))
    }

    private static func translate(_ texts: [String], library: String) -> TranslationOutcome {
        let command = TranslateCommand.command(
            texts: texts, route: ("en", "ja"), library: library,
            environment: ["PATH=/usr/bin:/bin", "PYTHONPATH=/elsewhere"])
        guard case .finished(let result) = ChildProcess.run(command) else {
            return .unavailable(.notInstalled)
        }
        let code: Int32?
        switch result.termination {
        case .exited(let exit):
            code = exit
        case .signaled:
            code = nil
        }
        return TranslationReply.interpret(exitCode: code, output: result.output, count: texts.count)
    }

    @Test func commandUsesTheLibraryAndMiniSBD() {
        let command = TranslateCommand.command(
            texts: ["a", "b"], route: ("en", "ja"), library: "/lib/x", environment: ["PYTHONPATH=/old", "HOME=/h"])
        #expect(command.executable == "python3")
        #expect(Array(command.arguments.suffix(4)) == ["en", "ja", "a", "b"])
        #expect(command.environment.contains("PYTHONPATH=/lib/x"))
        #expect(!command.environment.contains("PYTHONPATH=/old"))
        #expect(command.environment.contains("ARGOS_CHUNK_TYPE=MINISBD"))
        #expect(command.environment.contains("HOME=/h"))
    }

    @Test func translationsComeBackOneLinePerTextInOrder() throws {
        let library = try #require(Self.fakeLibrary(pairs: "('en', 'ja')"))
        defer { Self.remove(library) }
        #expect(Self.translate(["one", "two\ttabs"], library: library) == .translated(["訳:one 改行", "訳:two tabs 改行"]))
    }

    @Test func aMissingPairOrAMissingPackageIsNamed() throws {
        let library = try #require(Self.fakeLibrary(pairs: "('fr', 'ja')"))
        defer { Self.remove(library) }
        #expect(Self.translate(["one"], library: library) == .unavailable(.missingModel))
        #expect(Self.translate(["one"], library: "/nonexistent/nene-wire") == .unavailable(.notInstalled))
    }
}

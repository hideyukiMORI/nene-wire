import NeNeWireCore
import NeNeWireTerminal

/// 開いている設定画面（FR-22〜25・ADR 0011）。編集の規則（Core の `SettingsEditor`）にキーを渡し、保存と「試す」を受け持つ。
struct SettingsSession {
    private(set) var editor: SettingsEditor
    private var tester: FeedTester
    private let file: SettingsFile

    init(settings: Settings, file: SettingsFile, environment: [String]) {
        editor = .opening(settings)
        tester = FeedTester(environment: environment)
        self.file = file
    }

    /// 「試す」の curl の読み口。
    var descriptors: [Int32] {
        tester.descriptors
    }

    /// 端末のキーを順に渡す。
    mutating func press(_ keys: [KeyPress]) -> SessionOutcome {
        var outcome = SessionOutcome.stay
        for key in keys {
            switch editor.handle(Self.editorKey(key)) {
            case .none:
                continue
            case .test(let feed):
                if let line = tester.start(feed) {
                    editor.reportTest(line)
                }
            case .save(let settings):
                if save(settings) {
                    outcome = .apply(settings)
                }
            case .saveAndClose(let settings):
                if save(settings) {
                    tester.stop()
                    return .applyAndClose(settings)
                }
            case .close:
                tester.stop()
                return .close
            }
        }
        return outcome
    }

    /// 「試す」が終わっていれば結果を出す。
    mutating func poll() {
        if let line = tester.collect() {
            editor.reportTest(line)
        }
    }

    mutating func stop() {
        tester.stop()
    }

    private mutating func save(_ settings: Settings) -> Bool {
        if let problem = file.save(settings) {
            editor.tell(problem)
            return false
        }
        editor.didSave()
        return true
    }

    private static func editorKey(_ key: KeyPress) -> EditorKey {
        switch key {
        case .up:
            return .up
        case .down:
            return .down
        case .left:
            return .left
        case .right:
            return .right
        case .tab:
            return .tab
        case .enter:
            return .enter
        case .escape:
            return .escape
        case .backspace:
            return .backspace
        case .character(let character):
            return .character(character)
        }
    }
}

/// 設定画面の編集の規則（FR-22〜25・ADR 0011）。キーを 1 つずつ受け取り、下書きを直し、合成ルートに頼むことを返す。端末もファイルも知らない。
///
/// 一覧の欄: ↑↓ 選ぶ・空白 有効／無効・a 足す・e 直す・d 消す（y で確定）・t 試す。設定の欄: ↑↓ 選ぶ・←→ 値を変える。
/// どちらでも Tab 欄を替える・w 保存・Esc 閉じる（保存していない変更があれば、w 保存して閉じる・x 捨てて閉じる・Esc 戻る）。
public struct SettingsEditor: Sendable, Hashable {
    private var draft: Settings
    private var saved: Settings
    private var focus: EditorPane = .feeds
    private var feedIndex = 0
    private var optionIndex = 0
    private var state: EditorMode = .browse
    private var noticeText: String?
    private var testText: String?

    private init(settings: Settings) {
        draft = settings
        saved = settings
    }

    /// いまの設定で開く。
    public static func opening(_ settings: Settings) -> SettingsEditor {
        SettingsEditor(settings: settings)
    }

    /// 下書き。
    public var settings: Settings {
        draft
    }

    /// 保存していない変更があるか。
    public var isDirty: Bool {
        draft != saved
    }

    public var pane: EditorPane {
        focus
    }

    public var mode: EditorMode {
        state
    }

    /// 選んでいるフィードの番号（一覧が空なら 0）。
    public var selectedFeed: Int {
        feedIndex
    }

    /// 選んでいる表示の項目。
    public var selectedOption: DisplayOption {
        DisplayOption.allCases[optionIndex]
    }

    /// 1 行の知らせ（入力の誤り・保存したなど）。
    public var notice: String? {
        noticeText
    }

    /// 最後に試したフィードの結果。
    public var testResult: String? {
        testText
    }

    /// 保存できた。下書きを保存済みにする。
    public mutating func didSave() {
        saved = draft
        noticeText = "保存した。次の記事から反映する"
    }

    /// 合成ルートからの知らせ（保存に失敗した・試している最中など）。
    public mutating func tell(_ text: String) {
        noticeText = text
    }

    /// フィードを試した結果。
    public mutating func reportTest(_ text: String) {
        testText = text
    }

    /// キーを 1 つ受け取る。
    public mutating func handle(_ key: EditorKey) -> EditorCommand {
        noticeText = nil
        switch state {
        case .browse:
            return browse(key)
        case .form(let form):
            typeInto(form, key: key)
            return .none
        case .confirmDelete:
            confirmDelete(key)
            return .none
        case .confirmClose:
            return confirmClose(key)
        }
    }

    private mutating func browse(_ key: EditorKey) -> EditorCommand {
        switch key {
        case .up, .down:
            move(key == .up ? -1 : 1)
        case .left, .right:
            if focus == .display {
                draft = Settings(
                    feeds: draft.feeds, display: draft.display.stepping(selectedOption, by: key == .left ? -1 : 1))
            }
        case .tab:
            focus = focus == .feeds ? .display : .feeds
        case .escape:
            if isDirty {
                state = .confirmClose
                return .none
            }
            return .close
        case .character(let character):
            return command(for: character)
        case .enter, .backspace:
            break
        }
        return .none
    }

    private mutating func command(for character: Character) -> EditorCommand {
        if character == "w" {
            return .save(draft)
        }
        guard focus == .feeds else {
            return .none
        }
        let feed = draft.feeds.indices.contains(feedIndex) ? draft.feeds[feedIndex] : nil
        if character == "a" {
            state = .form(FeedForm(name: "", url: "", field: .name, editing: nil))
        } else if character == " ", let feed {
            replace(feedIndex, with: Feed.make(name: feed.name, url: feed.url, enabled: !feed.enabled))
        } else if character == "e", let feed {
            state = .form(FeedForm(name: feed.name, url: feed.url.text, field: .name, editing: feedIndex))
        } else if character == "d", feed != nil {
            state = .confirmDelete
        } else if character == "t", let feed {
            testText = "試している  \(feed.name) …"
            return .test(feed)
        }
        return .none
    }

    private mutating func move(_ step: Int) {
        switch focus {
        case .feeds:
            feedIndex = min(max(feedIndex + step, 0), max(draft.feeds.count - 1, 0))
        case .display:
            optionIndex = min(max(optionIndex + step, 0), DisplayOption.allCases.count - 1)
        }
    }

    private mutating func typeInto(_ form: FeedForm, key: EditorKey) {
        switch key {
        case .character(let character) where character != "\t" && !character.isNewline:
            state = .form(form.typing { $0 + String(character) })
        case .backspace:
            state = .form(form.typing { String($0.dropLast()) })
        case .tab, .up, .down:
            state = .form(form.switched)
        case .enter:
            submit(form)
        case .escape:
            state = .browse
        case .left, .right, .character:
            break
        }
    }

    private mutating func submit(_ form: FeedForm) {
        guard let url = FeedURL.parse(form.url) else {
            noticeText = "URL は http:// か https:// で始まり、空白を含まないもの"
            return
        }
        let enabled = form.editing.map { draft.feeds[$0].enabled } ?? true
        guard let feed = Feed.make(name: form.name, url: url, enabled: enabled) else {
            noticeText = "名前が空"
            return
        }
        if let editing = form.editing {
            replace(editing, with: feed)
        } else {
            draft = Settings(feeds: draft.feeds + [feed], display: draft.display)
            feedIndex = draft.feeds.count - 1
        }
        state = .browse
    }

    private mutating func confirmDelete(_ key: EditorKey) {
        state = .browse
        guard key == .character("y"), draft.feeds.indices.contains(feedIndex) else {
            noticeText = "消さなかった"
            return
        }
        var feeds = draft.feeds
        let removed = feeds.remove(at: feedIndex)
        draft = Settings(feeds: feeds, display: draft.display)
        feedIndex = min(feedIndex, max(feeds.count - 1, 0))
        noticeText = "\(removed.name) を消した（w で保存）"
    }

    private mutating func confirmClose(_ key: EditorKey) -> EditorCommand {
        switch key {
        case .character("w"):
            return .saveAndClose(draft)
        case .character("x"):
            return .close
        case .escape:
            state = .browse
            return .none
        case .up, .down, .left, .right, .tab, .enter, .backspace, .character:
            return .none
        }
    }

    private mutating func replace(_ index: Int, with feed: Feed?) {
        guard let feed, draft.feeds.indices.contains(index) else {
            return
        }
        var feeds = draft.feeds
        feeds[index] = feed
        draft = Settings(feeds: feeds, display: draft.display)
    }
}

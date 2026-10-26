/// フィードを足す・直すときの入力（FR-23）。
public struct FeedForm: Sendable, Hashable {
    public let name: String
    public let url: String
    /// いま打っている欄。
    public let field: FormField
    /// 直しているフィードの番号。足すときは nil。
    public let editing: Int?

    init(name: String, url: String, field: FormField, editing: Int?) {
        self.name = name
        self.url = url
        self.field = field
        self.editing = editing
    }

    /// いまの欄に文字を足した・消したもの。
    func typing(_ change: (String) -> String) -> FeedForm {
        switch field {
        case .name:
            return FeedForm(name: change(name), url: url, field: field, editing: editing)
        case .url:
            return FeedForm(name: name, url: change(url), field: field, editing: editing)
        }
    }

    /// 欄を切り替えたもの。
    var switched: FeedForm {
        FeedForm(name: name, url: url, field: field == .name ? .url : .name, editing: editing)
    }
}

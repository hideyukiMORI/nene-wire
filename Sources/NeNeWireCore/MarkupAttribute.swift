/// 開きタグの属性 1 つ（名前と、文字参照を解決した値）。
public struct MarkupAttribute: Sendable, Hashable {
    public let name: String
    public let value: String
}

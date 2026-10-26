/// HTTP の応答ヘッダ 1 つ。名前は小文字にそろえる。
public struct HTTPHeader: Sendable, Hashable {
    public let name: String
    public let value: String
}

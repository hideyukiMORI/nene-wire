/// 条件付きの取得の手がかり（FR-07）。前の応答の `ETag` と `Last-Modified` を持ち、次の取得で `If-None-Match` と `If-Modified-Since` に返す。
public struct Validators: Sendable, Hashable {
    public let entityTag: String?
    public let lastModified: String?

    private init(entityTag: String?, lastModified: String?) {
        self.entityTag = entityTag
        self.lastModified = lastModified
    }

    /// 手がかりが無い（初回・失敗の後）。
    public static let none = Validators(entityTag: nil, lastModified: nil)

    /// 応答のヘッダから拾う（名前は小文字にそろっている）。空の値は無いものとする。
    public static func from(_ headers: [HTTPHeader]) -> Validators {
        func value(_ name: String) -> String? {
            headers.last { $0.name == name }.map(\.value).flatMap { $0.isEmpty ? nil : $0 }
        }
        return Validators(entityTag: value("etag"), lastModified: value("last-modified"))
    }
}

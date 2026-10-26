/// 保存の文字列を 1 行ずつ読んで組み立てる（ArchiveCodec の中だけで使う）。
struct ArchiveReader {
    private var feeds: [FeedSnapshot] = []
    private var translations: [String: [String: Translation]] = [:]

    var archive: Archive {
        Archive(feeds: feeds, translations: translations)
    }

    /// 1 行読む。読めなければ false。
    mutating func read(_ line: String) -> Bool {
        guard let space = line.firstIndex(of: " ") else {
            return false
        }
        let kind = line[..<space]
        let fields = line[line.index(after: space)...].split(separator: "\t", omittingEmptySubsequences: false)
        if kind == "feed", fields.count == 3 {
            feeds.append(
                FeedSnapshot(
                    url: ArchiveCodec.unescape(fields[0]),
                    validators: .make(entityTag: Self.optional(fields[1]), lastModified: Self.optional(fields[2])),
                    articles: []))
            return true
        }
        if kind == "article", fields.count == 7 {
            return article(fields)
        }
        if kind == "translation", fields.count == 4 {
            let target = ArchiveCodec.unescape(fields[0])
            let translation = Translation(headline: ArchiveCodec.unescape(fields[2]), lede: Self.optional(fields[3]))
            translations[target, default: [:]][ArchiveCodec.unescape(fields[1])] = translation
            return true
        }
        return false
    }

    private mutating func article(_ fields: [Substring]) -> Bool {
        let url = ArchiveCodec.unescape(fields[0])
        guard let index = feeds.lastIndex(where: { $0.url == url }) else {
            return false
        }
        let stamp = Self.optional(fields[2])
        let seconds = stamp.flatMap { Int64($0) }
        guard stamp == nil || seconds != nil else {
            return false
        }
        guard
            let article = Article.restored(
                ArticleFields(
                    feedName: ArchiveCodec.unescape(fields[6]), headline: ArchiveCodec.unescape(fields[3]),
                    lede: Self.optional(fields[4]), link: ArchiveCodec.unescape(fields[5]),
                    published: seconds.map(Timestamp.since1970), identifier: ArchiveCodec.unescape(fields[1])))
        else {
            return false
        }
        let feed = feeds[index]
        feeds[index] = FeedSnapshot(url: feed.url, validators: feed.validators, articles: feed.articles + [article])
        return true
    }

    /// `=` で始まれば中身、空なら nil。
    private static func optional(_ field: Substring) -> String? {
        field.hasPrefix("=") ? ArchiveCodec.unescape(field.dropFirst()) : nil
    }
}

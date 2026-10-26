/// RSS 2.0・RSS 1.0（RDF）・Atom の解析（FR-07・FR-08・ADR 0005）。フィードを解析する経路はここ 1 つ（ARC-001）。
///
/// 根の要素の名前で形式を決め、記事にあたる要素（`item` / `entry`）の**直下の子**だけを拾う（`media:title` などの入れ子を見出しと取り違えない）。
public struct FeedParser {
    private struct Draft {
        var title = ""
        var link = ""
        var summary = ""
        var fallbackSummary = ""
        var date = ""
        var identifier = ""
    }

    private let format: FeedFormat
    private var path: [String] = []
    private var itemDepth: Int?
    private var draft = Draft()
    private var buffer = ""
    private var channelTitle = ""
    private var items: [FeedItem] = []

    private init(format: FeedFormat) {
        self.format = format
    }

    /// 文字列（UTF-8 から読んだもの）を解析する。
    public static func parse(_ text: String) -> FeedParseOutcome {
        if let encoding = declaredEncoding(text), !["utf-8", "utf8"].contains(encoding.lowercased()) {
            return .rejected(.unsupportedEncoding(encoding))
        }
        let events = MarkupScanner.events(text)
        guard let format = rootFormat(events) else {
            return .rejected(.notFeed)
        }
        var parser = FeedParser(format: format)
        for event in events {
            parser.consume(event)
        }
        return .parsed(FeedDocument(title: parser.channelTitle.collapsingSpaces, format: format, items: parser.items))
    }

    private static func rootFormat(_ events: [MarkupEvent]) -> FeedFormat? {
        for event in events {
            guard case .open(let name, _) = event else {
                continue
            }
            let local = localName(name)
            if local == "rss" {
                return .rss2
            }
            if local == "RDF" {
                return .rss1
            }
            return local == "feed" ? .atom : nil
        }
        return nil
    }

    /// XML 宣言の `encoding="..."`。宣言が無いか書いていなければ nil（UTF-8 とみなす）。
    private static func declaredEncoding(_ text: String) -> String? {
        guard text.hasPrefix("<?xml"), let end = text.firstRange(of: "?>") else {
            return nil
        }
        let declaration = String(text[..<end.lowerBound])
        guard let key = declaration.firstRange(of: "encoding=") else {
            return nil
        }
        let rest = declaration[key.upperBound...].dropFirst()
        return String(rest.prefix { $0 != "\"" && $0 != "'" })
    }

    private static func localName(_ name: String) -> String {
        name.split(separator: ":").last.map(String.init) ?? name
    }

    private mutating func consume(_ event: MarkupEvent) {
        switch event {
        case .open(let name, let attributes):
            open(name, attributes)
        case .close(let name):
            close(name)
        case .text(let text):
            buffer += text
        }
    }

    private mutating func open(_ name: String, _ attributes: [MarkupAttribute]) {
        path.append(name)
        buffer = ""
        let local = Self.localName(name)
        if itemDepth == nil, local == "item" || local == "entry" {
            itemDepth = path.count
            draft = Draft()
        } else if let depth = itemDepth, path.count == depth + 1, format == .atom, local == "link" {
            let rel = attributes.first { $0.name == "rel" }?.value ?? "alternate"
            let href = attributes.first { $0.name == "href" }?.value ?? ""
            if rel == "alternate", draft.link.isEmpty {
                draft.link = href
            }
        }
    }

    private mutating func close(_ name: String) {
        defer {
            if !path.isEmpty {
                path.removeLast()
            }
            buffer = ""
        }
        if let depth = itemDepth {
            if path.count == depth {
                finishItem()
            } else if path.count == depth + 1 {
                record(name, buffer)
            }
        } else if Self.localName(name) == "title", channelTitle.isEmpty, path.count <= 3 {
            channelTitle = buffer
        }
    }

    /// 記事の直下の子の値を下書きに書く。文字列で分岐するので `switch` ではなく `if` で書く（SWF-002: 全捕捉を書かない）。
    private mutating func record(_ name: String, _ value: String) {
        if name == "title" {
            draft.title = value
        } else if name == "link", format != .atom {
            draft.link = value
        } else if name == "description" || name == "summary" {
            draft.summary = value
        } else if name == "content" || name == "content:encoded" {
            draft.fallbackSummary = value
        } else if ["pubDate", "dc:date", "published", "updated"].contains(name),
            draft.date.isEmpty || name == "published"
        {
            draft.date = value
        } else if name == "guid" || name == "id" {
            draft.identifier = value
        }
    }

    private mutating func finishItem() {
        itemDepth = nil
        let link = draft.link.trimmingSpaces
        let summary = draft.summary.trimmingSpaces.isEmpty ? draft.fallbackSummary : draft.summary
        let identifier = draft.identifier.trimmingSpaces.isEmpty ? link : draft.identifier.trimmingSpaces
        items.append(
            FeedItem(
                title: draft.title, link: link, summary: summary, published: DateText.parse(draft.date),
                identifier: identifier))
    }
}

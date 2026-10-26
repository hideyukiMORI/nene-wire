/// 記事と訳の保存形式（ARC-009・ADR 0014）。書くのも読むのもここ 1 か所。
///
/// ```text
/// nene-wire-archive 1
/// feed <URL><TAB><ETag?><TAB><Last-Modified?>
/// article <フィードの URL><TAB><識別子><TAB><公開の秒?><TAB><見出し><TAB><出だし?><TAB><リンク><TAB><フィード名>
/// translation <表示の言語><TAB><識別子><TAB><見出し><TAB><出だし?>
/// ```
/// 欄の中の `\` `TAB` 改行は `\\` `\t` `\n` `\r` に書き換える。`?` の付いた欄は、あれば `=` を頭に付け、無ければ空。
public enum ArchiveCodec {
    public static let header = "nene-wire-archive"
    public static let version = "1"

    public static func encode(_ archive: Archive) -> String {
        var lines = ["\(header) \(version)"]
        for feed in archive.feeds {
            lines.append(
                row(
                    "feed",
                    [escape(feed.url), optional(feed.validators.entityTag), optional(feed.validators.lastModified)]))
            for article in feed.articles {
                lines.append(
                    row(
                        "article",
                        [
                            escape(feed.url), escape(article.identifier),
                            optional(article.published.map { String($0.seconds) }),
                            escape(article.headline), optional(article.lede), escape(article.link),
                            escape(article.feedName),
                        ]))
            }
        }
        for (target, entries) in archive.translations.sorted(by: { $0.key < $1.key }) {
            for (identifier, translation) in entries.sorted(by: { $0.key < $1.key }) {
                lines.append(
                    row(
                        "translation",
                        [escape(target), escape(identifier), escape(translation.headline), optional(translation.lede)]))
            }
        }
        return lines.joined(separator: "\n") + "\n"
    }

    public static func decode(_ text: String) -> ArchiveOutcome {
        let lines = text.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline).map(String.init)
        guard let first = lines.first, first.hasPrefix(header + " ") else {
            return .rejected(.notArchive)
        }
        let stated = String(first.dropFirst(header.count + 1))
        guard stated == version else {
            return .rejected(.unknownVersion(stated))
        }
        var reader = ArchiveReader()
        for (offset, line) in lines.enumerated().dropFirst() where !line.isEmpty {
            guard reader.read(line) else {
                return .rejected(.malformed(line: offset + 1))
            }
        }
        return .parsed(reader.archive)
    }

    private static func row(_ kind: String, _ fields: [String]) -> String {
        kind + " " + fields.joined(separator: "\t")
    }

    static func escape(_ text: String) -> String {
        var out = ""
        // 文字での分岐は `if`（文字の `switch` には全捕捉が要り、CNF-013 が拒む）
        for character in text {
            if character == "\\" {
                out += "\\\\"
            } else if character == "\t" {
                out += "\\t"
            } else if character == "\n" {
                out += "\\n"
            } else if character == "\r" || character == "\r\n" {
                out += "\\r"
            } else {
                out.append(character)
            }
        }
        return out
    }

    static func unescape(_ text: Substring) -> String {
        var out = ""
        var pending = false
        for character in text {
            if pending {
                if character == "t" {
                    out += "\t"
                } else if character == "n" {
                    out += "\n"
                } else if character == "r" {
                    out += "\r"
                } else {
                    out.append(character)
                }
                pending = false
            } else if character == "\\" {
                pending = true
            } else {
                out.append(character)
            }
        }
        return out
    }

    private static func optional(_ value: String?) -> String {
        value.map { "=" + escape($0) } ?? ""
    }
}

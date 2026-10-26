/// 設定の保存形式（ARC-009・ADR 0011）。書くのも読むのもここ 1 か所。
///
/// ```text
/// nene-wire-settings 1
/// language ja
/// interval 12
/// theme PHOSPHOR
/// rain on
/// original on
/// feed on<TAB>NHK<TAB>https://www.nhk.or.jp/rss/news/cat0.xml
/// ```
/// 1 行目が見出しと版。表示の項目は 1 行 1 つで、無ければ既定。フィードは書いた順。空行と `#` で始まる行は読み飛ばす。
public enum SettingsCodec {
    public static let header = "nene-wire-settings"
    public static let version = "1"

    public static func encode(_ settings: Settings) -> String {
        let display = settings.display
        var lines = [
            "\(header) \(version)", "language \(display.language)", "interval \(display.interval)",
            "theme \(display.theme)", "rain \(display.rain ? "on" : "off")",
            "original \(display.original ? "on" : "off")",
        ]
        for feed in settings.feeds {
            lines.append("feed \(feed.enabled ? "on" : "off")\t\(feed.name)\t\(feed.url.text)")
        }
        return lines.joined(separator: "\n") + "\n"
    }

    public static func decode(_ text: String) -> SettingsOutcome {
        // "\r\n" は Swift では 1 つの Character なので、"\n" で割らずに改行の文字で割る
        let lines = text.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline).map(String.init)
        guard let first = lines.first, first.hasPrefix(header + " ") else {
            return .rejected(.notSettings)
        }
        let stated = String(first.dropFirst(header.count + 1))
        guard stated == version else {
            return .rejected(.unknownVersion(stated))
        }
        var values: [String: String] = [:]
        var feeds: [Feed] = []
        for (offset, line) in lines.enumerated().dropFirst() where !line.isEmpty && !line.hasPrefix("#") {
            if line.hasPrefix("feed ") {
                guard let feed = feed(from: line.dropFirst(5)) else {
                    return .rejected(.malformed(line: offset + 1))
                }
                feeds.append(feed)
                continue
            }
            let parts = line.split(separator: " ", maxSplits: 1).map(String.init)
            guard parts.count == 2, ["language", "interval", "theme", "rain", "original"].contains(parts[0]) else {
                return .rejected(.malformed(line: offset + 1))
            }
            values[parts[0]] = parts[1]
        }
        return display(from: values).map { .parsed(Settings(feeds: feeds, display: $0)) }
            ?? .rejected(.malformed(line: 1))
    }

    private static func feed(from rest: Substring) -> Feed? {
        let fields = rest.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
        guard fields.count == 3, fields[0] == "on" || fields[0] == "off", let url = FeedURL.parse(fields[2]) else {
            return nil
        }
        return Feed.make(name: fields[1], url: url, enabled: fields[0] == "on")
    }

    private static func display(from values: [String: String]) -> DisplaySettings? {
        let base = DisplaySettings.defaults
        for key in ["rain", "original"] {
            if let value = values[key], value != "on", value != "off" {
                return nil
            }
        }
        let rain = values["rain"].map { $0 == "on" } ?? base.rain
        let original = values["original"].map { $0 == "on" } ?? base.original
        let interval = values["interval"].map { Int($0) ?? -1 } ?? base.interval
        return DisplaySettings.make(
            language: values["language"] ?? base.language, interval: interval, theme: values["theme"] ?? base.theme,
            switches: (rain, original))
    }
}

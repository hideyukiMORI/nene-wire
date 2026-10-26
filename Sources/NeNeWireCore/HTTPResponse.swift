/// HTTP の応答（ADR 0005）。curl に `--dump-header -` を付けた標準出力（ヘッダの列のあとにボディ）を読む。
///
/// 転送（`--location`）や `100 Continue` があると、ヘッダの塊が複数並ぶ。最後の塊が最終の応答で、その後ろがボディ。
public struct HTTPResponse: Sendable, Hashable {
    public let status: Int
    public let headers: [HTTPHeader]
    public let body: [UInt8]

    private init(status: Int, headers: [HTTPHeader], body: [UInt8]) {
        self.status = status
        self.headers = headers
        self.body = body
    }

    /// curl の標準出力を読む。
    public static func parse(_ bytes: [UInt8]) -> HTTPResponseOutcome {
        var offset = 0
        var last: (Int, [HTTPHeader])?
        while startsWithStatusLine(bytes, at: offset), let end = blockEnd(bytes, from: offset) {
            let block = String(decoding: bytes[offset..<end.headerEnd], as: UTF8.self)
            if let parsed = headerBlock(block) {
                last = parsed
            }
            offset = end.bodyStart
        }
        guard let (status, headers) = last else {
            return .rejected(.noStatusLine)
        }
        return .parsed(HTTPResponse(status: status, headers: headers, body: Array(bytes[offset...])))
    }

    /// その名前のヘッダの値（大文字小文字を区別しない・最初のもの）。
    public func header(_ name: String) -> String? {
        let key = name.lowercased()
        return headers.first { $0.name == key }?.value
    }

    private static func startsWithStatusLine(_ bytes: [UInt8], at offset: Int) -> Bool {
        let prefix = Array("HTTP/".utf8)
        return offset + prefix.count <= bytes.count && Array(bytes[offset..<offset + prefix.count]) == prefix
    }

    /// ヘッダの塊の終わり（空行）。`\r\n\r\n` か `\n\n`。
    private static func blockEnd(_ bytes: [UInt8], from offset: Int) -> (headerEnd: Int, bodyStart: Int)? {
        var index = offset
        while index + 1 < bytes.count {
            if bytes[index] == 10, bytes[index + 1] == 10 {
                return (index, index + 2)
            }
            if index + 3 < bytes.count, bytes[index] == 13, bytes[index + 1] == 10, bytes[index + 2] == 13,
                bytes[index + 3] == 10
            {
                return (index, index + 4)
            }
            index += 1
        }
        return bytes.count > offset ? (bytes.count, bytes.count) : nil
    }

    private static func headerBlock(_ block: String) -> (Int, [HTTPHeader])? {
        let lines = block.split(whereSeparator: { $0 == "\n" || $0 == "\r\n" || $0 == "\r" }).map(String.init)
        guard let statusLine = lines.first else {
            return nil
        }
        let parts = statusLine.split(separator: " ")
        guard parts.count >= 2, let status = Int(parts[1]) else {
            return nil
        }
        let headers = lines.dropFirst().compactMap { line -> HTTPHeader? in
            guard let colon = line.firstIndex(of: ":") else {
                return nil
            }
            let name = String(line[..<colon]).trimmingSpaces.lowercased()
            return HTTPHeader(name: name, value: String(line[line.index(after: colon)...]).trimmingSpaces)
        }
        return (status, headers)
    }
}

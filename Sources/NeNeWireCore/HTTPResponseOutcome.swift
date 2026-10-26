/// curl の出力を読んだ結果。
public enum HTTPResponseOutcome: Sendable, Hashable {
    case parsed(HTTPResponse)
    case rejected(HTTPRejection)
}

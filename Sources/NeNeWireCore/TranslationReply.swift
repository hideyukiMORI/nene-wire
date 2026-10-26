/// 翻訳の手段の出力を読む（ADR 0010）。読むのはここ 1 か所。
///
/// 出力は 1 行 1 件で `<番号>\t<訳>`。使えないときは `ERR\t<理由>` の 1 行（理由は `import` か `model`）。
public enum TranslationReply {
    public static func interpret(exitCode: Int32?, output: [UInt8], count: Int) -> TranslationOutcome {
        let lines = String(decoding: output, as: UTF8.self).split(separator: "\n", omittingEmptySubsequences: true)
        if let error = lines.first(where: { $0.hasPrefix("ERR\t") }) {
            return .unavailable(error.hasSuffix("model") ? .missingModel : .notInstalled)
        }
        var texts = [String?](repeating: nil, count: count)
        for line in lines {
            guard let tab = line.firstIndex(of: "\t"), let index = Int(line[..<tab]), texts.indices.contains(index)
            else {
                continue
            }
            texts[index] = String(line[line.index(after: tab)...]).trimmingSpaces
        }
        guard exitCode == 0, texts.allSatisfy({ $0 != nil }) else {
            return .unavailable(.crashed(exitCode))
        }
        return .translated(texts.compactMap { $0 })
    }
}

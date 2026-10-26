import NeNeWireCore
import NeNeWireHost

/// 記事と訳の保存の置き場と読み書き（FR-11・ARC-009・ADR 0014）。
/// `$XDG_STATE_HOME/nene-wire/archive.txt`（無ければ `~/.local/state/nene-wire/archive.txt`）。
struct ArchiveFile {
    let path: String

    init(stateHome: String?, home: String) {
        let base = stateHome.flatMap { $0.isEmpty ? nil : $0 } ?? home + "/.local/state"
        path = base + "/nene-wire/archive.txt"
    }

    /// 起動するときに読む（7 日より古い記事は捨てる）。無ければ空。読めなければ空で始め、理由を返す（次に保存するときに書き直す）。
    func load(at now: Timestamp) -> (Archive, String?) {
        switch TextFile.read(path) {
        case .missing:
            return (.empty, nil)
        case .failed(let code):
            return (.empty, "保存した記事を読めない（errno \(code)）。取り直す")
        case .text(let text):
            switch ArchiveCodec.decode(text) {
            case .parsed(let archive):
                return (archive.pruned(at: now), nil)
            case .rejected(.notArchive):
                return (.empty, "保存した記事のファイルの形が違う。取り直す")
            case .rejected(.unknownVersion(let version)):
                return (.empty, "保存した記事の版 \(version) は読めない。取り直す")
            case .rejected(.malformed(let line)):
                return (.empty, "保存した記事の \(line) 行目が読めない。取り直す")
            }
        }
    }

    /// 保存する。書けなければ理由。
    func save(_ archive: Archive) -> String? {
        switch TextFile.write(path, text: ArchiveCodec.encode(archive)) {
        case .written:
            return nil
        case .failed(let code):
            return "記事を保存できなかった（errno \(code)）"
        }
    }
}

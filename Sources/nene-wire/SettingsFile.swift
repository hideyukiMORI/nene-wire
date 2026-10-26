import NeNeWireCore
import NeNeWireHost

/// 設定の置き場と読み書き（ARC-009・ADR 0011）。`$XDG_CONFIG_HOME/nene-wire/settings.txt`（無ければ `~/.config/nene-wire/settings.txt`）。
struct SettingsFile {
    let path: String

    init(configHome: String?, home: String) {
        let base = configHome.flatMap { $0.isEmpty ? nil : $0 } ?? home + "/.config"
        path = base + "/nene-wire/settings.txt"
    }

    /// 起動するときに読む。無ければ既定。読めなければ既定で起動し、その理由を返す（ファイルは書き換えない）。
    func load() -> (Settings, String?) {
        switch TextFile.read(path) {
        case .missing:
            return (.defaults, nil)
        case .failed(let code):
            return (.defaults, "設定を読めない（errno \(code)）。既定で起動した")
        case .text(let text):
            switch SettingsCodec.decode(text) {
            case .parsed(let settings):
                return (settings, nil)
            case .rejected(.notSettings):
                return (.defaults, "設定のファイルの形が違う。既定で起動した")
            case .rejected(.unknownVersion(let version)):
                return (.defaults, "設定の版 \(version) は読めない。既定で起動した")
            case .rejected(.malformed(let line)):
                return (.defaults, "設定の \(line) 行目が読めない。既定で起動した")
            }
        }
    }

    /// 保存する。書けなければ理由。
    func save(_ settings: Settings) -> String? {
        switch TextFile.write(path, text: SettingsCodec.encode(settings)) {
        case .written:
            return nil
        case .failed(let code):
            return "保存できなかった（errno \(code)）"
        }
    }
}

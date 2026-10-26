/// 設定の文字列を読んだ結果。
public enum SettingsOutcome: Sendable, Hashable {
    case parsed(Settings)
    case rejected(SettingsRejection)
}

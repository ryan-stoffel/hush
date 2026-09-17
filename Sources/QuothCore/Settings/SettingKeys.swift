import Foundation

/// Every setting the app persists, grouped by area. Add new keys here and to `allNames`.
public enum SettingKeys {
    // Cleanup
    public static let cleanupEnabled = SettingKey("cleanup.enabled", default: true)
    public static let spokenFormattingEnabled = SettingKey("cleanup.spokenFormatting.enabled", default: true)

    public static let allNames: [String] = [
        cleanupEnabled.name,
        spokenFormattingEnabled.name,
    ]
}

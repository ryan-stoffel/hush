import Foundation

/// Every setting the app persists, grouped by area. Add new keys here and to `allNames`.
public enum SettingKeys {
    // Cleanup
    public static let cleanupEnabled = SettingKey("cleanup.enabled", default: true)

    /// Stage ids in pipeline order. Each one gets its own enabled toggle.
    public static let cleanupStageIDs = ["spokenFormatting", LLMCleanupStep.stageID]
    public static let cleanupEditLevel = SettingKey("cleanup.editLevel", default: EditLevel.light)

    public static func stageEnabled(_ stageID: String) -> SettingKey<Bool> {
        SettingKey("cleanup.stage.\(stageID).enabled", default: true)
    }

    public static let allNames: [String] = [cleanupEnabled.name, cleanupEditLevel.name]
        + cleanupStageIDs.map { stageEnabled($0).name }
}

import Foundation

/// Every setting the app persists, grouped by area. Add new keys here and to `allNames`.
public enum SettingKeys {
    // Cleanup
    public static let cleanupEnabled = SettingKey("cleanup.enabled", default: true)

    /// Stage ids in pipeline order. Each one gets its own enabled toggle.
    public static let cleanupStageIDs = ["spokenFormatting", LLMCleanupStep.stageID]
    public static let cleanupEditLevel = SettingKey("cleanup.editLevel", default: EditLevel.format)

    // Local cleanup server (Ollama, LM Studio). Loopback only; no bearer token until the Keychain store lands.
    public static let localServerEnabled = SettingKey("cleanup.localServer.enabled", default: false)
    public static let localServerBaseURL = SettingKey(
        "cleanup.localServer.baseURL",
        default: "http://localhost:11434/v1"
    )
    public static let localServerModel = SettingKey("cleanup.localServer.model", default: "llama3.2")

    public static func stageEnabled(_ stageID: String) -> SettingKey<Bool> {
        SettingKey("cleanup.stage.\(stageID).enabled", default: true)
    }

    public static let allNames: [String] = [
        cleanupEnabled.name,
        cleanupEditLevel.name,
        localServerEnabled.name,
        localServerBaseURL.name,
        localServerModel.name,
    ] + cleanupStageIDs.map { stageEnabled($0).name }
}

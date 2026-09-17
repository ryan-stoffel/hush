import Foundation

public enum CleanupStages {
    /// The rule-based stages in the order the pipeline runs them. New stages are added here and to
    /// `SettingKeys.cleanupStageIDs`; docs/ARCHITECTURE.md documents the order.
    public static let standard: [any CleanupStage] = []
}

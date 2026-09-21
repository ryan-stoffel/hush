import XCTest
@testable import HushCore

private struct ClosureStage: CleanupStage {
    let id: String
    var displayName: String {
        id
    }

    var followsGlobalToggle = true
    let transform: @Sendable (String) throws -> String

    func process(_ text: String, context _: CleanupContext) throws -> String {
        try transform(text)
    }
}

private struct ClosureAsyncStep: AsyncCleanupStep {
    let id = "llm"
    let delay: TimeInterval
    let transform: @Sendable (String) throws -> String

    func process(_ text: String, context _: CleanupContext) async throws -> String {
        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        return try transform(text)
    }
}

private struct StageFailure: Error {}

final class CleanupPipelineTests: XCTestCase {
    private let upper = ClosureStage(id: "upper") { $0.uppercased() }
    private let exclaim = ClosureStage(id: "exclaim") { $0 + "!" }

    func testStagesRunInTheGivenOrderAndAreTraced() async {
        let pipeline = CleanupPipeline(stages: [exclaim, upper], settings: .inMemory())
        let result = await pipeline.run("hi", context: CleanupContext())
        XCTAssertEqual(result.finalText, "HI!")
        XCTAssertEqual(result.rawText, "hi")
        XCTAssertEqual(result.trace.map(\.stageID), ["exclaim", "upper"])
        XCTAssertEqual(result.trace.map(\.output), ["hi!", "HI!"])
    }

    func testDisabledStageIsSkipped() async {
        let settings = SettingsStore.inMemory()
        settings.set(upper.enabledKey, to: false)
        let result = await CleanupPipeline(stages: [upper, exclaim], settings: settings).run("hi", context: .init())
        XCTAssertEqual(result.finalText, "hi!")
        XCTAssertEqual(result.trace.map(\.stageID), ["exclaim"])
    }

    func testGlobalToggleBypassesEverythingExceptIndependentStages() async {
        let settings = SettingsStore.inMemory()
        settings.set(SettingKeys.cleanupEnabled, to: false)
        var independent = exclaim
        independent.followsGlobalToggle = false
        let step = ClosureAsyncStep(delay: 0) { $0 + "?" }
        let pipeline = CleanupPipeline(stages: [upper, independent], asyncStep: step, settings: settings)
        let result = await pipeline.run("hi", context: .init())
        XCTAssertEqual(result.finalText, "hi!")
    }

    func testThrowingStageIsSkippedAndRecorded() async {
        let broken = ClosureStage(id: "broken") { _ in throw StageFailure() }
        let result = await CleanupPipeline(stages: [upper, broken, exclaim], settings: .inMemory())
            .run("hi", context: .init())
        XCTAssertEqual(result.finalText, "HI!")
        XCTAssertNotNil(result.trace[1].errorDescription)
        XCTAssertEqual(result.trace[1].output, "HI")
    }

    func testBlankOutputFallsBackToTheRawTranscript() async {
        let eraser = ClosureStage(id: "eraser") { _ in "  \n" }
        let result = await CleanupPipeline(stages: [eraser], settings: .inMemory()).run("keep me", context: .init())
        XCTAssertEqual(result.finalText, "keep me")
    }

    func testAsyncStepRunsAfterTheRules() async {
        let step = ClosureAsyncStep(delay: 0) { $0 + " (polished)" }
        let result = await CleanupPipeline(stages: [upper], asyncStep: step, settings: .inMemory())
            .run("hi", context: .init())
        XCTAssertEqual(result.finalText, "HI (polished)")
    }

    func testSlowAsyncStepTimesOutAndKeepsTheRuleBasedResult() async {
        let step = ClosureAsyncStep(delay: 2) { _ in "never" }
        let pipeline = CleanupPipeline(stages: [upper], asyncStep: step, settings: .inMemory(), asyncTimeout: 0.05)
        let result = await pipeline.run("hi", context: .init())
        XCTAssertEqual(result.finalText, "HI")
        XCTAssertNotNil(result.trace.last?.errorDescription)
    }

    func testFailingAsyncStepKeepsTheRuleBasedResult() async {
        let step = ClosureAsyncStep(delay: 0) { _ in throw StageFailure() }
        let result = await CleanupPipeline(stages: [upper], asyncStep: step, settings: .inMemory())
            .run("hi", context: .init())
        XCTAssertEqual(result.finalText, "HI")
    }

    func testEveryStandardStageHasARegisteredToggle() {
        XCTAssertEqual(CleanupStages.standard.map(\.id), SettingKeys.cleanupStageIDs.filter { id in
            CleanupStages.standard.contains { $0.id == id }
        })
        for stage in CleanupStages.standard {
            XCTAssertTrue(SettingKeys.allNames.contains(stage.enabledKey.name), stage.id)
        }
    }
}

import HushCore
import XCTest
@testable import HushKit

@MainActor
private final class FakeOverlay: OverlayPresenting {
    var events: [String] = []

    func showListening() {
        events.append("listening")
    }

    func showTranscribing() {
        events.append("transcribing")
    }

    func showError(_ message: String, duration _: TimeInterval) {
        events.append("error:\(message)")
    }

    func hide() {
        events.append("hide")
    }

    func append(level _: Float) {}
}

private final class FakeCleanup: TextCleaning {
    var contexts: [CleanupContext] = []

    func run(_ rawText: String, context: CleanupContext) async -> CleanupResult {
        contexts.append(context)
        return CleanupResult(rawText: rawText, finalText: "cleaned: \(rawText)")
    }
}

@MainActor
final class DictationCoordinatorTests: XCTestCase {
    private var appState = AppState()
    private var hotkey = FakeHotkeyMonitor()
    private var capture = FakeAudioCapture()
    private var backend = FakeTranscriptionBackend()
    private var inserter = FakeTextInserter()
    private var permissions = FakePermissions.allGranted
    private var overlay = FakeOverlay()
    private var history = HistoryStore(persistence: InMemoryHistoryPersistence(), settings: .inMemory())

    override func setUp() async throws {
        history = HistoryStore(persistence: InMemoryHistoryPersistence(), settings: .inMemory())
        appState = AppState()
        hotkey = FakeHotkeyMonitor()
        capture = FakeAudioCapture()
        backend = FakeTranscriptionBackend(result: .success("Send it Wednesday."))
        inserter = FakeTextInserter()
        permissions = .allGranted
        overlay = FakeOverlay()
    }

    private func makeCoordinator(errorDuration: TimeInterval = 0.05) -> DictationCoordinator {
        let coordinator = DictationCoordinator(
            appState: appState,
            hotkey: hotkey,
            capture: capture,
            backend: backend,
            inserter: inserter,
            permissions: permissions,
            overlay: overlay,
            errorDuration: errorDuration,
            hotkeyRetryInterval: 0.05
        )
        coordinator.start()
        return coordinator
    }

    func testHappyPathInsertsAndReturnsToIdle() async {
        let coordinator = makeCoordinator()
        coordinator.handle(.pressed)
        XCTAssertEqual(appState.dictation, .listening)
        XCTAssertTrue(capture.isCapturing)

        coordinator.handle(.released)
        XCTAssertEqual(appState.dictation, .transcribing)
        await coordinator.pipelineTask?.value

        XCTAssertEqual(inserter.insertedTexts, ["Send it Wednesday."])
        XCTAssertEqual(appState.lastDictation, "Send it Wednesday.")
        XCTAssertEqual(backend.receivedOptions.first?.vocabulary, SpokenVocabulary.words)
        XCTAssertEqual(appState.dictation, .idle)
        XCTAssertEqual(overlay.events, ["listening", "transcribing", "hide"])
    }

    func testStartWiresTheHotkeyAndPreloadsTheModel() async {
        let coordinator = makeCoordinator()
        await coordinator.preloadTask?.value
        XCTAssertTrue(hotkey.isStarted)
        XCTAssertEqual(backend.prepareCount, 1)
    }

    func testCancelDiscardsTheAudio() {
        let coordinator = makeCoordinator()
        coordinator.handle(.pressed)
        coordinator.handle(.cancelled)
        XCTAssertEqual(capture.cancelCount, 1)
        XCTAssertEqual(appState.dictation, .idle)
        XCTAssertNil(coordinator.pipelineTask)
        XCTAssertTrue(backend.transcribedClips.isEmpty)
        XCTAssertEqual(overlay.events, ["listening", "hide"])
    }

    func testTooShortAudioEndsQuietly() async {
        capture.bufferToReturn = AudioClip(samples: Array(repeating: 0, count: 800))
        let coordinator = makeCoordinator()
        coordinator.handle(.pressed)
        coordinator.handle(.released)
        await coordinator.pipelineTask?.value
        XCTAssertEqual(appState.dictation, .idle)
        XCTAssertTrue(inserter.insertedTexts.isEmpty)
        XCTAssertFalse(overlay.events.contains { $0.hasPrefix("error") })
    }

    func testTranscriptionFailureShowsAnErrorThenRecovers() async throws {
        backend.setResult(.failure(.failed("boom")))
        let coordinator = makeCoordinator()
        coordinator.handle(.pressed)
        coordinator.handle(.released)
        await coordinator.pipelineTask?.value
        XCTAssertEqual(appState.dictation, .error("Transcription failed"))
        XCTAssertEqual(overlay.events.last, "error:Transcription failed")

        try await Task.sleep(nanoseconds: 300_000_000)
        XCTAssertEqual(appState.dictation, .idle)
    }

    func testInsertionFailureIsReported() async {
        inserter = FakeTextInserter(error: .accessibilityNotGranted)
        let coordinator = makeCoordinator()
        coordinator.handle(.pressed)
        coordinator.handle(.released)
        await coordinator.pipelineTask?.value
        XCTAssertEqual(appState.dictation, .error("Accessibility access is off"))
        XCTAssertNil(appState.lastDictation)
    }

    func testMissingPermissionIsNamedAndCaptureNeverStarts() {
        permissions = FakePermissions(
            statuses: [.microphone: .denied, .accessibility: .granted, .inputMonitoring: .granted],
            grantsOnRequest: false
        )
        let coordinator = makeCoordinator()
        coordinator.handle(.pressed)
        XCTAssertEqual(appState.dictation, .error("Microphone access is off"))
        XCTAssertEqual(capture.startCount, 0)
        XCTAssertEqual(appState.permissions[.microphone], .denied)
    }

    func testCaptureFailureIsReported() {
        capture.startError = AudioCaptureError.noInputDevice
        let coordinator = makeCoordinator()
        coordinator.handle(.pressed)
        XCTAssertEqual(appState.dictation, .error("No microphone found"))
    }

    func testSecondPressWhileTranscribingIsIgnored() async {
        let coordinator = makeCoordinator()
        coordinator.handle(.pressed)
        coordinator.handle(.released)
        coordinator.handle(.pressed)
        XCTAssertEqual(appState.dictation, .transcribing)
        XCTAssertEqual(capture.startCount, 1)
        await coordinator.pipelineTask?.value
        XCTAssertEqual(inserter.insertedTexts.count, 1)
    }

    func testANewDictationCanStartFromTheErrorState() {
        capture.startError = AudioCaptureError.noInputDevice
        let coordinator = makeCoordinator(errorDuration: 5)
        coordinator.handle(.pressed)
        capture.startError = nil
        coordinator.handle(.pressed)
        XCTAssertEqual(appState.dictation, .listening)
    }

    func testHotkeyStartFailureSurfacesInputMonitoring() {
        hotkey.startError = HotkeyError.eventTapUnavailable
        _ = makeCoordinator()
        XCTAssertEqual(appState.dictation, .error("Input Monitoring access is off"))
    }

    func testHotkeyStartIsRetriedUntilAccessIsGranted() async throws {
        hotkey.startError = HotkeyError.eventTapUnavailable
        let coordinator = makeCoordinator()
        XCTAssertFalse(hotkey.isStarted)
        hotkey.startError = nil
        try await Task.sleep(nanoseconds: 300_000_000)
        XCTAssertTrue(hotkey.isStarted)
        coordinator.stop()
    }

    func testMissingInputMonitoringDoesNotBlockAPressThatArrived() {
        permissions = FakePermissions(
            statuses: [.microphone: .granted, .accessibility: .granted, .inputMonitoring: .denied],
            grantsOnRequest: false
        )
        let coordinator = makeCoordinator()
        coordinator.handle(.pressed)
        XCTAssertEqual(appState.dictation, .listening)
    }

    func testCleanupRunsBetweenTranscriptionAndInsertion() async {
        let cleanup = FakeCleanup()
        let coordinator = DictationCoordinator(
            appState: appState,
            hotkey: hotkey,
            capture: capture,
            backend: backend,
            inserter: inserter,
            permissions: permissions,
            overlay: overlay,
            cleanup: cleanup,
            history: history,
            frontmostApp: { FrontmostApp(bundleIdentifier: "com.apple.TextEdit", name: "TextEdit") }
        )
        coordinator.start()
        coordinator.handle(.pressed)
        coordinator.handle(.released)
        await coordinator.pipelineTask?.value
        XCTAssertEqual(inserter.insertedTexts, ["cleaned: Send it Wednesday."])
        XCTAssertEqual(appState.lastDictation, "cleaned: Send it Wednesday.")
        XCTAssertEqual(cleanup.contexts, [CleanupContext(language: "en", bundleIdentifier: "com.apple.TextEdit")])
        XCTAssertEqual(overlay.events, ["listening", "transcribing", "hide"])

        let entry = history.entries.first
        XCTAssertEqual(history.entries.count, 1)
        XCTAssertEqual(entry?.rawTranscript, "Send it Wednesday.")
        XCTAssertEqual(entry?.cleanedText, "cleaned: Send it Wednesday.")
        XCTAssertEqual(entry?.appName, "TextEdit")
        XCTAssertEqual(entry?.insertionStrategy, .clipboardPaste)
        XCTAssertEqual(entry?.backendID, "fake")
        XCTAssertNil(entry?.cleanupNote)
    }

    func testFailedInsertionIsRecordedWithoutAStrategyAndCancelIsNot() async {
        inserter = FakeTextInserter(error: .accessibilityNotGranted)
        let coordinator = DictationCoordinator(
            appState: appState,
            hotkey: hotkey,
            capture: capture,
            backend: backend,
            inserter: inserter,
            permissions: permissions,
            overlay: overlay,
            history: history
        )
        coordinator.start()
        coordinator.handle(.pressed)
        coordinator.handle(.cancelled)
        XCTAssertTrue(history.entries.isEmpty)

        coordinator.handle(.pressed)
        coordinator.handle(.released)
        await coordinator.pipelineTask?.value
        XCTAssertEqual(history.entries.count, 1)
        XCTAssertNil(history.entries.first?.insertionStrategy)
        XCTAssertEqual(history.entries.first?.cleanupNote, "Accessibility access is off")
    }

    func testReleasedWithoutListeningDoesNothing() {
        let coordinator = makeCoordinator()
        coordinator.handle(.released)
        XCTAssertEqual(appState.dictation, .idle)
        XCTAssertTrue(overlay.events.isEmpty)
    }
}

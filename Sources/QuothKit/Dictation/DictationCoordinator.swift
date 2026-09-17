import Foundation
import QuothCore

@MainActor
public protocol OverlayPresenting: AnyObject {
    func showListening()
    func showTranscribing()
    func showError(_ message: String, duration: TimeInterval)
    func hide()
    func append(level: Float)
}

extension OverlayPanelController: OverlayPresenting {
    public func append(level: Float) {
        model.append(level: level)
    }
}

/// Owns the dictation loop and is the only writer of the dictation state.
@MainActor
public final class DictationCoordinator {
    private let appState: AppState
    private let hotkey: HotkeyMonitoring
    private let capture: AudioCapturing
    private let backend: any TranscriptionBackend
    private let inserter: any TextInserting
    private let permissions: any PermissionsProviding
    private let overlay: OverlayPresenting
    private let errorDuration: TimeInterval

    public private(set) var pipelineTask: Task<Void, Never>?
    public private(set) var preloadTask: Task<Void, Never>?
    private var errorResetTask: Task<Void, Never>?
    private var hotkeyRetryTask: Task<Void, Never>?
    private let hotkeyRetryInterval: TimeInterval

    public init(
        appState: AppState,
        hotkey: HotkeyMonitoring,
        capture: AudioCapturing,
        backend: any TranscriptionBackend,
        inserter: any TextInserting,
        permissions: any PermissionsProviding,
        overlay: OverlayPresenting,
        errorDuration: TimeInterval = 3,
        hotkeyRetryInterval: TimeInterval = 3
    ) {
        self.appState = appState
        self.hotkey = hotkey
        self.capture = capture
        self.backend = backend
        self.inserter = inserter
        self.permissions = permissions
        self.overlay = overlay
        self.errorDuration = errorDuration
        self.hotkeyRetryInterval = hotkeyRetryInterval
    }

    public func start() {
        hotkey.onEvent = { [weak self] event in
            Task { @MainActor in self?.handle(event) }
        }
        capture.onLevel = { [weak self] level in
            Task { @MainActor in self?.overlay.append(level: level) }
        }
        capture.onLimitReached = { [weak self] in
            Task { @MainActor in self?.handle(.released) }
        }
        do {
            try hotkey.start()
        } catch {
            fail(DictationFailure.message(for: error))
            retryHotkeyUntilItStarts()
        }
        // Loading the model takes seconds, so do it before the first dictation needs it.
        preloadTask = Task { [backend] in
            try? await backend.prepare(progress: nil)
        }
    }

    public func stop() {
        hotkey.stop()
        capture.cancel()
        pipelineTask?.cancel()
        errorResetTask?.cancel()
        hotkeyRetryTask?.cancel()
    }

    /// The event tap cannot be created until the user grants access. Keep trying so that the
    /// hotkey starts working as soon as they do, without a relaunch.
    private func retryHotkeyUntilItStarts() {
        hotkeyRetryTask?.cancel()
        hotkeyRetryTask = Task { [weak self, hotkeyRetryInterval] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(hotkeyRetryInterval * 1_000_000_000))
                guard let self, !Task.isCancelled else { return }
                if (try? hotkey.start()) != nil {
                    return
                }
            }
        }
    }

    public func handle(_ event: HotkeyEvent) {
        switch event {
        case .pressed: beginListening()
        case .released: finishListening()
        case .cancelled: cancelListening()
        }
    }

    private func beginListening() {
        guard !appState.dictation.isBusy else { return }
        appState.permissions = permissions.snapshot()
        // A press can only arrive through a working event tap, so Input Monitoring is not re-checked here.
        let missing = PermissionSummary.missing(in: appState.permissions).filter { $0 != .inputMonitoring }
        if let message = DictationFailure.message(forMissing: missing) {
            fail(message)
            return
        }
        do {
            try capture.start()
        } catch {
            fail(DictationFailure.message(for: error))
            return
        }
        errorResetTask?.cancel()
        appState.transition(to: .listening)
        overlay.showListening()
    }

    private func cancelListening() {
        guard appState.dictation == .listening else { return }
        capture.cancel()
        appState.transition(to: .idle)
        overlay.hide()
    }

    private func finishListening() {
        guard appState.dictation == .listening else { return }
        let clip = capture.stop()
        appState.transition(to: .transcribing)
        overlay.showTranscribing()
        pipelineTask = Task { [weak self] in
            await self?.transcribeAndInsert(clip)
        }
    }

    private func transcribeAndInsert(_ clip: AudioClip) async {
        do {
            let transcript = try await backend.transcribe(clip, options: .automatic)
            guard !transcript.text.isEmpty else {
                finishQuietly()
                return
            }
            _ = try await inserter.insert(transcript.text)
            appState.lastDictation = transcript.text
            finishQuietly()
        } catch TranscriptionError.tooShort {
            finishQuietly()
        } catch {
            fail(DictationFailure.message(for: error))
        }
    }

    private func finishQuietly() {
        appState.transition(to: .idle)
        overlay.hide()
    }

    private func fail(_ message: String) {
        appState.transition(to: .error(message))
        overlay.showError(message, duration: errorDuration)
        errorResetTask?.cancel()
        errorResetTask = Task { [weak self, errorDuration] in
            try? await Task.sleep(nanoseconds: UInt64(errorDuration * 1_000_000_000))
            guard !Task.isCancelled, let self, appState.dictation == .error(message) else { return }
            appState.transition(to: .idle)
        }
    }
}

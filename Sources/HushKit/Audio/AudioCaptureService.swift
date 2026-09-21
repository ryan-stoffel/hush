import AVFoundation
import HushCore

public final class AudioCaptureService: AudioCapturing {
    public var onLevel: ((Float) -> Void)?
    public var onLimitReached: (() -> Void)?

    private let maximumDuration: TimeInterval
    private let microphoneStatus: () -> PermissionStatus
    private let engine = AVAudioEngine()
    private let lock = NSLock()
    private var samples: [Float] = []
    private var resampler: AudioResampler?
    private var capturing = false

    public init(
        maximumDuration: TimeInterval = 600,
        microphoneStatus: @escaping () -> PermissionStatus = { SystemPermissionsService().status(of: .microphone) }
    ) {
        self.maximumDuration = maximumDuration
        self.microphoneStatus = microphoneStatus
    }

    public var isCapturing: Bool {
        lock.withLock { capturing }
    }

    public func start() throws {
        guard !isCapturing else { return }
        guard microphoneStatus() == .granted else { throw AudioCaptureError.microphonePermissionMissing }

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.channelCount > 0, format.sampleRate > 0, let resampler = AudioResampler(inputFormat: format) else {
            throw AudioCaptureError.noInputDevice
        }
        self.resampler = resampler
        lock.withLock {
            samples.removeAll(keepingCapacity: true)
            capturing = true
        }

        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.receive(buffer)
        }
        do {
            engine.prepare()
            try engine.start()
        } catch {
            teardown()
            throw AudioCaptureError.engineFailure(error.localizedDescription)
        }
    }

    public func stop() -> AudioClip {
        teardown()
        let captured = lock.withLock {
            let copy = samples
            samples.removeAll()
            return copy
        }
        return AudioClip(samples: captured)
    }

    public func cancel() {
        _ = stop()
    }

    private func teardown() {
        let wasCapturing = lock.withLock {
            let previous = capturing
            capturing = false
            return previous
        }
        guard wasCapturing else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        resampler = nil
    }

    private func receive(_ buffer: AVAudioPCMBuffer) {
        guard let converted = resampler?.convert(buffer), !converted.isEmpty else { return }
        let limit = Int(maximumDuration * AudioClip.transcriptionSampleRate)
        let reachedLimit = lock.withLock {
            guard capturing else { return false }
            samples.append(contentsOf: converted)
            return samples.count >= limit
        }
        let level = LevelMeter.level(of: converted)
        DispatchQueue.main.async { [weak self] in
            guard let self, isCapturing else { return }
            onLevel?(level)
            if reachedLimit {
                onLimitReached?()
            }
        }
    }
}

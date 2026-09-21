import Foundation

/// Mono Float32 samples held in memory. Audio is never written to disk.
public struct AudioClip: Equatable, Sendable {
    public static let transcriptionSampleRate: Double = 16000

    public let samples: [Float]
    public let sampleRate: Double

    public init(samples: [Float], sampleRate: Double = AudioClip.transcriptionSampleRate) {
        self.samples = samples
        self.sampleRate = sampleRate
    }

    public static let empty = AudioClip(samples: [])

    public var duration: TimeInterval {
        sampleRate > 0 ? Double(samples.count) / sampleRate : 0
    }

    public var isEmpty: Bool {
        samples.isEmpty
    }
}

public enum AudioCaptureError: Error, Equatable {
    case microphonePermissionMissing
    case noInputDevice
    case engineFailure(String)
}

public protocol AudioCapturing: AnyObject {
    /// Input level between 0 and 1, delivered on the main queue while capturing.
    var onLevel: ((Float) -> Void)? { get set }
    /// Called on the main queue when the maximum session length is reached. Capture has already stopped.
    var onLimitReached: (() -> Void)? { get set }
    var isCapturing: Bool { get }
    func start() throws
    func stop() -> AudioClip
    func cancel()
}

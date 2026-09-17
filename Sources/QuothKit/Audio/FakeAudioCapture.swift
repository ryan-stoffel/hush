import QuothCore

public final class FakeAudioCapture: AudioCapturing {
    public var onLevel: ((Float) -> Void)?
    public var onLimitReached: (() -> Void)?
    public private(set) var isCapturing = false
    public private(set) var startCount = 0
    public private(set) var cancelCount = 0
    public var startError: Error?
    public var bufferToReturn: AudioClip

    public init(bufferToReturn: AudioClip = AudioClip(samples: Array(repeating: 0.1, count: 16000))) {
        self.bufferToReturn = bufferToReturn
    }

    public func start() throws {
        if let startError {
            throw startError
        }
        startCount += 1
        isCapturing = true
    }

    public func stop() -> AudioClip {
        isCapturing = false
        return bufferToReturn
    }

    public func cancel() {
        cancelCount += 1
        isCapturing = false
    }
}

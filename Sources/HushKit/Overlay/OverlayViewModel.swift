import Foundation
import HushCore

@MainActor
public final class OverlayViewModel: ObservableObject {
    public enum Mode: Equatable {
        case listening
        case transcribing
        case error(String)
    }

    @Published public var mode: Mode = .listening
    @Published public private(set) var waveform = WaveformModel()
    @Published public var elapsed: TimeInterval = 0

    public init() {}

    public var elapsedText: String {
        ElapsedTimeFormatter.string(from: elapsed)
    }

    public func append(level: Float) {
        waveform.append(level)
    }

    public func setWaveform(_ waveform: WaveformModel) {
        self.waveform = waveform
    }

    public func resetForNewDictation() {
        waveform.reset()
        elapsed = 0
        mode = .listening
    }
}

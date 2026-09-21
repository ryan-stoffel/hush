import Foundation

/// Turns raw samples into a 0...1 level for the waveform.
public enum LevelMeter {
    /// Quiet room noise sits around -60 dBFS and speech close to the microphone peaks near -10 dBFS.
    public static let floorDecibels: Float = -60
    public static let ceilingDecibels: Float = -10

    public static func rootMeanSquare(_ samples: [Float]) -> Float {
        guard !samples.isEmpty else { return 0 }
        let sum = samples.reduce(Float(0)) { $0 + $1 * $1 }
        return (sum / Float(samples.count)).squareRoot()
    }

    public static func decibels(fromRMS rms: Float) -> Float {
        rms > 0 ? 20 * log10(rms) : -.infinity
    }

    public static func normalizedLevel(decibels: Float) -> Float {
        guard decibels.isFinite else { return 0 }
        let scaled = (decibels - floorDecibels) / (ceilingDecibels - floorDecibels)
        return min(max(scaled, 0), 1)
    }

    public static func level(of samples: [Float]) -> Float {
        normalizedLevel(decibels: decibels(fromRMS: rootMeanSquare(samples)))
    }
}

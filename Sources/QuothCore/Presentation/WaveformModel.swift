import Foundation

/// Fixed-size history of input levels, oldest first, used to draw the overlay bars.
public struct WaveformModel: Equatable, Sendable {
    public static let minimumBarHeight: Float = 0.08

    public let barCount: Int
    public private(set) var levels: [Float]

    public init(barCount: Int = 24) {
        self.barCount = max(barCount, 1)
        levels = Array(repeating: 0, count: self.barCount)
    }

    public init(levels: [Float]) {
        barCount = max(levels.count, 1)
        self.levels = levels.isEmpty ? [0] : levels.map(Self.clamp)
    }

    public mutating func append(_ level: Float) {
        levels.removeFirst()
        levels.append(Self.clamp(level))
    }

    public mutating func reset() {
        levels = Array(repeating: 0, count: barCount)
    }

    /// Bar heights between the minimum height and 1, so silence still draws a visible baseline.
    public var barHeights: [Float] {
        levels.map { Self.minimumBarHeight + (1 - Self.minimumBarHeight) * $0 }
    }

    private static func clamp(_ level: Float) -> Float {
        level.isFinite ? min(max(level, 0), 1) : 0
    }
}

public enum ElapsedTimeFormatter {
    /// 7 becomes 0:07, 125 becomes 2:05, 3600 becomes 60:00.
    public static func string(from interval: TimeInterval) -> String {
        let total = interval.isFinite ? max(Int(interval), 0) : 0
        let seconds = total % 60
        return "\(total / 60):\(seconds < 10 ? "0" : "")\(seconds)"
    }
}

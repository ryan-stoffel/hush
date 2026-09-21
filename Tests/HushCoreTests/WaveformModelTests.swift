import XCTest
@testable import HushCore

final class WaveformModelTests: XCTestCase {
    func testStartsFlatWithTheRequestedBarCount() {
        let model = WaveformModel(barCount: 8)
        XCTAssertEqual(model.levels, Array(repeating: 0, count: 8))
        XCTAssertEqual(model.barHeights, Array(repeating: WaveformModel.minimumBarHeight, count: 8))
    }

    func testAppendScrollsOldestOut() {
        var model = WaveformModel(barCount: 3)
        for level: Float in [0.1, 0.2, 0.3, 0.4] {
            model.append(level)
        }
        XCTAssertEqual(model.levels, [0.2, 0.3, 0.4])
        XCTAssertEqual(model.levels.count, 3)
    }

    func testLevelsAreClamped() {
        var model = WaveformModel(barCount: 3)
        model.append(-1)
        model.append(2)
        model.append(.nan)
        XCTAssertEqual(model.levels, [0, 1, 0])
        XCTAssertEqual(model.barHeights[1], 1, accuracy: 0.0001)
    }

    func testResetFlattens() {
        var model = WaveformModel(levels: [0.5, 0.9])
        model.reset()
        XCTAssertEqual(model.levels, [0, 0])
    }

    func testBarCountIsNeverZero() {
        XCTAssertEqual(WaveformModel(barCount: 0).barCount, 1)
        XCTAssertEqual(WaveformModel(levels: []).levels, [0])
    }

    func testElapsedTimeFormatting() {
        XCTAssertEqual(ElapsedTimeFormatter.string(from: 0), "0:00")
        XCTAssertEqual(ElapsedTimeFormatter.string(from: 7.9), "0:07")
        XCTAssertEqual(ElapsedTimeFormatter.string(from: 125), "2:05")
        XCTAssertEqual(ElapsedTimeFormatter.string(from: 3600), "60:00")
        XCTAssertEqual(ElapsedTimeFormatter.string(from: -3), "0:00")
        XCTAssertEqual(ElapsedTimeFormatter.string(from: .infinity), "0:00")
    }
}

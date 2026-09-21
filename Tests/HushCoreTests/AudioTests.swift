import XCTest
@testable import HushCore

final class AudioTests: XCTestCase {
    func testDuration() {
        XCTAssertEqual(AudioClip(samples: Array(repeating: 0, count: 8000)).duration, 0.5, accuracy: 0.0001)
        XCTAssertEqual(AudioClip.empty.duration, 0)
        XCTAssertTrue(AudioClip.empty.isEmpty)
        XCTAssertEqual(AudioClip(samples: [0], sampleRate: 0).duration, 0)
    }

    func testRootMeanSquare() {
        XCTAssertEqual(LevelMeter.rootMeanSquare([]), 0)
        XCTAssertEqual(LevelMeter.rootMeanSquare([0.5, -0.5, 0.5, -0.5]), 0.5, accuracy: 0.0001)
        let sine = (0 ..< 1600).map { Float(sin(2 * Double.pi * 440 * Double($0) / 16000)) }
        XCTAssertEqual(LevelMeter.rootMeanSquare(sine), Float(1 / 2.0.squareRoot()), accuracy: 0.01)
    }

    func testDecibels() {
        XCTAssertEqual(LevelMeter.decibels(fromRMS: 1), 0, accuracy: 0.001)
        XCTAssertEqual(LevelMeter.decibels(fromRMS: 0.1), -20, accuracy: 0.001)
        XCTAssertEqual(LevelMeter.decibels(fromRMS: 0), -.infinity)
    }

    func testNormalizedLevelIsClampedBetweenZeroAndOne() {
        XCTAssertEqual(LevelMeter.normalizedLevel(decibels: -.infinity), 0)
        XCTAssertEqual(LevelMeter.normalizedLevel(decibels: -80), 0)
        XCTAssertEqual(LevelMeter.normalizedLevel(decibels: -60), 0)
        XCTAssertEqual(LevelMeter.normalizedLevel(decibels: -35), 0.5, accuracy: 0.001)
        XCTAssertEqual(LevelMeter.normalizedLevel(decibels: -10), 1)
        XCTAssertEqual(LevelMeter.normalizedLevel(decibels: 0), 1)
    }

    func testSilenceIsZeroAndLoudSpeechIsHigh() {
        XCTAssertEqual(LevelMeter.level(of: Array(repeating: 0, count: 512)), 0)
        XCTAssertGreaterThan(LevelMeter.level(of: Array(repeating: 0.3, count: 512)), 0.9)
    }
}

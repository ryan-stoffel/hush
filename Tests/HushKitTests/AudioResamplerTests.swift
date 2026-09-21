import AVFoundation
import HushCore
import XCTest
@testable import HushKit

final class AudioResamplerTests: XCTestCase {
    private func sineBuffer(
        sampleRate: Double,
        channels: AVAudioChannelCount,
        seconds: Double
    ) throws -> AVAudioPCMBuffer {
        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: channels))
        let frames = AVAudioFrameCount(sampleRate * seconds)
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames))
        buffer.frameLength = frames
        for channel in 0 ..< Int(channels) {
            let data = try XCTUnwrap(buffer.floatChannelData?[channel])
            for frame in 0 ..< Int(frames) {
                data[frame] = Float(sin(2 * Double.pi * 440 * Double(frame) / sampleRate)) * 0.5
            }
        }
        return buffer
    }

    func testStereo48kBecomesMono16k() throws {
        let input = try sineBuffer(sampleRate: 48000, channels: 2, seconds: 1)
        let resampler = try XCTUnwrap(AudioResampler(inputFormat: input.format))
        let output = resampler.convert(input)
        // The sample rate converter holds back its filter tail, about 60 ms, once per stream.
        XCTAssertEqual(Double(output.count), 16000, accuracy: 1100)
        XCTAssertEqual(LevelMeter.rootMeanSquare(output), 0.5 / Float(2.0.squareRoot()), accuracy: 0.05)
    }

    func testStreamingChunksLoseTheFilterTailOnlyOnce() throws {
        let chunk = try sineBuffer(sampleRate: 48000, channels: 1, seconds: 0.1)
        let resampler = try XCTUnwrap(AudioResampler(inputFormat: chunk.format))
        let total = (0 ..< 20).reduce(0) { count, _ in count + resampler.convert(chunk).count }
        XCTAssertEqual(Double(total), 32000, accuracy: 1100)
    }

    func testMono44kBecomes16k() throws {
        let input = try sineBuffer(sampleRate: 44100, channels: 1, seconds: 0.5)
        let resampler = try XCTUnwrap(AudioResampler(inputFormat: input.format))
        XCTAssertEqual(Double(resampler.convert(input).count), 8000, accuracy: 1100)
    }

    func testSixteenKilohertzPassesThrough() throws {
        let input = try sineBuffer(sampleRate: 16000, channels: 1, seconds: 0.25)
        let resampler = try XCTUnwrap(AudioResampler(inputFormat: input.format))
        XCTAssertEqual(Double(resampler.convert(input).count), 4000, accuracy: 100)
    }

    func testStartWithoutMicrophonePermissionThrows() {
        let service = AudioCaptureService(microphoneStatus: { .denied })
        XCTAssertThrowsError(try service.start()) { error in
            XCTAssertEqual(error as? AudioCaptureError, .microphonePermissionMissing)
        }
        XCTAssertFalse(service.isCapturing)
        XCTAssertTrue(service.stop().isEmpty)
    }
}

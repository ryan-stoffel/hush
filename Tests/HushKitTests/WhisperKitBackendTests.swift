import AVFoundation
import HushCore
import XCTest
@testable import HushKit

final class WhisperKitBackendTests: XCTestCase {
    func testTooShortAudioNeverReachesTheModel() async {
        let backend = WhisperKitBackend(modelsDirectory: FileManager.default.temporaryDirectory)
        do {
            _ = try await backend.transcribe(AudioClip(samples: Array(repeating: 0, count: 1600)), options: .automatic)
            XCTFail("expected tooShort")
        } catch {
            XCTAssertEqual(error as? TranscriptionError, .tooShort)
        }
    }

    func testModelsLiveInApplicationSupport() {
        let path = WhisperKitBackend.defaultModelsDirectory().path
        XCTAssertTrue(path.hasSuffix("Application Support/Hush/Models"), path)
    }

    func testBackendIsLocal() {
        let backend = WhisperKitBackend()
        XCTAssertFalse(backend.sendsAudioOffDevice)
        XCTAssertEqual(backend.id, "whisperkit")
    }

    func testFakeBackendHonorsTheSameRules() async throws {
        let fake = FakeTranscriptionBackend(result: .success("Hi."))
        let transcript = try await fake.transcribe(
            AudioClip(samples: Array(repeating: 0, count: 16000)),
            options: .automatic
        )
        XCTAssertEqual(transcript.text, "Hi.")
        XCTAssertEqual(transcript.audioDuration, 1, accuracy: 0.001)
    }

    /// Downloads a model and runs real inference, so it only runs on request:
    /// RUN_MODEL_TESTS=1 swift test --filter WhisperKitBackendTests
    func testTranscribesTheBundledSample() async throws {
        guard ProcessInfo.processInfo.environment["RUN_MODEL_TESTS"] == "1" else {
            throw XCTSkip("Set RUN_MODEL_TESTS=1 to run model inference.")
        }
        let url = try XCTUnwrap(Bundle.module.url(forResource: "sample-speech", withExtension: "wav"))
        let file = try AVAudioFile(forReading: url)
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(
            pcmFormat: file.processingFormat,
            frameCapacity: AVAudioFrameCount(file.length)
        ))
        try file.read(into: buffer)
        let channel = try XCTUnwrap(buffer.floatChannelData?[0])
        let samples = Array(UnsafeBufferPointer(start: channel, count: Int(buffer.frameLength)))

        let backend = WhisperKitBackend()
        let transcript = try await backend.transcribe(AudioClip(samples: samples), options: .automatic)
        XCTAssertTrue(transcript.text.lowercased().contains("quick brown fox"), transcript.text)
        XCTAssertEqual(transcript.language, "en")
    }
}

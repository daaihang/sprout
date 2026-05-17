import Foundation
import XCTest
@testable import mory

@MainActor
final class AudioRecorderModelTests: XCTestCase {
    func testRecordingStopTranscribesAndReachesReadyState() async {
        let controller = FakeAudioRecordingController(
            output: AudioRecordingOutput(url: nil, filename: "quick.caf", audioData: Data([1, 2, 3])),
            partialTranscript: "partial text"
        )
        let transcriber = FakeAudioTranscriber(
            result: AudioTranscriptionService.Result(
                transcription: "final transcript",
                locale: Locale(identifier: "en_US"),
                duration: 0.3
            )
        )
        let model = AudioRecorderModel(controller: controller, transcriber: transcriber)

        await model.startRecording()
        let output = await model.stopAndTranscribe()

        XCTAssertEqual(output?.filename, "quick.caf")
        XCTAssertEqual(model.state, .transcriptReady)
        XCTAssertEqual(model.liveTranscription, "partial text")
        XCTAssertEqual(model.finalTranscription, "final transcript")
        XCTAssertEqual(model.transcriptionDuration, 0.3)
        XCTAssertEqual(controller.startCallCount, 1)
        XCTAssertEqual(controller.stopCallCount, 1)
        XCTAssertEqual(transcriber.callCount, 1)
    }

    func testRepeatedStopIsIdempotentAfterTranscriptReady() async {
        let controller = FakeAudioRecordingController(
            output: AudioRecordingOutput(url: nil, filename: "idempotent.caf", audioData: Data([4, 5, 6]))
        )
        let model = AudioRecorderModel(
            controller: controller,
            transcriber: FakeAudioTranscriber(result: nil)
        )

        await model.startRecording()
        _ = await model.stopAndTranscribe()
        _ = await model.stopAndTranscribe()

        XCTAssertEqual(model.state, .transcriptReady)
        XCTAssertEqual(controller.stopCallCount, 1)
        XCTAssertEqual(model.recordedAudioData, Data([4, 5, 6]))
    }

    func testCancelDuringRecordingClearsOutputAndDoesNotTranscribe() async {
        let controller = FakeAudioRecordingController(
            output: AudioRecordingOutput(url: nil, filename: "cancel.caf", audioData: Data([7]))
        )
        let transcriber = FakeAudioTranscriber(
            result: AudioTranscriptionService.Result(
                transcription: "should not run",
                locale: Locale(identifier: "en_US"),
                duration: 0.1
            )
        )
        let model = AudioRecorderModel(controller: controller, transcriber: transcriber)

        await model.startRecording()
        await model.cancelRecording()

        XCTAssertEqual(model.state, .cancelled)
        XCTAssertNil(model.recordedAudioData)
        XCTAssertTrue(model.liveTranscription.isEmpty)
        XCTAssertTrue(model.finalTranscription.isEmpty)
        XCTAssertEqual(controller.cancelCallCount, 1)
        XCTAssertEqual(transcriber.callCount, 0)
    }

    func testStartFailureMovesToFailedAndCanClearToIdle() async {
        let controller = FakeAudioRecordingController(
            output: nil,
            startError: TestRecorderError.permissionDenied
        )
        let model = AudioRecorderModel(
            controller: controller,
            transcriber: FakeAudioTranscriber(result: nil)
        )

        await model.startRecording()

        XCTAssertEqual(model.state, .failed)
        XCTAssertEqual(model.errorMessage, "Permission denied")

        model.clearRecording()
        XCTAssertEqual(model.state, .idle)
        XCTAssertNil(model.errorMessage)
    }

    func testMissingFinalTranscriptFallsBackToLivePartial() async {
        let controller = FakeAudioRecordingController(
            output: AudioRecordingOutput(url: nil, filename: "fallback.caf", audioData: Data([8, 9])),
            partialTranscript: "live partial"
        )
        let model = AudioRecorderModel(
            controller: controller,
            transcriber: FakeAudioTranscriber(result: nil)
        )

        await model.startRecording()
        _ = await model.stopAndTranscribe()

        XCTAssertEqual(model.state, .transcriptReady)
        XCTAssertEqual(model.finalTranscription, "live partial")
    }
}

private enum TestRecorderError: LocalizedError {
    case permissionDenied

    var errorDescription: String? {
        "Permission denied"
    }
}

@MainActor
private final class FakeAudioRecordingController: AudioRecordingControlling {
    var onPartialTranscription: (@MainActor @Sendable (String) -> Void)?
    private let output: AudioRecordingOutput?
    private let partialTranscript: String?
    private let startError: Error?

    private(set) var startCallCount = 0
    private(set) var stopCallCount = 0
    private(set) var cancelCallCount = 0

    init(output: AudioRecordingOutput?, partialTranscript: String? = nil, startError: Error? = nil) {
        self.output = output
        self.partialTranscript = partialTranscript
        self.startError = startError
    }

    func start() async throws {
        startCallCount += 1
        if let startError {
            throw startError
        }
        if let partialTranscript {
            onPartialTranscription?(partialTranscript)
        }
    }

    func stop() async -> AudioRecordingOutput? {
        stopCallCount += 1
        return output
    }

    func cancel() async {
        cancelCallCount += 1
    }
}

private final class FakeAudioTranscriber: AudioRecordingTranscribing, @unchecked Sendable {
    private let result: AudioTranscriptionService.Result?
    private(set) var callCount = 0

    init(result: AudioTranscriptionService.Result?) {
        self.result = result
    }

    func transcribe(audioData: Data, filename: String?) async -> AudioTranscriptionService.Result? {
        callCount += 1
        return result
    }
}

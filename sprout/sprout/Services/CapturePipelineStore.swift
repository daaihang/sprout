import Foundation
import Observation

@Observable
@MainActor
final class CapturePipelineStore {
    static let shared = CapturePipelineStore()

    enum Stage: Equatable {
        case idle
        case saving
        case saved
        case analyzing
        case analyzed
        case analysisUnavailable
        case failed
    }

    var stage: Stage = .idle
    var detailMessage: String? = nil
    var lastRecordID: UUID? = nil
    var lastStatusUpdatedAt: Date? = nil
    var lastPreviewAnalyzeRequest: AuthSessionManager.RequestRecord? = nil
    var lastRecordAnalyzeRequest: AuthSessionManager.RequestRecord? = nil

    @ObservationIgnored
    private var resetTask: Task<Void, Never>? = nil

    func beginSaving(recordID: UUID? = nil) {
        update(stage: .saving, detail: nil, recordID: recordID, autoReset: false)
    }

    func markSaved(recordID: UUID) {
        update(stage: .saved, detail: nil, recordID: recordID, autoReset: false)
    }

    func markAnalyzing(recordID: UUID, detail: String? = nil) {
        update(stage: .analyzing, detail: detail, recordID: recordID, autoReset: false)
    }

    func markAnalyzed(recordID: UUID) {
        update(stage: .analyzed, detail: nil, recordID: recordID, autoReset: true)
    }

    func markAnalysisUnavailable(recordID: UUID, detail: String) {
        update(stage: .analysisUnavailable, detail: detail, recordID: recordID, autoReset: true)
    }

    func markFailed(recordID: UUID? = nil, detail: String) {
        update(stage: .failed, detail: detail, recordID: recordID, autoReset: true)
    }

    func clearStatus() {
        resetTask?.cancel()
        resetTask = nil
        stage = .idle
        detailMessage = nil
        lastRecordID = nil
        lastStatusUpdatedAt = Date()
    }

    func recordAnalyzeRequest(_ request: AuthSessionManager.RequestRecord) {
        switch request.kind {
        case "analyze_preview":
            lastPreviewAnalyzeRequest = request
        case "analyze_record":
            lastRecordAnalyzeRequest = request
        default:
            break
        }
    }

    private func update(
        stage: Stage,
        detail: String?,
        recordID: UUID?,
        autoReset: Bool
    ) {
        resetTask?.cancel()
        resetTask = nil

        self.stage = stage
        detailMessage = detail
        lastRecordID = recordID
        lastStatusUpdatedAt = Date()

        guard autoReset else { return }
        let expectedStage = stage
        resetTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(4))
            guard let self, self.stage == expectedStage else { return }
            self.clearStatus()
        }
    }
}

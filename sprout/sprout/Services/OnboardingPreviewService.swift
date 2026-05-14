import Foundation
import Observation

@Observable
@MainActor
final class OnboardingPreviewService {
    typealias PreviewResult = SproutAnalyzeResponse

    var isLoading = false
    var previewText = ""
    var previewResult: PreviewResult? = nil
    var latestAnalysisSnapshot: RecordAnalysisSnapshot? = nil
    var latestMemoryView: SproutMemoryRepository.RecordMemoryView? = nil
    var errorMessage: String? = nil

    private let aggregateBuilder = SproutMemoryAggregateBuilder()
    private let capturePipeline = CapturePipelineStore.shared
    private let memoryRepository: SproutMemoryRepository
    private let analyzeService = SproutAnalyzeService()

    init(memoryRepository: SproutMemoryRepository) {
        self.memoryRepository = memoryRepository
    }

    func runPreview() async {
        let content = previewText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else {
            errorMessage = "Write a short memory to preview the AI reflection."
            latestMemoryView = nil
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let aggregate = aggregateBuilder.buildPreviewAggregate(from: content)
        capturePipeline.markAnalyzing(recordID: aggregate.recordShell.id, detail: "Preview request")

        do {
            let result = try await analyzeService.analyzePreview(aggregate: aggregate)
            previewResult = result

            let analysis = analyzeService.mapToAnalysisSnapshot(response: result, recordID: aggregate.recordShell.id)
            latestAnalysisSnapshot = analysis
            try memoryRepository.setAnalysis(analysis, aggregate: aggregate)
            latestMemoryView = memoryRepository.memoryView(for: aggregate.recordShell.id)
            capturePipeline.markAnalyzed(recordID: aggregate.recordShell.id)
        } catch {
            errorMessage = error.localizedDescription
            latestMemoryView = nil
            capturePipeline.markFailed(recordID: aggregate.recordShell.id, detail: error.localizedDescription)
        }
    }
}

enum OnboardingPreviewError: LocalizedError {
    case invalidBaseURL
    case invalidResponse
    case server(String)

    var errorDescription: String? {
        switch self {
        case .invalidBaseURL:
            return "MORY_API_BASE_URL is not configured."
        case .invalidResponse:
            return "Invalid server response."
        case let .server(message):
            return message
        }
    }
}

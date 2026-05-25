#if DEBUG
import SwiftUI

struct DebugClarificationQuestionsView: View {
    @Environment(\.memoryRepository) private var memoryRepository
    @State private var questions: [ClarificationQuestion] = []
    @State private var resultMessage: String?

    var body: some View {
        List {
            Section("Pending (\(questions.filter { $0.status == .pending }.count))") {
                let pending = questions.filter { $0.status == .pending }
                if pending.isEmpty {
                    Text("No pending questions")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(pending) { question in
                        DebugQuestionRow(
                            question: question,
                            onAnswer: { answer in answerQuestion(question.id, answer: answer) },
                            onDismiss: { dismissQuestion(question.id) }
                        )
                    }
                }
            }

            Section("Answered (\(questions.filter { $0.status == .answered }.count))") {
                ForEach(questions.filter { $0.status == .answered }.prefix(10)) { question in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(question.prompt)
                            .font(.caption)
                        if let answer = question.answer {
                            Text("Answer: \(answer.value)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section("Dismissed (\(questions.filter { $0.status == .dismissed }.count))") {
                ForEach(questions.filter { $0.status == .dismissed }.prefix(5)) { question in
                    Text(question.prompt)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if let resultMessage {
                Section("Result") {
                    Text(resultMessage)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }
        }
        .navigationTitle("Clarification Questions")
        .task { reload() }
        .toolbar {
            Button("Refresh") { reload() }
        }
    }

    private func reload() {
        questions = (try? memoryRepository.fetchClarificationQuestions(status: nil, limit: nil)) ?? []
    }

    private func answerQuestion(_ id: UUID, answer: ClarificationAnswer) {
        do {
            try memoryRepository.answerClarificationQuestion(id, answer: answer)
            resultMessage = "Answered question \(id.uuidString.prefix(8))."
            reload()
        } catch {
            resultMessage = "Answer failed: \(error.localizedDescription)"
        }
    }

    private func dismissQuestion(_ id: UUID) {
        do {
            try memoryRepository.dismissClarificationQuestion(id)
            resultMessage = "Dismissed \(id.uuidString.prefix(8))."
            reload()
        } catch {
            resultMessage = "Dismiss failed: \(error.localizedDescription)"
        }
    }
}

// MARK: - Row

private struct DebugQuestionRow: View {
    let question: ClarificationQuestion
    let onAnswer: (ClarificationAnswer) -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(question.prompt)
                .font(.caption)

            Text("Kind: \(question.kind.rawValue) · Sensitivity: \(question.sensitivity.rawValue)")
                .font(.caption2)
                .foregroundStyle(.secondary)

            if !question.candidateAnswers.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(question.candidateAnswers) { option in
                            Button(option.label) {
                                onAnswer(ClarificationAnswer(value: option.value))
                            }
                            .buttonStyle(.bordered)
                            .font(.caption2)
                        }
                    }
                }
            }

            Button("Dismiss", role: .destructive) {
                onDismiss()
            }
            .font(.caption2)
        }
        .padding(.vertical, 4)
    }
}
#endif

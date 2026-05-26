import SwiftUI

enum HomeRoute: Hashable, Identifiable, Sendable {
    case memory(UUID)
    case arc(UUID)
    case reflection(UUID)
    case question(UUID)

    var id: String {
        switch self {
        case let .memory(id): return "memory-\(id.uuidString)"
        case let .arc(id): return "arc-\(id.uuidString)"
        case let .reflection(id): return "reflection-\(id.uuidString)"
        case let .question(id): return "question-\(id.uuidString)"
        }
    }
}

struct ClarificationQuestionDetailView: View {
    @Environment(\.memoryRepository) private var memoryRepository

    let questionID: UUID

    @State private var question: ClarificationQuestion?
    @State private var profile: EntityProfile?
    @State private var errorMessage: String?

    var body: some View {
        List {
            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }

            if let question {
                Section {
                    if question.status == .pending {
                        ClarificationQuestionCard(
                            question: question,
                            profile: profile,
                            onAnswer: answerQuestion,
                            onDismiss: dismissQuestion
                        )
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(question.prompt)
                                .font(.headline)
                            Text(question.status.displayLabel)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if let answer = question.answer {
                                Text(answer.freeformText ?? answer.value)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            } else if errorMessage == nil {
                Section {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .navigationTitle("Daily question")
        .moryHidesTabChrome()
        .task {
            load()
        }
        .refreshable {
            load()
        }
    }

    private func load() {
        do {
            let questions = try memoryRepository.fetchClarificationQuestions(status: nil, limit: nil)
            question = questions.first { $0.id == questionID }
            if let question, question.targetType == .entity {
                profile = try memoryRepository.fetchEntityProfile(entityID: question.targetID)
            } else {
                profile = nil
            }
            errorMessage = question == nil ? "Question is no longer available." : nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func answerQuestion(_ answer: ClarificationAnswer) {
        do {
            try memoryRepository.answerClarificationQuestion(questionID, answer: answer)
            load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func dismissQuestion() {
        do {
            try memoryRepository.dismissClarificationQuestion(questionID)
            load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

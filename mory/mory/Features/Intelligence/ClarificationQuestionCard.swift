import SwiftUI

struct ClarificationQuestionCard: View {
    let question: ClarificationQuestion
    let profile: EntityProfile?
    let onAnswer: (ClarificationAnswer) -> Void
    let onDismiss: () -> Void

    @State private var freeformAnswer = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let displayName = profile?.displayName ?? questionPromptTitle {
                Text(displayName)
                    .font(.headline)
            }

            Text(question.prompt)
                .font(.subheadline)
                .foregroundStyle(.primary)

            if let reason = question.reason.trimmedOrNil {
                Text(reason)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }

            if question.kind == .entityAlias {
                TextField("Nickname or alternate name", text: $freeformAnswer)
                    .textFieldStyle(.roundedBorder)

                HStack {
                    if let noAliasOption = question.candidateAnswers.first(where: { $0.value == "no_alias" }) {
                        Button(noAliasOption.label) {
                            onAnswer(ClarificationAnswer(value: noAliasOption.value))
                        }
                        .buttonStyle(.bordered)
                    }

                    Button("Save") {
                        onAnswer(
                            ClarificationAnswer(
                                value: freeformAnswer.trimmedOrNil ?? "",
                                freeformText: freeformAnswer.trimmedOrNil
                            )
                        )
                        freeformAnswer = ""
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(freeformAnswer.trimmedOrNil == nil)
                }
            } else {
                ForEach(question.candidateAnswers.prefix(4)) { option in
                    Button(option.label) {
                        onAnswer(ClarificationAnswer(value: option.value))
                    }
                    .buttonStyle(.bordered)
                }
            }

            Button("Not now", role: .cancel, action: onDismiss)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
    }

    private var questionPromptTitle: String? {
        if let profileName = profile?.displayName.trimmedOrNil {
            return profileName
        }
        if question.kind == .dailyReflection {
            return String(localized: "Daily question")
        }
        if question.kind == .revisit {
            return String(localized: "Memory revisit")
        }
        return nil
    }
}

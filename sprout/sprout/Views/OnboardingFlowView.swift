import SwiftUI

struct OnboardingFlowView: View {
    @Environment(AppLocalization.self) private var localization
    @Environment(OnboardingPreviewService.self) private var previewService

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                previewComposer
                if let result = previewService.previewResult {
                    previewResultCard(result)
                }
                if let memoryView = previewService.latestMemoryView,
                   let snapshot = previewService.latestAnalysisSnapshot {
                    persistedResultCard(memoryView: memoryView, snapshot: snapshot)
                }
                if let errorMessage = previewService.errorMessage, !errorMessage.isEmpty {
                    Text(errorMessage)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.red)
                }
                signInSection
            }
            .padding(24)
        }
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.98, green: 0.95, blue: 0.89),
                    Color(red: 0.92, green: 0.96, blue: 0.93),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(localization.string("onboarding.title", default: "Try a first reflection before you sign in"))
                .font(.system(size: 30, weight: .bold, design: .rounded))

            Text(localization.string("onboarding.subtitle", default: "Write a small memory and we will turn it into a preview insight. Sign in when you want to keep the journey going."))
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }

    private var previewComposer: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(localization.string("onboarding.prompt", default: "What happened today?"))
                .font(.headline)

            TextEditor(text: Binding(
                get: { previewService.previewText },
                set: { previewService.previewText = $0 }
            ))
            .frame(minHeight: 140)
            .padding(12)
            .background(.white.opacity(0.7), in: RoundedRectangle(cornerRadius: 20, style: .continuous))

            Button {
                Task { await previewService.runPreview() }
            } label: {
                HStack {
                    if previewService.isLoading {
                        ProgressView()
                    }
                    Text(localization.string("onboarding.preview_cta", default: "Preview AI Reflection"))
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(previewService.isLoading)
        }
        .padding(20)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private func previewResultCard(_ result: OnboardingPreviewService.PreviewResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(localization.string("onboarding.result_title", default: "Preview Result"))
                .font(.headline)

            Label(result.emotion.label.capitalized, systemImage: "sparkles")
                .font(.subheadline.weight(.semibold))

            Text(result.insight)
                .font(.body)

            if !result.tags.isEmpty {
                Text(result.tags.joined(separator: "  •  "))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if !result.entities.isEmpty {
                Text(
                    result.entities
                        .map { "\($0.kind.capitalized): \($0.name)" }
                        .joined(separator: "  •  ")
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
            }

            if let followUp = result.followUp {
                Text(followUp.question)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .background(.white.opacity(0.75), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func persistedResultCard(
        memoryView: SproutMemoryRepository.RecordMemoryView,
        snapshot: RecordAnalysisSnapshot
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(localization.string("common.stored_memory_effects", default: "Stored Memory Effects"))
                .font(.headline)

            Text(localization.string("common.v3_memory_layer_result", default: "This is the v3 memory-layer result after the preview response is mapped into snapshot, graph, and reflection state."))
                .font(.footnote)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                SignalPill(title: "\(memoryView.artifacts.count) artifacts", tint: .blue)
                SignalPill(title: "\(memoryView.linkedEntities.count) entities", tint: .green)
                if let reflection = memoryView.reflection {
                    SignalPill(title: reflection.type.rawValue.capitalized, tint: .orange)
                }
            }

            AnalysisCompactEvidenceView(
                analysis: snapshot,
                showInsight: true,
                showEntities: true,
                showRetrievalTerms: true,
                showReflectionHint: true,
                maxEntityCount: 4,
                maxRetrievalTermCount: 8
            )

            if !memoryView.linkedEntities.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(localization.string("common.linked_entities", default: "Linked Entities"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    TokenPillRow(
                        values: memoryView.linkedEntities.prefix(6).map { "\($0.kind.badgeLabel): \($0.displayName)" },
                        tint: .green
                    )
                }
            }

            if let reflection = memoryView.reflection {
                VStack(alignment: .leading, spacing: 8) {
                    Text(localization.string("common.generated_reflection", default: "Generated Reflection"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(reflection.title)
                        .font(.subheadline.weight(.semibold))
                    Text(reflection.body)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(4)
                }
            }
        }
        .padding(20)
        .background(.white.opacity(0.78), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var signInSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(localization.string("onboarding.signin_title", default: "Sign in to save your progress and finish setup"))
                .font(.headline)

            AuthLandingView(
                titleOverride: localization.string("auth.onboarding.title", default: "Keep this reflection and continue"),
                subtitleOverride: localization.string("auth.onboarding.subtitle", default: "Use Sign in with Apple to save future reflections, sync devices, and finish your setup."),
                compactLayout: true
            )
        }
    }
}

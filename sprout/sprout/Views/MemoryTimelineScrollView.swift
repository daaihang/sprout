import SwiftUI

struct MemoryTimelineScrollView: View {
    @Environment(AppLocalization.self) private var localization
    @Environment(SproutMemoryRepository.self) private var memoryRepository

    let selectedDate: Date

    private var daySections: [MemoryDaySection] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: memoryRepository.recordShells) { recordShell in
            calendar.startOfDay(for: recordShell.createdAt)
        }

        return grouped
            .map { date, shells in
                MemoryDaySection(
                    id: date,
                    recordShells: shells.sorted { $0.createdAt > $1.createdAt }
                )
            }
            .sorted { $0.id > $1.id }
    }

    var body: some View {
        Group {
            if daySections.isEmpty {
                emptyState
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 120)
            } else {
                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                            ForEach(daySections) { section in
                                Section {
                                    VStack(spacing: 0) {
                                        ForEach(section.recordShells, id: \.id) { recordShell in
                                            MemoryTimelineRow(recordShell: recordShell)
                                                .padding(.horizontal, 16)
                                                .padding(.vertical, 10)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .background(Color.clear)
                                                .id(recordShell.id)

                                            if recordShell.id != section.recordShells.last?.id {
                                                Divider()
                                                    .padding(.leading, 92)
                                            }
                                        }
                                    }
                                    .background(Color.clear)
                                } header: {
                                    sectionHeader(for: section.id)
                                        .id(sectionAnchorID(for: section))
                                }
                            }
                        }
                        .padding(.top, 4)
                        .padding(.bottom, 104)
                    }
                    .background(Color.clear)
                    .task {
                        await scroll(to: selectedDate, using: proxy, animated: false)
                    }
                    .onChange(of: selectedDate) { _, newValue in
                        Task {
                            await scroll(to: newValue, using: proxy, animated: true)
                        }
                    }
                }
            }
        }
        .background(Color.clear)
        .overlay {
            ClearAncestorBackgroundView(clearDescendantScrollViews: true)
                .allowsHitTesting(false)
        }
    }

    private func scroll(to date: Date, using proxy: ScrollViewProxy, animated: Bool) async {
        guard let target = targetScrollID(for: date) else { return }

        try? await Task.sleep(for: .milliseconds(50))
        await MainActor.run {
            if animated {
                withAnimation(.spring(duration: 0.32, bounce: 0.08)) {
                    proxy.scrollTo(target, anchor: .top)
                }
            } else {
                proxy.scrollTo(target, anchor: .top)
            }
        }
    }

    private func targetScrollID(for requestedDate: Date) -> String? {
        guard !daySections.isEmpty else { return nil }

        let targetDay = Calendar.current.startOfDay(for: requestedDate)
        if let exactSection = daySections.first(where: { Calendar.current.isDate($0.id, inSameDayAs: targetDay) }) {
            return sectionAnchorID(for: exactSection)
        }

        return daySections.min {
            abs($0.id.timeIntervalSince(targetDay)) < abs($1.id.timeIntervalSince(targetDay))
        }.map(sectionAnchorID(for:))
    }

    private func sectionAnchorID(for section: MemoryDaySection) -> String {
        "memory-day-\(section.id.timeIntervalSinceReferenceDate)"
    }

    private func sectionHeader(for date: Date) -> some View {
        ZStack(alignment: .leading) {
            Rectangle()
                .fill(.ultraThinMaterial.opacity(0.96))
                .overlay(Color.clear)

            Text(sectionTitle(for: date))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "list.bullet.rectangle")
                .font(.system(size: 42, weight: .regular))
                .foregroundStyle(.secondary.opacity(0.45))

            Text(localization.string("timeline.empty.title", default: "No memories yet"))
                .font(.headline)
                .foregroundStyle(.primary)

            Text(localization.string("timeline.empty.subtitle", default: "Memories captured through the new memory stack will appear here in chronological order."))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private func sectionTitle(for date: Date) -> String {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        if calendar.isDate(date, inSameDayAs: today) {
            return localization.string("content.date.today", default: "Today")
        }

        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        if calendar.isDate(date, inSameDayAs: yesterday) {
            return localization.string("content.date.yesterday", default: "Yesterday")
        }

        return localization.templateDateString(from: date, template: "MMM d EEEE")
    }
}

private struct MemoryDaySection: Identifiable {
    let id: Date
    let recordShells: [RecordShell]
}

private struct MemoryTimelineRow: View {
    @Environment(AppLocalization.self) private var localization
    @Environment(SproutMemoryRepository.self) private var memoryRepository

    let recordShell: RecordShell

    private var memoryView: SproutMemoryRepository.RecordMemoryView? {
        memoryRepository.memoryView(for: recordShell.id)
    }

    private var headlineText: String {
        let trimmed = recordShell.rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            return trimmed
        }
        if let artifactTitle = memoryView?.artifacts.first?.title, !artifactTitle.isEmpty {
            return artifactTitle
        }
        return localization.string("common.memory_shell", default: "Memory Shell")
    }

    private var supportingText: String? {
        if let summary = memoryView?.analysis?.summary, !summary.isEmpty {
            return summary
        }
        if let artifactSummary = memoryView?.artifacts.first(where: { !$0.summary.isEmpty })?.summary {
            return artifactSummary
        }
        return recordShell.inputContext
    }

    private var metaLine: String {
        var labels: [String] = []
        labels.append(recordShell.captureSource.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)
        if let mood = recordShell.userMood, !mood.isEmpty {
            labels.append(mood.capitalized)
        }
        if let firstArtifact = memoryView?.artifacts.first {
            labels.append(firstArtifact.kind.rawValue.capitalized)
        }
        return labels.joined(separator: " · ")
    }

    var body: some View {
        NavigationLink(
            destination: MemoryRecordDetailView(recordID: recordShell.id)
        ) {
            HStack(alignment: .top, spacing: 14) {
                preview

                VStack(alignment: .leading, spacing: 6) {
                    Text(localization.templateDateString(from: recordShell.createdAt, template: "HH:mm"))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)

                    Text(headlineText)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)

                    if let supportingText, !supportingText.isEmpty {
                        Text(supportingText)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)
                    }

                    if !metaLine.isEmpty {
                        Text(metaLine)
                            .font(.caption)
                            .foregroundStyle(.secondary.opacity(0.85))
                            .multilineTextAlignment(.leading)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var preview: some View {
        if let photoArtifact = memoryView?.artifacts.first(where: { $0.kind == .photo }),
           let previewPayload = photoArtifact.previewPayload ?? photoArtifact.binaryPayload,
           let image = UIImage(data: previewPayload) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 62, height: 62)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(previewTint.opacity(0.14))
                .frame(width: 62, height: 62)
                .overlay(
                    Image(systemName: previewSymbol)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(previewTint)
                )
        }
    }

    private var previewSymbol: String {
        guard let kind = memoryView?.artifacts.first?.kind else {
            return "shippingbox"
        }

        switch kind {
        case .text, .decisionNote:
            return "text.alignleft"
        case .link:
            return "link"
        case .todo:
            return "checklist"
        case .music:
            return "music.note"
        case .photo:
            return "photo"
        case .audio:
            return "waveform"
        case .location:
            return "map"
        case .weather:
            return "cloud.sun"
        case .personMention:
            return "person.2"
        case .book:
            return "book"
        case .film:
            return "film"
        case .game:
            return "gamecontroller"
        case .ticket:
            return "ticket"
        case .healthMetric:
            return "heart.text.square"
        }
    }

    private var previewTint: Color {
        guard let kind = memoryView?.artifacts.first?.kind else {
            return .accentColor
        }

        switch kind {
        case .weather:
            return .orange
        case .audio:
            return .orange
        case .music:
            return .pink
        case .location:
            return .green
        case .todo:
            return .accentColor
        case .link:
            return .blue
        case .personMention:
            return .mint
        default:
            return .accentColor
        }
    }
}

import SwiftUI

struct PeopleHomeView: View {
    @Environment(SproutMemoryRepository.self) private var memoryRepository

    private var people: [SproutMemoryRepository.PersonIndexEntry] {
        memoryRepository.peopleIndex()
    }

    private var featuredPerson: SproutMemoryRepository.PersonIndexEntry? {
        people.first
    }

    private var remainingPeople: [SproutMemoryRepository.PersonIndexEntry] {
        Array(people.dropFirst())
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                if let featuredPerson {
                    featuredSection(featuredPerson)
                }
                if !remainingPeople.isEmpty {
                    peopleListSection
                } else if featuredPerson == nil {
                    emptyState
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
            .padding(.bottom, 40)
        }
        .background(Color.clear)
    }

    private func featuredSection(_ person: SproutMemoryRepository.PersonIndexEntry) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Featured Person")
                .font(.headline)

            NavigationLink {
                MemoryEntityDetailView(entityID: person.id)
            } label: {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .top, spacing: 12) {
                        Circle()
                            .fill(person.entity.kind.tintColor.opacity(0.14))
                            .frame(width: 48, height: 48)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundStyle(person.entity.kind.tintColor)
                            )

                        VStack(alignment: .leading, spacing: 4) {
                            Text(person.entity.displayName)
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(.primary)

                            if !person.entity.summary.isEmpty {
                                Text(person.entity.summary)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(3)
                            } else {
                                Text(summaryLine(for: person))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    statRow(for: person)

                    if !person.themeNames.isEmpty {
                        metadataSection(title: "Themes", values: person.themeNames, tint: .orange)
                    }
                    if !person.placeNames.isEmpty {
                        metadataSection(title: "Places", values: person.placeNames, tint: .green)
                    }
                    if !person.arcTitles.isEmpty {
                        metadataSection(title: "Phases", values: person.arcTitles, tint: .blue)
                    }
                }
                .detailCard()
            }
            .buttonStyle(.plain)
        }
    }

    private var peopleListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("People")
                .font(.headline)

            ForEach(remainingPeople, id: \.id) { person in
                NavigationLink {
                    MemoryEntityDetailView(entityID: person.id)
                } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Text(person.entity.displayName)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)

                            Text("Person")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.blue)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.12), in: Capsule())

                            Spacer()

                            if let lastSeenAt = person.lastSeenAt {
                                Text(lastSeenAt.formatted(date: .abbreviated, time: .omitted))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Text(summaryLine(for: person))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)

                        if !person.themeNames.isEmpty {
                            chipRow(person.themeNames, tint: .orange)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(Color.white.opacity(0.78), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var emptyState: some View {
        HomeSectionPlaceholderView(
            systemImage: "person.2",
            title: "People",
            subtitle: "人物页已经接入。等分析沉淀出人物实体后，这里会展示长期关系记忆索引。"
        )
    }

    private func statRow(for person: SproutMemoryRepository.PersonIndexEntry) -> some View {
        HStack(spacing: 12) {
            statCard(title: "Memories", value: "\(person.relatedRecordCount)")
            statCard(title: "Artifacts", value: "\(person.relatedArtifactCount)")
            statCard(title: "Links", value: "\(person.relatedEntityCount)")
        }
    }

    private func statCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.headline)
                .foregroundStyle(.primary)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func metadataSection(title: String, values: [String], tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            chipRow(values, tint: tint)
        }
    }

    private func chipRow(_ values: [String], tint: Color) -> some View {
        FlexibleChipRow(values: values, tint: tint)
    }

    private func summaryLine(for person: SproutMemoryRepository.PersonIndexEntry) -> String {
        var parts: [String] = []
        parts.append("\(person.relatedRecordCount) memories")
        if !person.placeNames.isEmpty {
            parts.append(person.placeNames.joined(separator: ", "))
        }
        if !person.arcTitles.isEmpty {
            parts.append(person.arcTitles.first ?? "")
        }
        return parts.joined(separator: " · ")
    }
}

private struct FlexibleChipRow: View {
    let values: [String]
    let tint: Color

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(values, id: \.self) { value in
                    Text(value)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(tint)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(tint.opacity(0.12), in: Capsule())
                }
            }
        }
    }
}

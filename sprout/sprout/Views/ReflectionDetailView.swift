import SwiftUI
import SwiftData

struct ReflectionDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(SproutMemoryRepository.self) private var memoryRepository

    let reflection: ReflectionSnapshot

    private var linkedArc: TemporalArc? {
        guard let arcID = reflection.linkedTemporalArcID else { return nil }
        return memoryRepository.temporalArc(for: arcID)
    }

    private var relatedRecords: [Record] {
        let records = (try? modelContext.fetch(FetchDescriptor<Record>())) ?? []
        let ids = Set(reflection.sourceRecordIDs)
        return records
            .filter { ids.contains($0.id) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                header
                if let linkedArc {
                    linkedPhaseSection(linkedArc)
                }
                if !relatedRecords.isEmpty {
                    relatedRecordsSection
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
            .padding(.bottom, 40)
        }
        .navigationTitle(reflection.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Phase Reflection")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.purple)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.purple.opacity(0.12), in: Capsule())

            Text(reflection.body)
                .font(.body)
                .foregroundStyle(.primary)

            Text(reflection.createdAt.formatted(date: .abbreviated, time: .shortened))
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .detailCard()
    }

    private func linkedPhaseSection(_ arc: TemporalArc) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Linked Phase")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            NavigationLink {
                TemporalArcDetailView(arc: arc)
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(arc.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(arc.summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .detailCard()
    }

    private var relatedRecordsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Related Memories")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            ForEach(relatedRecords, id: \.id) { record in
                NavigationLink {
                    RecordDetailView(record: record)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(record.body.isEmpty ? "Untitled Memory" : String(record.body.prefix(100)))
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.primary)
                        Text(record.createdAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .detailCard()
    }
}

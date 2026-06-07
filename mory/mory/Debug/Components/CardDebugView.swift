import SwiftUI

struct CardDebugView: View {
    @Environment(\.memoryRepository) private var memoryRepository
    @State private var latestDetail: MemoryDetailSnapshot?
    @State private var overviewMessage = "Loading latest memory..."

    var body: some View {
        List {
            overviewSection

            Section("Debug Surfaces") {
                NavigationLink {
                    CardDebugTypeCatalogView()
                } label: {
                    DebugMenuRow(
                        icon: "list.bullet.rectangle",
                        title: "Type Catalog",
                        subtitle: "Inspect each content type, density, arrangement layer, and rendered object"
                    )
                }

                NavigationLink {
                    CardDebugMasonryBoardLabView()
                } label: {
                    DebugMenuRow(
                        icon: "rectangle.split.3x1",
                        title: "Masonry Board Lab",
                        subtitle: "Inspect fixed column width, adaptive card height, column placement, and sticker overflow"
                    )
                }

                NavigationLink {
                    CardDebugArrangementPlaygroundView()
                } label: {
                    DebugMenuRow(
                        icon: "rectangle.stack.badge.play",
                        title: "Arrangement Playground",
                        subtitle: "Preview order, stack, rotation, z-index, stickers, density, and masonry rendering"
                    )
                }

                NavigationLink {
                    CardDebugMasonryPolicyView()
                } label: {
                    DebugMenuRow(
                        icon: "rectangle.split.3x1.fill",
                        title: "Masonry Policy",
                        subtitle: "Inspect column metrics, density defaults, and object metrics"
                    )
                }

                NavigationLink {
                    CardDebugDensityMatrixView()
                } label: {
                    DebugMenuRow(
                        icon: "rectangle.on.rectangle",
                        title: "Density Matrix",
                        subtitle: "Preview every content kind across simple, standard, and detailed where supported"
                    )
                }

                NavigationLink {
                    CardDebugStatesActionsView()
                } label: {
                    DebugMenuRow(
                        icon: "slider.horizontal.3",
                        title: "Card States & Actions",
                        subtitle: "Switch content kind, density, role, runtime state, capabilities, and derived behavior"
                    )
                }

                NavigationLink {
                    CaptureCardLabView()
                } label: {
                    DebugMenuRow(
                        icon: "rectangle.stack",
                        title: "Fixture Stress Lab",
                        subtitle: "Existing fixture lab for weather, music, place, states, origins, and edge cases"
                    )
                }
            }
        }
        .navigationTitle("Card Debug")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            loadOverview()
        }
    }

    private var overviewSection: some View {
        Section {
            Button {
                loadOverview()
            } label: {
                Label("Refresh latest memory", systemImage: "arrow.clockwise")
            }

            if let latestDetail {
                DebugValueRow(title: "Record", value: latestDetail.record.id.uuidString)
                DebugValueRow(title: "Artifacts", value: "\(latestDetail.artifacts.count)")
                DebugValueRow(title: "Semantic digests", value: "\(latestDetail.artifactSemanticDigests.count)")
                DebugValueRow(title: "Arrangement nodes", value: "\(latestDetail.cardArrangement?.nodes.count ?? 0)")
                DebugValueRow(title: "Pipeline", value: latestDetail.pipelineStatus?.stage.rawValue ?? "nil")
                DebugValueRow(title: "Updated", value: latestDetail.record.updatedAt.formatted(date: .abbreviated, time: .shortened))
            } else {
                Text(overviewMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Overview")
        } footer: {
            Text("Overview reads the latest saved memory. Fixture pages below do not save or mutate data.")
        }
    }

    private func loadOverview() {
        do {
            guard let latest = try memoryRepository.fetchRecentMemories(limit: 1).first else {
                latestDetail = nil
                overviewMessage = "No saved memories yet. Use Type Catalog and Density Matrix for fixture-only checks."
                return
            }
            latestDetail = try memoryRepository.fetchMemoryDetail(recordID: latest.id)
            overviewMessage = latestDetail == nil
                ? "Latest memory summary exists, but detail snapshot was unavailable."
                : "Loaded latest memory."
        } catch {
            latestDetail = nil
            overviewMessage = error.localizedDescription
        }
    }
}

private struct CardDebugTypeCatalogView: View {
    var body: some View {
        List {
            Section {
                ForEach(CardDebugCatalog.typeCatalogEntries) { entry in
                    NavigationLink {
                        CardDebugTypeDetailView(entry: entry)
                    } label: {
                        DebugMenuRow(
                            icon: entry.fixture.contentKind.symbolName,
                            title: entry.contentType,
                            subtitle: "kind=\(entry.fixture.contentKind.rawValue) · density=\(entry.fixture.preferredDensity.rawValue)"
                        )
                    }
                }
            } footer: {
                Text("Affect, status, and bundle entries are presentation/debug nodes when they are not direct Artifact rows.")
            }
        }
        .navigationTitle("Type Catalog")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct CardDebugTypeDetailView: View {
    let entry: CardDebugTypeCatalogEntry

    var body: some View {
        List {
            Section("Rendered Densities") {
                ForEach(CardDebugCatalog.contentDensityFixtures.filter { $0.fixture.contentKind == entry.fixture.contentKind }) { fixture in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Spacer()
                            CaptureCardView(presentation: presentation(density: fixture.density))
                            Spacer()
                        }
                        let metrics = fixture.metrics
                        Text("\(fixture.density.rawValue) · object \(Int(metrics.preferredSize.width))x\(Int(metrics.preferredSize.height)) · lines \(metrics.titleLineLimit)/\(metrics.detailLineLimit)/\(metrics.metadataLineLimit)")
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                    .padding(.vertical, 12)
                }
            }

            Section("Four-layer Path") {
                DebugValueRow(title: "Draft", value: entry.draftLayer)
                DebugValueRow(title: "Artifact", value: entry.artifactLayer)
                DebugValueRow(title: "Digest", value: entry.digestLayer)
                DebugValueRow(title: "Arrangement", value: entry.arrangementLayer)
            }

            Section("Checks") {
                let metrics = MemoryCardObjectMetrics.resolve(
                    contentKind: entry.fixture.contentKind,
                    density: entry.fixture.preferredDensity
                )
                DebugValueRow(
                    title: "Object metrics",
                    value: "\(Int(metrics.preferredSize.width))x\(Int(metrics.preferredSize.height)) · padding \(Int(metrics.padding.top))/\(Int(metrics.padding.leading)) · lines \(metrics.titleLineLimit)/\(metrics.detailLineLimit)/\(metrics.metadataLineLimit)"
                )
                ForEach(entry.fixture.layerNotes, id: \.self) { note in
                    Label(note, systemImage: "checkmark.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(entry.contentType)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func presentation(density: MemoryCardContentDensity) -> CaptureCardPresentation {
        CaptureCardPresentation(
            item: entry.fixture.item,
            role: .debugLab,
            provenanceDisplayMode: .debug,
            contentDensity: density
        )
    }
}

private struct CardDebugArrangementPlaygroundView: View {
    private let snapshot = CardDebugCatalog.arrangementPlaygroundSnapshot()
    private var nodes: [MemoryCardNode] {
        MemoryDeskRenderPlan.nodes(for: snapshot)
    }
    private var report: CardDebugArrangementReport {
        CardDebugArrangementReport.make(nodes: nodes, artifacts: snapshot.artifacts)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("In-memory MemoryDetailSnapshot rendered through MemoryDeskRenderer. No repository writes.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                MemoryDeskRenderer(snapshot: snapshot)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Masonry")
                        .font(.headline)
                    DebugValueRow(title: "Columns", value: "\(report.columnCount)")
                    DebugValueRow(title: "Column width", value: "\(Int(report.columnWidth))")
                    DebugValueRow(title: "Board height", value: "\(Int(report.boardHeight))")
                    DebugValueRow(title: "Sticker overflow", value: "\(Int(report.stickerOverflow))")
                }
                .padding(.horizontal, 20)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Slots")
                        .font(.headline)
                    ForEach(report.slots) { slot in
                        Text(slot.debugLine)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
        .navigationTitle("Arrangement")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct CardDebugDensityMatrixView: View {
    var body: some View {
        List {
            ForEach(CardDebugCatalog.contentFixtures) { fixture in
                Section {
                    ForEach(CardDebugCatalog.contentDensityFixtures.filter { $0.fixture.contentKind == fixture.contentKind }) { densityFixture in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Spacer()
                                CaptureCardView(
                                    presentation: CaptureCardPresentation(
                                        item: fixture.item,
                                        role: .debugLab,
                                        provenanceDisplayMode: .debug,
                                        contentDensity: densityFixture.density
                                    )
                                )
                                Spacer()
                            }
                            let metrics = densityFixture.metrics
                            Text("\(densityFixture.density.rawValue) · object \(Int(metrics.preferredSize.width))x\(Int(metrics.preferredSize.height)) · lines \(metrics.titleLineLimit)/\(metrics.detailLineLimit)/\(metrics.metadataLineLimit)")
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 12)
                    }

                    DebugValueRow(title: "Content kind", value: fixture.contentKind.rawValue)
                    DebugValueRow(title: "Preferred density", value: fixture.preferredDensity.rawValue)
                    DebugValueRow(
                        title: "Supported densities",
                        value: MemoryCardPresentationPolicy.supportedDensities(for: fixture.contentKind).map(\.rawValue).joined(separator: ", ")
                    )
                    DebugValueRow(title: "Payload kind", value: fixture.item.kind.rawValue)
                } header: {
                    Text(fixture.contentKind.rawValue)
                }
            }
        }
        .navigationTitle("Density Matrix")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct CardDebugMasonryPolicyView: View {
    private let metrics = MoryMasonryMetrics.default

    var body: some View {
        List {
            Section("Column Metrics") {
                DebugValueRow(title: "Column width", value: "\(Int(metrics.minColumnWidth))...\(Int(metrics.maxColumnWidth))")
                DebugValueRow(title: "Spacing", value: "columns \(Int(metrics.columnSpacing)) · rows \(Int(metrics.rowSpacing))")
                DebugValueRow(title: "Padding", value: "h \(Int(metrics.horizontalPadding)) · v \(Int(metrics.verticalPadding))")
                DebugValueRow(title: "Sticker overflow", value: "\(Int(metrics.stickerOverflow))")
            }

            Section("Density Defaults") {
                ForEach(MemoryCardContentKind.allCases) { contentKind in
                    DebugValueRow(
                        title: contentKind.rawValue,
                        value: "default=\(MemoryCardPresentationPolicy.defaultDensity(for: contentKind).rawValue) · supported=\(MemoryCardPresentationPolicy.supportedDensities(for: contentKind).map(\.rawValue).joined(separator: ", "))"
                    )
                }
            }

            Section("Object Metrics") {
                ForEach(CardDebugCatalog.contentFixtures) { fixture in
                    let metrics = MemoryCardObjectMetrics.resolve(contentKind: fixture.contentKind, density: fixture.preferredDensity)
                    DebugValueRow(
                        title: "\(fixture.contentKind.rawValue).\(fixture.preferredDensity.rawValue)",
                        value: "\(Int(metrics.preferredSize.width))x\(Int(metrics.preferredSize.height)) · padding \(Int(metrics.padding.top)) · lines \(metrics.titleLineLimit)/\(metrics.detailLineLimit)/\(metrics.metadataLineLimit)"
                    )
                }
            }
        }
        .navigationTitle("Masonry Policy")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private extension MemoryCardContentKind {
    var symbolName: String {
        switch self {
        case .recordBody, .prompt: return "note.text"
        case .photo: return "photo"
        case .video: return "film"
        case .livePhoto: return "livephoto"
        case .audio: return "waveform"
        case .music: return "music.note"
        case .place: return "map"
        case .weather: return "cloud.sun"
        case .link: return "link"
        case .todo: return "checklist"
        case .person: return "person.crop.rectangle"
        case .affect: return "heart.text.square"
        case .journalingSuggestion: return "sparkles.rectangle.stack"
        case .bundle: return "shippingbox"
        case .status: return "info.circle"
        }
    }
}

private extension MemoryCardNode {
    var debugLine: String {
        "order=\(layout.order) density=\(contentDensity.rawValue) z=\(layout.zIndex) stickers=\(layout.stickers.count) ref=\(contentRef.debugLabel)"
    }
}

private extension MemoryDeskBoardLayoutSlot {
    var debugLine: String {
        "order=\(layout.order) column=\(column) frame=(\(Int(frame.origin.x)),\(Int(frame.origin.y))) \(Int(frame.width))x\(Int(frame.height))"
    }
}

private extension MemoryCardContentRef {
    var debugLabel: String {
        switch self {
        case .recordBody:
            return "recordBody"
        case let .artifact(id):
            return "artifact(\(id.uuidString.prefix(8)))"
        case let .artifactGroup(ids, kind):
            return "artifactGroup(\(ids.count), \(kind.rawValue))"
        case let .affect(id):
            return "affect(\(id.uuidString.prefix(8)))"
        case let .journalingSuggestion(id):
            return "journalingSuggestion(\(id.uuidString.prefix(8)))"
        }
    }
}

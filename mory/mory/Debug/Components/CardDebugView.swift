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
                        subtitle: "Inspect each content type as draft, artifact, digest, arrangement, and rendered object"
                    )
                }

                NavigationLink {
                    CardDebugArrangementPlaygroundView()
                } label: {
                    DebugMenuRow(
                        icon: "rectangle.stack.badge.play",
                        title: "Arrangement Playground",
                        subtitle: "Preview order, size tokens, stack, rotation, z-index, and desk rendering"
                    )
                }

                NavigationLink {
                    CardDebugLayoutPolicyView()
                } label: {
                    DebugMenuRow(
                        icon: "square.grid.3x3",
                        title: "Layout Policy",
                        subtitle: "Inspect 6-column grid tokens, supported recipe sizes, and cassette strip/tape/banner fixtures"
                    )
                }

                NavigationLink {
                    CardDebugVisualRecipesView()
                } label: {
                    DebugMenuRow(
                        icon: "rectangle.on.rectangle.angled",
                        title: "Visual Recipes",
                        subtitle: "Preview every MemoryCardVisualRecipe as a desktop object"
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

            Section("Legacy Labs") {
                NavigationLink {
                    SkeuomorphicCardLabView()
                } label: {
                    DebugMenuRow(
                        icon: "archivebox",
                        title: "Legacy Skeuomorphic Lab",
                        subtitle: "Old focused recipe lab kept as a reference while Card Debug becomes the main entry"
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
                overviewMessage = "No saved memories yet. Use Type Catalog and Visual Recipes for fixture-only checks."
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
                        let supported = entry.fixture.supportedSizes.map(\.rawValue).joined(separator: ", ")
                        DebugMenuRow(
                            icon: entry.fixture.recipe.symbolName,
                            title: entry.contentType,
                            subtitle: "recipe=\(entry.fixture.recipe.rawValue) · default=\(entry.fixture.preferredSize.rawValue) · supported=\(supported)"
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
            Section("Rendered Sizes") {
                ForEach(entry.fixture.supportedSizes) { size in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Spacer()
                            CaptureCardView(presentation: presentation(size: size))
                            Spacer()
                        }
                        let box = MemoryCardRecipeLayoutPolicy.gridBox(for: size)
                        let metrics = MemoryCardObjectMetrics.resolve(
                            recipe: entry.fixture.recipe,
                            sizeToken: size
                        )
                        Text("\(size.rawValue) · grid \(box.columnSpan)x\(box.rowSpan) · object \(Int(metrics.preferredSize.width))x\(Int(metrics.preferredSize.height)) · density \(metrics.density.rawValue)")
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
                    recipe: entry.fixture.recipe,
                    sizeToken: entry.fixture.preferredSize
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

    private func presentation(size: MemoryCardSizeToken) -> CaptureCardPresentation {
        CaptureCardPresentation(
            item: entry.fixture.item,
            role: .debugLab,
            provenanceDisplayMode: .debug,
            surfaceMode: .skeuomorphic,
            visualRecipe: entry.fixture.recipe,
            sizeToken: size
        )
    }
}

private struct CardDebugArrangementPlaygroundView: View {
    private let snapshot = CardDebugCatalog.arrangementPlaygroundSnapshot()
    private var nodes: [MemoryCardNode] {
        MemoryDeskRenderPlan.nodes(for: snapshot)
    }
    private var report: CardDebugArrangementReport {
        CardDebugArrangementReport.make(nodes: nodes)
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
                    Text("Occupancy")
                        .font(.headline)
                    DebugValueRow(title: "Rows", value: "\(report.rowCount)")
                    DebugValueRow(title: "Cells", value: "\(report.occupiedCells)/\(report.totalCells)")
                    DebugValueRow(title: "Density", value: report.densityLabel)
                    DebugValueRow(title: "Overlaps", value: "\(report.overlapCount)")
                    DebugValueRow(title: "Overflowing objects", value: "\(report.slots.filter(\.hasOverflow).count)")
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

private struct CardDebugVisualRecipesView: View {
    var body: some View {
        List {
            ForEach(CardDebugCatalog.recipeFixtures) { fixture in
                Section {
                    ForEach(CardDebugCatalog.recipeSizeFixtures.filter { $0.fixture.recipe == fixture.recipe }) { recipeSizeFixture in
                        let size = recipeSizeFixture.size
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Spacer()
                                CaptureCardView(
                                    presentation: CaptureCardPresentation(
                                        item: fixture.item,
                                        role: .debugLab,
                                        provenanceDisplayMode: .debug,
                                        surfaceMode: .skeuomorphic,
                                        visualRecipe: fixture.recipe,
                                        sizeToken: size
                                    )
                                )
                                Spacer()
                            }
                            let box = MemoryCardRecipeLayoutPolicy.gridBox(for: size)
                            let metrics = recipeSizeFixture.metrics
                            Text("\(size.rawValue) · grid \(box.columnSpan)x\(box.rowSpan) · object \(Int(metrics.preferredSize.width))x\(Int(metrics.preferredSize.height)) · lines \(metrics.titleLineLimit)/\(metrics.detailLineLimit)/\(metrics.metadataLineLimit)")
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 12)
                    }

                    DebugValueRow(title: "Recipe", value: fixture.recipe.rawValue)
                    DebugValueRow(title: "Preferred size", value: fixture.preferredSize.rawValue)
                    DebugValueRow(title: "Supported sizes", value: fixture.supportedSizes.map(\.rawValue).joined(separator: ", "))
                    DebugValueRow(title: "Kind", value: fixture.item.kind.rawValue)
                } header: {
                    Text(fixture.recipe.rawValue)
                }
            }
        }
        .navigationTitle("Visual Recipes")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct CardDebugLayoutPolicyView: View {
    private let cassetteFixture = CardDebugCatalog.fixture(for: .cassette)

    var body: some View {
        List {
            Section("Grid Tokens") {
                ForEach(MemoryCardSizeToken.allCases) { size in
                    let box = MemoryCardRecipeLayoutPolicy.gridBox(for: size)
                    DebugValueRow(
                        title: size.rawValue,
                        value: "\(box.columnSpan)x\(box.rowSpan) · \(MemoryCardRecipeLayoutPolicy.contentDensity(for: size).rawValue)"
                    )
                }
            }

            Section("Recipe Support") {
                ForEach(MemoryCardVisualRecipe.allCases) { recipe in
                    DebugValueRow(
                        title: recipe.rawValue,
                        value: MemoryCardRecipeLayoutPolicy.supportedSizes(for: recipe).map(\.rawValue).joined(separator: ", ")
                    )
                }
            }

            Section("Cassette Fixtures") {
                ForEach(cassetteFixture.supportedSizes) { size in
                    HStack {
                        Spacer()
                        CaptureCardView(
                            presentation: CaptureCardPresentation(
                                item: cassetteFixture.item,
                                role: .debugLab,
                                provenanceDisplayMode: .debug,
                                surfaceMode: .skeuomorphic,
                                visualRecipe: .cassette,
                                sizeToken: size
                            )
                        )
                        Spacer()
                    }
                    .padding(.vertical, 10)
                    .overlay(alignment: .topLeading) {
                        let metrics = MemoryCardObjectMetrics.resolve(recipe: .cassette, sizeToken: size)
                        Text("\(size.rawValue) object \(Int(metrics.preferredSize.width))x\(Int(metrics.preferredSize.height))")
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Object Metrics") {
                ForEach(CardDebugCatalog.recipeFixtures) { fixture in
                    let size = fixture.preferredSize
                    let metrics = MemoryCardObjectMetrics.resolve(recipe: fixture.recipe, sizeToken: size)
                    DebugValueRow(
                        title: "\(fixture.recipe.rawValue).\(size.rawValue)",
                        value: "\(Int(metrics.preferredSize.width))x\(Int(metrics.preferredSize.height)) · padding \(Int(metrics.padding.top)) · lines \(metrics.titleLineLimit)/\(metrics.detailLineLimit)/\(metrics.metadataLineLimit)"
                    )
                }
            }
        }
        .navigationTitle("Layout Policy")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private extension MemoryCardVisualRecipe {
    var symbolName: String {
        switch self {
        case .notebook:
            return "note.text"
        case .polaroid:
            return "photo"
        case .filmFrame:
            return "film"
        case .livePhotoPrint:
            return "livephoto"
        case .cassette:
            return "waveform"
        case .vinyl:
            return "music.note"
        case .mapTicket:
            return "map"
        case .weatherStamp:
            return "cloud.sun"
        case .linkNote:
            return "link"
        case .taskNote:
            return "checklist"
        case .personCard:
            return "person.crop.rectangle"
        case .affectCard:
            return "heart.text.square"
        case .bundlePacket:
            return "shippingbox"
        case .statusNote:
            return "info.circle"
        }
    }
}

private extension MemoryCardNode {
    var debugLine: String {
        let placement = layout.gridPlacement.map { "c\($0.column)r\($0.row)" } ?? "nil"
        return "order=\(layout.order) size=\(layout.size.rawValue) grid=\(placement) recipe=\(visualRecipe.rawValue) z=\(layout.zIndex) ref=\(contentRef.debugLabel)"
    }
}

private extension MemoryDeskBoardLayoutSlot {
    var debugLine: String {
        let placement = layout.gridPlacement.map { "c\($0.column)r\($0.row)" } ?? "nil"
        return "order=\(layout.order) size=\(layout.size.rawValue) grid=\(placement) frame=(\(Int(frame.origin.x)),\(Int(frame.origin.y))) \(Int(frame.width))x\(Int(frame.height))"
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

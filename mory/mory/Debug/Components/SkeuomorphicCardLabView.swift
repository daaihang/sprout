import SwiftUI

struct SkeuomorphicCardLabView: View {
    @State private var selectedSurfaceMode: CaptureCardSurfaceMode = .skeuomorphic
    @State private var selectedProvenanceDisplayMode: CaptureCardProvenanceDisplayMode = .debug
    @State private var showsLayoutGuides = false

    var body: some View {
        List {
            controlsSection

            polaroidSection
            cassetteSection
            notebookSection
            vinylSection
            comparisonSection
        }
        .navigationTitle("Skeuomorphic Card Lab")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var controlsSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 14) {
                Picker("Surface Mode", selection: $selectedSurfaceMode) {
                    ForEach(CaptureCardSurfaceMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                Toggle("Show layout guides", isOn: $showsLayoutGuides)

                Text("Preview skeuomorphic card styles using fixture data. Toggle surface mode to compare with standard cards.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Controls")
        }
    }

    private var polaroidSection: some View {
        labSection(
            title: "Polaroid",
            subtitle: "Photo cards rendered as instant film prints with white borders, tilt, and handwritten labels.",
            items: polaroidFixtures
        )
    }

    private var cassetteSection: some View {
        labSection(
            title: "Cassette Tape",
            subtitle: "Audio cards rendered as compact cassette bodies with tape reels and vintage label areas.",
            items: cassetteFixtures
        )
    }

    private var notebookSection: some View {
        labSection(
            title: "Notebook",
            subtitle: "Todo, link, and prompt cards rendered as lined notebook pages with margin rules.",
            items: notebookFixtures
        )
    }

    private var vinylSection: some View {
        labSection(
            title: "Vinyl Record",
            subtitle: "Music cards rendered as vinyl discs with grooves, center labels, and album sleeves.",
            items: vinylFixtures
        )
    }

    private var comparisonSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                Text("Side-by-side comparison of standard vs. skeuomorphic rendering for each supported type.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ScrollView(.horizontal) {
                    HStack(spacing: 20) {
                        ForEach(CaptureCardLabFixtures.allTypes.filter { supportedForSkeuomorphic($0) }) { item in
                            VStack(spacing: 8) {
                                CaptureCardView(
                                    presentation: presentation(item, surfaceMode: .standard)
                                )

                                CaptureCardView(
                                    presentation: presentation(item, surfaceMode: .skeuomorphic)
                                )

                                Text(item.kind.label)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                .scrollIndicators(.hidden)
            }
            .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 12, trailing: 0))
        } header: {
            Text("Comparison")
        }
    }

    // MARK: - Helpers

    private func labSection(title: String, subtitle: String, items: [CaptureCardItem]) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                ScrollView(.horizontal) {
                    LazyHStack(spacing: 16) {
                        ForEach(items) { item in
                            CaptureCardView(
                                presentation: presentation(item, surfaceMode: selectedSurfaceMode)
                            )
                            .scrollTransition(.animated, axis: .horizontal) { content, phase in
                                content
                                    .scaleEffect(phase.isIdentity ? 1 : 0.965)
                                    .opacity(phase.isIdentity ? 1 : 0.82)
                            }
                        }
                    }
                    .scrollTargetLayout()
                    .padding(.vertical, 8)
                }
                .scrollIndicators(.hidden)
                .scrollTargetBehavior(.viewAligned)
            }
            .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 12, trailing: 0))
        } header: {
            Text(title)
        }
    }

    private func presentation(_ item: CaptureCardItem, surfaceMode: CaptureCardSurfaceMode) -> CaptureCardPresentation {
        .debug(
            item,
            provenanceDisplayMode: selectedProvenanceDisplayMode,
            showsLayoutGuides: showsLayoutGuides,
            surfaceMode: surfaceMode
        )
    }

    private func supportedForSkeuomorphic(_ item: CaptureCardItem) -> Bool {
        switch item.kind {
        case .photo, .audio, .music, .todo, .link, .prompt:
            return true
        default:
            return false
        }
    }

    // MARK: - Fixtures

    private var polaroidFixtures: [CaptureCardItem] {
        [
            CaptureCardItem(
                id: "skeuo-polaroid-1",
                payload: .photo(CapturePhotoCardPayload()),
                title: "Sunday morning",
                detail: "Golden light through the kitchen window",
                metadata: "9:32 AM"
            ),
            CaptureCardItem(
                id: "skeuo-polaroid-2",
                payload: .photo(CapturePhotoCardPayload(photoCount: 3, groupStyle: .mosaic)),
                title: "Park walk",
                detail: "The leaves are turning",
                metadata: "Oct 14"
            ),
            CaptureCardItem(
                id: "skeuo-polaroid-3",
                payload: .photo(CapturePhotoCardPayload()),
                origin: .context,
                title: nil,
                detail: "No title, context origin",
                metadata: nil
            ),
        ]
    }

    private var cassetteFixtures: [CaptureCardItem] {
        [
            CaptureCardItem(
                id: "skeuo-cassette-1",
                payload: .audio(CaptureAudioCardPayload(durationSeconds: 74)),
                title: "Voice memo #12",
                detail: "Meeting notes with the team about Q3 planning",
                metadata: "1:14"
            ),
            CaptureCardItem(
                id: "skeuo-cassette-2",
                payload: .audio(CaptureAudioCardPayload(durationSeconds: 312)),
                title: "Interview recording",
                detail: "Call with design candidate",
                metadata: "5:12"
            ),
            CaptureCardItem(
                id: "skeuo-cassette-3",
                payload: .audio(CaptureAudioCardPayload()),
                title: nil,
                detail: "No title, no duration",
                metadata: nil
            ),
        ]
    }

    private var notebookFixtures: [CaptureCardItem] {
        [
            CaptureCardItem(
                id: "skeuo-notebook-todo",
                payload: .todo(CaptureTodoCardPayload()),
                title: "Grocery list",
                detail: "Eggs, milk, bread, avocados, coffee beans"
            ),
            CaptureCardItem(
                id: "skeuo-notebook-link",
                payload: .link(CaptureLinkCardPayload()),
                title: "SwiftUI Layout Protocol",
                detail: "developer.apple.com/documentation/swiftui/layout",
                metadata: "developer.apple.com"
            ),
            CaptureCardItem(
                id: "skeuo-notebook-prompt",
                payload: .prompt(CapturePromptCardPayload(
                    prompt: "What made today meaningful?",
                    answer: "I finally finished the card redesign and it felt great to see it come together."
                )),
                title: "Daily reflection",
                detail: "What made today meaningful?"
            ),
            CaptureCardItem(
                id: "skeuo-notebook-todo-selected",
                payload: .todo(CaptureTodoCardPayload()),
                title: "Done task",
                detail: "Review pull request for notification refactor",
                isSelected: true
            ),
        ]
    }

    private var vinylFixtures: [CaptureCardItem] {
        [
            CaptureCardItem(
                id: "skeuo-vinyl-1",
                payload: .music(CaptureMusicCardPayload(durationSeconds: 244, playbackState: .playing)),
                origin: .context,
                title: "Midnight City",
                detail: "M83 · Hurry Up, We're Dreaming"
            ),
            CaptureCardItem(
                id: "skeuo-vinyl-2",
                payload: .music(CaptureMusicCardPayload(durationSeconds: 186)),
                title: "Space Song",
                detail: "Beach House · Depression Cherry"
            ),
            CaptureCardItem(
                id: "skeuo-vinyl-3",
                payload: .music(CaptureMusicCardPayload()),
                title: nil,
                detail: "Unknown artist",
                metadata: nil
            ),
        ]
    }
}

import SwiftUI

enum CardDebugRoleOption: String, CaseIterable, Identifiable {
    case composer
    case detailViewing
    case detailEditing
    case debug

    var id: String { rawValue }

    var label: String {
        switch self {
        case .composer: return "composer"
        case .detailViewing: return "detail viewing"
        case .detailEditing: return "detail editing"
        case .debug: return "debug"
        }
    }

    var role: CaptureCardRole {
        switch self {
        case .composer: return .composerEditing
        case .detailViewing: return .detailViewing
        case .detailEditing: return .detailEditing
        case .debug: return .debugLab
        }
    }
}

enum CardDebugRuntimeStateOption: String, CaseIterable, Identifiable {
    case normal
    case loading
    case error
    case disabled
    case selected

    var id: String { rawValue }
    var label: String { rawValue }

    var state: CaptureCardState {
        switch self {
        case .normal, .selected: return .normal
        case .loading: return .loading
        case .error: return .error
        case .disabled: return .disabled
        }
    }

    var isSelected: Bool { self == .selected }

    func apply(to item: CaptureCardItem) -> CaptureCardItem {
        var next = item
        next.state = state
        next.isSelected = isSelected
        return next
    }
}

struct CardDebugCapabilityRow: Identifiable, Hashable {
    var id: String { title }
    let title: String
    let isEnabled: Bool
}

enum CardDebugStatesActionsModel {
    static var contentKindOptions: [MemoryCardContentKind] {
        CardDebugCatalog.contentFixtures.map(\.contentKind)
    }

    static func fixture(for contentKind: MemoryCardContentKind) -> CardDebugContentFixture {
        CardDebugCatalog.fixture(for: contentKind)
    }

    static func supportedDensities(for contentKind: MemoryCardContentKind) -> [MemoryCardContentDensity] {
        MemoryCardPresentationPolicy.supportedDensities(for: contentKind)
    }

    static func item(
        contentKind: MemoryCardContentKind,
        runtimeState: CardDebugRuntimeStateOption
    ) -> CaptureCardItem {
        runtimeState.apply(to: fixture(for: contentKind).item)
    }

    static func presentation(
        contentKind: MemoryCardContentKind,
        density: MemoryCardContentDensity,
        role: CardDebugRoleOption,
        runtimeState: CardDebugRuntimeStateOption
    ) -> CaptureCardPresentation {
        CaptureCardPresentation(
            item: item(contentKind: contentKind, runtimeState: runtimeState),
            role: role.role,
            provenanceDisplayMode: .debug,
            contentKind: contentKind,
            contentDensity: density
        )
    }

    static func capabilityRows(for presentation: CaptureCardPresentation) -> [CardDebugCapabilityRow] {
        [
            CardDebugCapabilityRow(title: "open", isEnabled: presentation.capabilities.canOpen),
            CardDebugCapabilityRow(title: "remove", isEnabled: presentation.capabilities.canRemove),
            CardDebugCapabilityRow(title: "reorder", isEnabled: presentation.capabilities.canReorder),
            CardDebugCapabilityRow(title: "select", isEnabled: presentation.capabilities.canSelect),
            CardDebugCapabilityRow(title: "retry", isEnabled: presentation.capabilities.canRetry),
        ]
    }

    static func derivedBehaviorRows(for presentation: CaptureCardPresentation) -> [CardDebugCapabilityRow] {
        [
            CardDebugCapabilityRow(title: "allowsPrimaryAction", isEnabled: presentation.allowsPrimaryAction),
            CardDebugCapabilityRow(title: "displaysRemoveControl", isEnabled: presentation.displaysRemoveControl),
            CardDebugCapabilityRow(title: "displaysSelection", isEnabled: presentation.displaysSelection),
            CardDebugCapabilityRow(title: "hasTrailingControl", isEnabled: presentation.hasTrailingControl),
        ]
    }
}

struct CardDebugStatesActionsView: View {
    @State private var selectedContentKind: MemoryCardContentKind = .audio
    @State private var selectedDensity: MemoryCardContentDensity = MemoryCardPresentationPolicy.defaultDensity(for: .audio)
    @State private var selectedRole: CardDebugRoleOption = .composer
    @State private var selectedRuntimeState: CardDebugRuntimeStateOption = .normal
    @State private var tapCount = 0
    @State private var removeCount = 0

    private var supportedDensities: [MemoryCardContentDensity] {
        CardDebugStatesActionsModel.supportedDensities(for: selectedContentKind)
    }

    private var presentation: CaptureCardPresentation {
        CardDebugStatesActionsModel.presentation(
            contentKind: selectedContentKind,
            density: selectedDensity,
            role: selectedRole,
            runtimeState: selectedRuntimeState
        )
    }

    var body: some View {
        List {
            selectorSection
            previewSection
            capabilitiesSection
            derivedBehaviorSection
            contractSection
        }
        .navigationTitle("Card States & Actions")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: selectedContentKind) { _, newKind in
            selectedDensity = MemoryCardPresentationPolicy.normalizedDensity(selectedDensity, for: newKind)
        }
    }

    private var selectorSection: some View {
        Section {
            Picker("Content kind", selection: $selectedContentKind) {
                ForEach(CardDebugStatesActionsModel.contentKindOptions) { kind in
                    Text(kind.rawValue).tag(kind)
                }
            }

            Picker("Density", selection: $selectedDensity) {
                ForEach(supportedDensities) { density in
                    Text(density.rawValue).tag(density)
                }
            }

            Picker("Role", selection: $selectedRole) {
                ForEach(CardDebugRoleOption.allCases) { role in
                    Text(role.label).tag(role)
                }
            }

            Picker("Runtime state", selection: $selectedRuntimeState) {
                ForEach(CardDebugRuntimeStateOption.allCases) { runtimeState in
                    Text(runtimeState.label).tag(runtimeState)
                }
            }
        } header: {
            Text("Selectors")
        } footer: {
            Text("Density controls internal information density only. Masonry column width controls layout frame.")
        }
    }

    private var previewSection: some View {
        Section("Preview") {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Spacer()
                    CaptureCardView(
                        presentation: presentation,
                        onTap: { tapCount += 1 },
                        onRemove: { removeCount += 1 }
                    )
                    Spacer()
                }
                .padding(.vertical, 10)

                let metrics = MemoryCardObjectMetrics.resolve(
                    contentKind: selectedContentKind,
                    density: presentation.contentDensity,
                    mediaAspectRatio: presentation.item.payload.mediaAspectRatio
                )
                DebugValueRow(title: "Presentation role", value: presentation.role.rawValue)
                DebugValueRow(title: "Runtime state", value: presentation.item.state.rawValue)
                DebugValueRow(title: "Selected", value: presentation.item.isSelected ? "true" : "false")
                DebugValueRow(title: "Object metrics", value: "\(Int(metrics.preferredSize.width))x\(Int(metrics.preferredSize.height)) · \(metrics.density.rawValue)")
                DebugValueRow(title: "Tap callback count", value: "\(tapCount)")
                DebugValueRow(title: "Remove callback count", value: "\(removeCount)")
            }
        }
    }

    private var capabilitiesSection: some View {
        Section {
            ForEach(CardDebugStatesActionsModel.capabilityRows(for: presentation)) { row in
                CardDebugBooleanRow(row: row)
            }
        } header: {
            Text("Capabilities")
        }
    }

    private var derivedBehaviorSection: some View {
        Section {
            ForEach(CardDebugStatesActionsModel.derivedBehaviorRows(for: presentation)) { row in
                CardDebugBooleanRow(row: row)
            }
        } header: {
            Text("Derived Behavior")
        }
    }

    private var contractSection: some View {
        Section("Contract Notes") {
            DebugValueRow(title: "Source fixture", value: CardDebugStatesActionsModel.fixture(for: selectedContentKind).item.id)
            DebugValueRow(title: "Content kind", value: selectedContentKind.rawValue)
            DebugValueRow(title: "Density", value: presentation.contentDensity.rawValue)
            DebugValueRow(title: "canRetry gap", value: presentation.capabilities.canRetry ? "available" : "not wired")
        }
    }
}

private struct CardDebugBooleanRow: View {
    let row: CardDebugCapabilityRow

    var body: some View {
        HStack {
            Text(row.title)
            Spacer()
            Label(row.isEnabled ? "true" : "false", systemImage: row.isEnabled ? "checkmark.circle.fill" : "xmark.circle")
                .font(.caption.weight(.semibold))
                .foregroundStyle(row.isEnabled ? .green : .secondary)
        }
    }
}

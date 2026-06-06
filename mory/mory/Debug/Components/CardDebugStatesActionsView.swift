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
    static var recipeOptions: [MemoryCardVisualRecipe] {
        CardDebugCatalog.recipeFixtures.map(\.recipe)
    }

    static func fixture(for recipe: MemoryCardVisualRecipe) -> CardDebugRecipeFixture {
        CardDebugCatalog.fixture(for: recipe)
    }

    static func supportedDensities(for recipe: MemoryCardVisualRecipe) -> [MemoryCardContentDensity] {
        MemoryCardRecipeLayoutPolicy.supportedDensities(for: recipe)
    }

    static func supportedVariants(
        for recipe: MemoryCardVisualRecipe,
        density: MemoryCardContentDensity
    ) -> [MemoryCardVisualVariant] {
        MemoryCardRecipeLayoutPolicy.supportedVariants(for: recipe, density: density)
    }

    static func normalizedVariant(
        _ variant: MemoryCardVisualVariant,
        for recipe: MemoryCardVisualRecipe,
        density: MemoryCardContentDensity
    ) -> MemoryCardVisualVariant {
        MemoryCardRecipeLayoutPolicy.resolvedVariant(
            variant == .automatic ? nil : variant,
            for: recipe,
            density: density
        )
    }

    static func item(
        recipe: MemoryCardVisualRecipe,
        runtimeState: CardDebugRuntimeStateOption
    ) -> CaptureCardItem {
        runtimeState.apply(to: fixture(for: recipe).item)
    }

    static func presentation(
        recipe: MemoryCardVisualRecipe,
        density: MemoryCardContentDensity,
        variant: MemoryCardVisualVariant = .automatic,
        role: CardDebugRoleOption,
        runtimeState: CardDebugRuntimeStateOption
    ) -> CaptureCardPresentation {
        CaptureCardPresentation(
            item: item(recipe: recipe, runtimeState: runtimeState),
            role: role.role,
            provenanceDisplayMode: .debug,
            surfaceMode: .skeuomorphic,
            visualRecipe: recipe,
            visualVariant: variant == .automatic ? nil : variant,
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
    @State private var selectedRecipe: MemoryCardVisualRecipe = .cassette
    @State private var selectedDensity: MemoryCardContentDensity = MemoryCardRecipeLayoutPolicy.defaultDensity(for: .cassette)
    @State private var selectedVariant: MemoryCardVisualVariant = .automatic
    @State private var selectedRole: CardDebugRoleOption = .composer
    @State private var selectedRuntimeState: CardDebugRuntimeStateOption = .normal
    @State private var tapCount = 0
    @State private var removeCount = 0

    private var supportedDensities: [MemoryCardContentDensity] {
        CardDebugStatesActionsModel.supportedDensities(for: selectedRecipe)
    }

    private var supportedVariants: [MemoryCardVisualVariant] {
        CardDebugStatesActionsModel.supportedVariants(for: selectedRecipe, density: selectedDensity)
    }

    private var presentation: CaptureCardPresentation {
        CardDebugStatesActionsModel.presentation(
            recipe: selectedRecipe,
            density: selectedDensity,
            variant: selectedVariant,
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
        .onChange(of: selectedRecipe) { _, newRecipe in
            selectedDensity = MemoryCardRecipeLayoutPolicy.normalizedDensity(selectedDensity, for: newRecipe)
            normalizeVariant()
        }
        .onChange(of: selectedDensity) { _, _ in
            normalizeVariant()
        }
        .onChange(of: selectedVariant) { _, _ in
            normalizeVariant()
        }
    }

    private var selectorSection: some View {
        Section {
            Picker("Recipe", selection: $selectedRecipe) {
                ForEach(CardDebugStatesActionsModel.recipeOptions) { recipe in
                    Text(recipe.rawValue).tag(recipe)
                }
            }

            Picker("Density", selection: $selectedDensity) {
                ForEach(supportedDensities) { density in
                    Text(density.rawValue).tag(density)
                }
            }

            Picker("Variant", selection: $selectedVariant) {
                ForEach(supportedVariants) { variant in
                    Text(variant.rawValue).tag(variant)
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
                    recipe: selectedRecipe,
                    density: presentation.contentDensity
                )
                DebugValueRow(title: "Presentation role", value: presentation.role.rawValue)
                DebugValueRow(title: "Runtime state", value: presentation.item.state.rawValue)
                DebugValueRow(title: "Selected", value: presentation.item.isSelected ? "true" : "false")
                DebugValueRow(title: "Visual variant", value: presentation.visualVariant.rawValue)
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
            DebugValueRow(title: "Source fixture", value: CardDebugStatesActionsModel.fixture(for: selectedRecipe).item.id)
            DebugValueRow(title: "Surface", value: presentation.surfaceMode.rawValue)
            DebugValueRow(title: "Visual recipe", value: selectedRecipe.rawValue)
            DebugValueRow(title: "Visual variant", value: presentation.visualVariant.rawValue)
            DebugValueRow(title: "Density", value: presentation.contentDensity.rawValue)
            DebugValueRow(title: "canRetry gap", value: presentation.capabilities.canRetry ? "available" : "not wired")
        }
    }

    private func normalizeVariant() {
        let normalized = CardDebugStatesActionsModel.normalizedVariant(
            selectedVariant,
            for: selectedRecipe,
            density: selectedDensity
        )
        if normalized != selectedVariant {
            selectedVariant = normalized
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

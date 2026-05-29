import SwiftUI

enum CardDebugRoleOption: String, CaseIterable, Identifiable {
    case composer
    case detailViewing
    case detailEditing
    case debug

    var id: String { rawValue }

    var label: String {
        switch self {
        case .composer:
            return "composer"
        case .detailViewing:
            return "detail viewing"
        case .detailEditing:
            return "detail editing"
        case .debug:
            return "debug"
        }
    }

    var role: CaptureCardRole {
        switch self {
        case .composer:
            return .composerEditing
        case .detailViewing:
            return .detailViewing
        case .detailEditing:
            return .detailEditing
        case .debug:
            return .debugLab
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
        case .normal, .selected:
            return .normal
        case .loading:
            return .loading
        case .error:
            return .error
        case .disabled:
            return .disabled
        }
    }

    var isSelected: Bool {
        self == .selected
    }

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

    static func supportedSizes(for recipe: MemoryCardVisualRecipe) -> [MemoryCardSizeToken] {
        MemoryCardRecipeLayoutPolicy.supportedSizes(for: recipe)
    }

    static func normalizedSize(_ size: MemoryCardSizeToken, for recipe: MemoryCardVisualRecipe) -> MemoryCardSizeToken {
        MemoryCardRecipeLayoutPolicy.normalizedSize(size, for: recipe)
    }

    static func supportedVariants(
        for recipe: MemoryCardVisualRecipe,
        size: MemoryCardSizeToken
    ) -> [MemoryCardVisualVariant] {
        MemoryCardRecipeLayoutPolicy.supportedVariants(for: recipe, size: size)
    }

    static func normalizedVariant(
        _ variant: MemoryCardVisualVariant,
        for recipe: MemoryCardVisualRecipe,
        size: MemoryCardSizeToken
    ) -> MemoryCardVisualVariant {
        MemoryCardRecipeLayoutPolicy.resolvedVariant(
            variant == .automatic ? nil : variant,
            for: recipe,
            size: size
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
        size: MemoryCardSizeToken,
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
            sizeToken: normalizedSize(size, for: recipe)
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
    @State private var selectedSize: MemoryCardSizeToken = MemoryCardRecipeLayoutPolicy.defaultSize(for: .cassette)
    @State private var selectedVariant: MemoryCardVisualVariant = .automatic
    @State private var selectedRole: CardDebugRoleOption = .composer
    @State private var selectedRuntimeState: CardDebugRuntimeStateOption = .normal
    @State private var tapCount = 0
    @State private var removeCount = 0

    private var supportedSizes: [MemoryCardSizeToken] {
        CardDebugStatesActionsModel.supportedSizes(for: selectedRecipe)
    }

    private var supportedVariants: [MemoryCardVisualVariant] {
        CardDebugStatesActionsModel.supportedVariants(for: selectedRecipe, size: selectedSize)
    }

    private var presentation: CaptureCardPresentation {
        CardDebugStatesActionsModel.presentation(
            recipe: selectedRecipe,
            size: selectedSize,
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
            let normalized = CardDebugStatesActionsModel.normalizedSize(selectedSize, for: newRecipe)
            if normalized != selectedSize {
                selectedSize = normalized
            }
            let normalizedVariant = CardDebugStatesActionsModel.normalizedVariant(
                selectedVariant,
                for: newRecipe,
                size: normalized
            )
            if normalizedVariant != selectedVariant {
                selectedVariant = normalizedVariant
            }
        }
        .onChange(of: selectedSize) { _, newSize in
            let normalized = CardDebugStatesActionsModel.normalizedSize(newSize, for: selectedRecipe)
            if normalized != newSize {
                selectedSize = normalized
            }
            let normalizedVariant = CardDebugStatesActionsModel.normalizedVariant(
                selectedVariant,
                for: selectedRecipe,
                size: normalized
            )
            if normalizedVariant != selectedVariant {
                selectedVariant = normalizedVariant
            }
        }
        .onChange(of: selectedVariant) { _, newVariant in
            let normalized = CardDebugStatesActionsModel.normalizedVariant(
                newVariant,
                for: selectedRecipe,
                size: selectedSize
            )
            if normalized != newVariant {
                selectedVariant = normalized
            }
        }
    }

    private var selectorSection: some View {
        Section {
            Picker("Recipe", selection: $selectedRecipe) {
                ForEach(CardDebugStatesActionsModel.recipeOptions) { recipe in
                    Text(recipe.rawValue).tag(recipe)
                }
            }

            Picker("Size", selection: $selectedSize) {
                ForEach(supportedSizes) { size in
                    Text(size.rawValue).tag(size)
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
            Text("Selected maps to CaptureCardState.normal with item.isSelected=true. It is not a production CaptureCardState case.")
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

                let box = MemoryCardRecipeLayoutPolicy.gridBox(for: presentation.sizeToken)
                let metrics = MemoryCardObjectMetrics.resolve(
                    recipe: selectedRecipe,
                    sizeToken: presentation.sizeToken,
                    density: presentation.contentDensity
                )
                DebugValueRow(title: "Presentation role", value: presentation.role.rawValue)
                DebugValueRow(title: "Runtime state", value: presentation.item.state.rawValue)
                DebugValueRow(title: "Selected", value: presentation.item.isSelected ? "true" : "false")
                DebugValueRow(title: "Grid box", value: "\(box.columnSpan)x\(box.rowSpan)")
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
        } footer: {
            Text("Capabilities are resolved from role + item. They describe what the surface may do, not necessarily what is visible in the current runtime state.")
        }
    }

    private var derivedBehaviorSection: some View {
        Section {
            ForEach(CardDebugStatesActionsModel.derivedBehaviorRows(for: presentation)) { row in
                CardDebugBooleanRow(row: row)
            }
        } header: {
            Text("Derived Behavior")
        } footer: {
            Text("Derived behavior is what CaptureCardView will actually expose for this state, including loading, error, disabled, and selected gates.")
        }
    }

    private var contractSection: some View {
        Section("Contract Notes") {
            DebugValueRow(title: "Source fixture", value: CardDebugStatesActionsModel.fixture(for: selectedRecipe).item.id)
            DebugValueRow(title: "Surface", value: presentation.surfaceMode.rawValue)
            DebugValueRow(title: "Visual recipe", value: selectedRecipe.rawValue)
            DebugValueRow(title: "Visual variant", value: presentation.visualVariant.rawValue)
            DebugValueRow(title: "Normalized size", value: presentation.sizeToken.rawValue)
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

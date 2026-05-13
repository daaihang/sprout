import SwiftUI

struct CompositionItemInspectorView: View {
    @Environment(PrototypeWorkspaceStore.self) private var workspace
    let item: CompositionItem

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Composition Item")
                .font(.headline)

            LabeledContent("Target Type", value: item.targetType.rawValue)
            LabeledContent("Width Units", value: "\(resolvedItem.widthUnits)")
            LabeledContent("Height Units", value: "\(resolvedItem.heightUnits)")
            LabeledContent("Z Index", value: "\(resolvedItem.zIndex)")
            LabeledContent("Rotation", value: String(format: "%.1f", resolvedItem.rotation))
            LabeledContent("Scale", value: String(format: "%.2f", resolvedItem.scale))

            Stepper("Width: \(resolvedItem.widthUnits)", value: widthBinding, in: 1...8)
            Stepper("Height: \(resolvedItem.heightUnits)", value: heightBinding, in: 1...8)
            Stepper("Layer: \(resolvedItem.zIndex)", value: zIndexBinding, in: 0...20)
            VStack(alignment: .leading, spacing: 6) {
                Text("Rotation")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                Slider(value: rotationBinding, in: -8...8, step: 0.5)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("Scale")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                Slider(value: scaleBinding, in: 0.75...1.2, step: 0.05)
            }

            Button("Bring Forward") {
                workspace.update(itemID: item.id, zIndex: resolvedItem.zIndex + 1)
            }

            Spacer()
        }
    }

    private var resolvedItem: CompositionItem {
        workspace.items.first(where: { $0.id == item.id }) ?? item
    }

    private var widthBinding: Binding<Int> {
        Binding(
            get: { resolvedItem.widthUnits },
            set: { workspace.update(itemID: item.id, widthUnits: $0) }
        )
    }

    private var heightBinding: Binding<Int> {
        Binding(
            get: { resolvedItem.heightUnits },
            set: { workspace.update(itemID: item.id, heightUnits: $0) }
        )
    }

    private var zIndexBinding: Binding<Int> {
        Binding(
            get: { resolvedItem.zIndex },
            set: { workspace.update(itemID: item.id, zIndex: $0) }
        )
    }

    private var rotationBinding: Binding<Double> {
        Binding(
            get: { resolvedItem.rotation },
            set: { workspace.update(itemID: item.id, rotation: $0) }
        )
    }

    private var scaleBinding: Binding<Double> {
        Binding(
            get: { resolvedItem.scale },
            set: { workspace.update(itemID: item.id, scale: $0) }
        )
    }
}

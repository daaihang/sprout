import SwiftUI

struct CompositionItemView: View {
    @Environment(PrototypeWorkspaceStore.self) private var workspace
    @Environment(PrototypeSelectionStore.self) private var selection

    let item: CompositionItem

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(item.targetType.rawValue.uppercased())
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)

            Text(title)
                .font(.headline)
                .lineLimit(2)

            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)

            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(borderColor, lineWidth: isSelected ? 2 : 1)
        )
        .overlay {
            if isSelected {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(Color.accentColor.opacity(0.22), style: StrokeStyle(lineWidth: 8))
                    .padding(-4)
            }
        }
        .overlay(alignment: .topTrailing) {
            if isSelected {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 10, height: 10)
                    .padding(10)
            }
        }
        .overlay {
            if isSelected {
                handleOverlay
            }
        }
        .shadow(color: .black.opacity(0.08), radius: 10, y: 5)
        .rotationEffect(.degrees(item.rotation))
        .scaleEffect(item.scale)
    }

    private var title: String {
        switch item.targetType {
        case .artifact:
            workspace.artifacts.first(where: { $0.id == item.targetID })?.title ?? "Unknown Artifact"
        case .record:
            workspace.records.first(where: { $0.id == item.targetID })?.rawText ?? "Unknown Record"
        case .reflection:
            workspace.reflections.first(where: { $0.id == item.targetID })?.title ?? "Unknown Reflection"
        case .arc:
            workspace.temporalArcs.first(where: { $0.id == item.targetID })?.title ?? "Unknown Arc"
        }
    }

    private var subtitle: String {
        switch item.targetType {
        case .artifact:
            workspace.artifacts.first(where: { $0.id == item.targetID })?.summary ?? ""
        case .record:
            workspace.records.first(where: { $0.id == item.targetID })?.captureSource.rawValue ?? ""
        case .reflection:
            workspace.reflections.first(where: { $0.id == item.targetID })?.body ?? ""
        case .arc:
            workspace.temporalArcs.first(where: { $0.id == item.targetID })?.summary ?? ""
        }
    }

    private var isSelected: Bool {
        selection.selectedEntity == .item(item.id)
    }

    private var borderColor: Color {
        isSelected ? .accentColor : Color.primary.opacity(0.08)
    }

    private var handleOverlay: some View {
        ZStack {
            handle
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            handle
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            handle
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            handle
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        }
        .padding(2)
    }

    private var handle: some View {
        RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(Color.white)
            .frame(width: 10, height: 10)
            .overlay {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .stroke(Color.accentColor, lineWidth: 1.5)
            }
    }
}

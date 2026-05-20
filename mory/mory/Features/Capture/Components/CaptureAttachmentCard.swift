import SwiftUI

struct CaptureAttachmentCard: View {
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    let item: CaptureComposerAttachmentItem
    let onRemove: () -> Void
    let onToggleSelection: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: item.kind.iconName)
                    .font(.subheadline)
                    .foregroundStyle(displaysSelection ? palette.controlTint : palette.controlTint.opacity(0.78))
                    .frame(width: 22, height: 22)

                Text(item.kind.label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Spacer(minLength: 8)

                trailingControl
            }

            Text(item.detail)
                .font(.subheadline)
                .foregroundStyle(palette.primaryText)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let secondaryText = item.secondaryText {
                HStack(spacing: 6) {
                    Text(secondaryText)
                        .font(.caption2)
                        .foregroundStyle(palette.secondaryText.opacity(0.72))
                }
            }
        }
        .padding(12)
        .frame(width: 176, height: 112, alignment: .topLeading)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.regularMaterial)
                .overlay {
                    LinearGradient(
                        colors: palette.background.map { $0.opacity(0.1) },
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(displaysSelection ? palette.selectionStroke : Color.secondary.opacity(0.16), lineWidth: 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .onTapGesture {
            guard canToggleSelection else { return }
            onToggleSelection()
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var trailingControl: some View {
        if item.isProcessing {
            ProgressView()
                .controlSize(.small)
        } else if item.isRemovable {
            Button(role: .destructive, action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .symbolRenderingMode(.hierarchical)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove attachment")
        } else if item.isSelectable {
            Image(systemName: displaysSelection ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(displaysSelection ? Color.accentColor : Color.secondary.opacity(0.5))
                .accessibilityLabel(displaysSelection ? "Selected" : "Not selected")
        }
    }

    private var displaysSelection: Bool {
        item.isSelectable && item.isSelected && !item.isProcessing
    }

    private var canToggleSelection: Bool {
        item.isSelectable && !item.isProcessing
    }

    private var palette: CaptureCardPalette {
        CaptureCardPalette.resolve(
            for: CaptureCardItem(attachment: item),
            highContrast: colorSchemeContrast == .increased
        )
    }
}

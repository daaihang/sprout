import SwiftUI

struct CaptureAttachmentCard: View {
    let item: CaptureComposerAttachmentItem
    let onRemove: () -> Void
    let onToggleSelection: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: item.kind.iconName)
                    .font(.subheadline)
                    .foregroundStyle(item.isSelected ? Color.accentColor : Color.secondary)
                    .frame(width: 22, height: 22)

                Text(item.kind.label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Spacer(minLength: 8)

                trailingControl
            }

            Text(item.detail)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 6) {
                if let origin = item.origin {
                    Text(origin.captureBadgeLabel)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.14), in: Capsule())
                }

                if let secondaryText = item.secondaryText {
                    Text(secondaryText)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(12)
        .frame(width: 176, height: 112, alignment: .topLeading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(item.isSelected ? Color.accentColor.opacity(0.45) : Color.secondary.opacity(0.16), lineWidth: 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .onTapGesture {
            guard item.isSelectable else { return }
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
            Image(systemName: item.isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(item.isSelected ? Color.accentColor : Color.secondary.opacity(0.5))
                .accessibilityLabel(item.isSelected ? "Selected" : "Not selected")
        }
    }
}

import SwiftUI

struct RecordBodyCardEditor: View {
    @Binding var text: String
    var focus: FocusState<Bool>.Binding
    var minHeight: CGFloat = 180

    var body: some View {
        CaptureCardChrome(
            item: item,
            containerBackground: AnyShapeStyle(Color(.secondarySystemBackground)),
            containerStroke: stroke,
            trailingControl: EmptyView(),
            showsLayoutGuides: false,
            fieldAuditText: nil,
            cornerRadius: 18
        ) {
            VStack(alignment: .leading, spacing: 10) {
                Label("capture.card.kind.text", systemImage: "note.text")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                TextField("quickCapture.text.placeholder", text: $text, axis: .vertical)
                    .focused(focus)
                    .font(.body)
                    .lineSpacing(4)
                    .lineLimit(4...14)
                    .textFieldStyle(.plain)
                    .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .topLeading)
            }
            .padding(16)
            .contentShape(Rectangle())
            .onTapGesture {
                focus.wrappedValue = true
            }
        }
        .contentShape(.contextMenuPreview, RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var item: CaptureCardItem {
        CaptureCardItem(
            id: "record-body-editor",
            payload: .prompt(CapturePromptCardPayload(prompt: String(localized: "quickCapture.text.placeholder"), answer: text)),
            origin: .manual,
            state: .normal,
            title: String(localized: "capture.card.kind.text"),
            detail: text,
            isRemovable: false
        )
    }

    private var stroke: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .stroke(Color.primary.opacity(0.08), lineWidth: 1)
    }
}

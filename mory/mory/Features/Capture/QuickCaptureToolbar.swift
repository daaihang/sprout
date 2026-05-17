import SwiftUI

struct QuickCaptureToolbar: View {
    let onTextCapture: () -> Void
    let onMoreCapture: () -> Void

    var body: some View {
        HStack(spacing: MorySpacing.small) {
            Button {
                onTextCapture()
            } label: {
                Label("quickCapture.text", systemImage: "square.and.pencil")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            Button {
            } label: {
                Label("quickCapture.voice", systemImage: "mic.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(true)
            .accessibilityHint(Text("quickCapture.voice.placeholder"))

            Button {
                onMoreCapture()
            } label: {
                Label("quickCapture.more", systemImage: "plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .labelStyle(.iconOnly)
        .padding(.horizontal, MorySpacing.medium)
        .padding(.vertical, MorySpacing.small)
        .background(.regularMaterial)
        .overlay(alignment: .top) {
            Divider()
        }
    }
}

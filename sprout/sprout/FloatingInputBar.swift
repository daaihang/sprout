import SwiftUI

struct FloatingInputBar: View {
    @Environment(AppLocalization.self) private var localization
    @Binding var text: String
    @Binding var isShowingSheet: Bool
    @FocusState var isFocused: Bool
    let onSend: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            TextField(t("content.floating_input.placeholder", "Write something..."), text: $text)
                .focused($isFocused)
                .padding(.horizontal, 20)
                .padding(.vertical, 14)

            Button(action: {
                onSend()
            }) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.white)
            }
            .padding(.trailing, 16)
            .disabled(text.isEmpty)
            .opacity(text.isEmpty ? 0.4 : 1)
        }
        .background(
            RoundedRectangle(cornerRadius: 28)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 28)
                        .stroke(Color.white.opacity(0.4), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.12), radius: 16, x: 0, y: 8)
        .padding(.horizontal, 16)
        .onTapGesture {
            isFocused = false
            if text.isEmpty {
                onDismiss()
            }
            isShowingSheet = true
        }
        .onAppear {
            isFocused = true
        }
    }

    private func t(_ key: String, _ defaultValue: String, _ arguments: CVarArg...) -> String {
        localization.string(key, default: defaultValue, arguments: arguments)
    }
}

#Preview {
    VStack {
        Spacer()
        FloatingInputBar(
            text: .constant(""),
            isShowingSheet: .constant(true),
            onSend: {},
            onDismiss: {}
        )
    }
    .padding(.bottom, 50)
}

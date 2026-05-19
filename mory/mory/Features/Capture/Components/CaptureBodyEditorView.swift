import SwiftUI

struct CaptureBodyEditorView: View {
    @Binding var text: String
    var focus: FocusState<Bool>.Binding
    var minHeight: CGFloat = 360

    var body: some View {
        TextField("quickCapture.text.placeholder", text: $text, axis: .vertical)
            .focused(focus)
            .font(.body)
            .lineSpacing(4)
            .lineLimit(14...)
            .textFieldStyle(.plain)
            .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .topLeading)
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .contentShape(Rectangle())
            .onTapGesture {
                focus.wrappedValue = true
            }
    }
}

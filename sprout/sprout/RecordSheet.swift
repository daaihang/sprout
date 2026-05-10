import SwiftUI

struct RecordSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 24) {
            Text("录音")
                .font(.headline)
                .padding(.top, 20)

            Spacer()

            Text("按住说话")
                .font(.title2)
                .foregroundColor(.secondary)

            Spacer()

            // 液态玻璃效果装饰
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .frame(height: 120)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                )
                .padding(.horizontal, 20)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground).opacity(0.95))
        .presentationDetents([.medium, .large], selection: .constant(.medium))
        .presentationDragIndicator(.visible)
    }
}

struct RecordSheet_Previews: PreviewProvider {
    static var previews: some View {
        RecordSheet()
    }
}
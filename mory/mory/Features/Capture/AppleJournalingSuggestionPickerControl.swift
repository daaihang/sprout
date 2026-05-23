import SwiftUI

#if os(iOS) && canImport(JournalingSuggestions)
import JournalingSuggestions

@available(iOS 17.2, *)
private struct DeviceAppleJournalingSuggestionPickerControl: View {
    let onDraft: (JournalingSuggestionDraft) -> Void
    let onError: (String) -> Void

    @State private var isPresented = false

    var body: some View {
        Button("Open Apple Picker") {
            isPresented = true
        }
        .journalingSuggestionsPicker(isPresented: $isPresented) { suggestion in
            let draft = await AppleJournalingSuggestionAdapter().makeDraft(from: suggestion)
            await MainActor.run {
                onDraft(draft)
            }
        }
    }
}
#endif

struct AppleJournalingSuggestionPickerControl: View {
    let onDraft: (JournalingSuggestionDraft) -> Void
    let onError: (String) -> Void

    var body: some View {
        #if os(iOS) && canImport(JournalingSuggestions)
        if #available(iOS 17.2, *) {
            DeviceAppleJournalingSuggestionPickerControl(onDraft: onDraft, onError: onError)
        } else {
            unavailableView("Apple Journaling Suggestions requires iOS 17.2 or later.")
        }
        #else
        unavailableView("Apple Journaling Suggestions is not present in this SDK/platform build. Use the fallback draft form.")
        #endif
    }

    private func unavailableView(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
            Button("Open Apple Picker") {
                onError(message)
            }
            .disabled(true)
        }
    }
}

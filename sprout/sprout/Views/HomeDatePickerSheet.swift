import SwiftUI

struct HomeDatePickerSheet: View {
    @Environment(AppLocalization.self) private var localization
    @Binding var selectedDate: Date
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack {
                DatePicker(
                    localization.string("content.date_picker.title", default: "Choose Date"),
                    selection: $selectedDate,
                    in: ...Calendar.current.startOfDay(for: Date()),
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .padding()
                .onChange(of: selectedDate) { _, new in
                    let norm = Calendar.current.startOfDay(for: new)
                    if norm != selectedDate { selectedDate = norm }
                }
            }
            .navigationTitle(localization.string("content.date_picker.title", default: "Choose Date"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(localization.string("common.done", default: "Done")) { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }
}

import SwiftUI

struct NotificationManagementView: View {
    @Environment(\.memoryRepository) private var memoryRepository

    var body: some View {
        List {
            NotificationPreferencesContent(memoryRepository: memoryRepository)
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
    }
}

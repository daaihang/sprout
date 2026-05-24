import AVFoundation
import Foundation
import Photos
import Speech
import SwiftUI
import UIKit

struct SettingsPlaceholderSection: View {
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    let systemImage: String

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
        } description: {
            Text(message)
        }
        .navigationTitle(title)
    }
}

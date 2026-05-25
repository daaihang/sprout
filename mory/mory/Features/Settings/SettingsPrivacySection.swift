import AVFoundation
import Foundation
import Photos
import Speech
import SwiftUI
import UIKit

struct SettingsPrivacySection: View {
    let runtimeEnvironment: AppRuntimeEnvironment

    var body: some View {
        List {
            Section("settings.privacy.localFirst.title") {
                Text("settings.privacy.localFirst.body")
                Text("settings.privacy.ai.body")
                Text("settings.privacy.context.body")
            }

            Section("settings.privacy.deletion.title") {
                Text("settings.privacy.deletion.body")
            }

            Section("settings.privacy.debug.title") {
                Text(runtimeEnvironment.allowsDebugTools ? "settings.privacy.debug.internal" : "settings.privacy.debug.public")
            }
        }
        .navigationTitle("settings.privacy.title")
    }
}

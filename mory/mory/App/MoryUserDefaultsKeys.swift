import Foundation

enum MoryUserDefaultsKeys {
    enum LocalData {
        static let legacyOwnerID = "mory.localData.legacyOwnerID.v1"
        static let activeOwnerID = "mory.localData.lastPreparedOwnerID.v1"
    }

    enum Onboarding {
        static let completedV1 = "mory.onboarding.v1.completed"
    }

    enum RemotePush {
        static let legacyAPNSTokenHex = "mory.apnsTokenHex"
        static let lastRegistrationDigest = "mory.remotePush.lastRegistrationDigest"
        static let pendingWritebacks = "mory.remotePush.pendingWritebacks"
        static let activeLocalOwnerID = "mory.remotePush.activeLocalOwnerID"
    }

    enum DebugQualityTuning {
        static let enabled = "mory.debug.qualityTuning.enabled"
        static let thresholds = "mory.debug.qualityTuning.thresholds"
        static let promptProfile = "mory.debug.qualityTuning.promptProfile"
        static let wildcard = "mory.debug.qualityTuning.*"
    }
}

import Foundation

enum NotificationPolicyBlockReason: String, Codable, Hashable, Sendable {
    case notificationsDisabled
    case localNotificationFlagDisabled
    case notificationTypeDisabled
    case maxPerDayReached
    case minimumInterval
    case quietHours
    case sensitiveTopicSuppressed
}

struct NotificationPolicyDecision: Hashable, Sendable {
    var approvedIntent: NotificationIntent?
    var blockReasons: [NotificationPolicyBlockReason]

    var isAllowed: Bool {
        approvedIntent != nil && blockReasons.isEmpty
    }

    static func blocked(_ reasons: [NotificationPolicyBlockReason]) -> NotificationPolicyDecision {
        NotificationPolicyDecision(approvedIntent: nil, blockReasons: reasons)
    }
}

struct NotificationPolicy: Sendable {
    let calendar: Calendar

    nonisolated init(calendar: Calendar = .autoupdatingCurrent) {
        self.calendar = calendar
    }

    func evaluate(
        intent: NotificationIntent,
        existingIntents: [NotificationIntent],
        preferences: IntelligencePreferences,
        flags: V6FeatureFlags,
        questionSensitivity: QuestionSensitivity? = nil,
        now: Date = .now
    ) -> NotificationPolicyDecision {
        var reasons: [NotificationPolicyBlockReason] = []

        if !preferences.notificationPreferences.enabled {
            reasons.append(.notificationsDisabled)
        }
        if intent.deliveryChannel == .local && !flags.localNotifications {
            reasons.append(.localNotificationFlagDisabled)
        }
        if !isNotificationTypeEnabled(intent.kind, preferences: preferences.notificationPreferences) {
            reasons.append(.notificationTypeDisabled)
        }
        if reachesDailyLimit(
            candidate: intent,
            existingIntents: existingIntents,
            maxPerDay: preferences.notificationPreferences.maxPerDay
        ) {
            reasons.append(.maxPerDayReached)
        }
        if violatesMinimumInterval(
            candidate: intent,
            existingIntents: existingIntents,
            minimumMinutes: preferences.notificationPreferences.resolvedMinimumMinutesBetweenNotifications
        ) {
            reasons.append(.minimumInterval)
        }
        if isInsideQuietHours(intent.scheduledAt, preferences: preferences.notificationPreferences) {
            reasons.append(.quietHours)
        }
        if isSensitiveBlocked(questionSensitivity, policy: preferences.sensitiveTopicPolicy) {
            reasons.append(.sensitiveTopicSuppressed)
        }

        guard reasons.isEmpty else {
            return .blocked(reasons)
        }

        return NotificationPolicyDecision(
            approvedIntent: sanitize(intent, preferences: preferences, questionSensitivity: questionSensitivity, now: now),
            blockReasons: []
        )
    }

    private func isNotificationTypeEnabled(
        _ kind: NotificationIntentKind,
        preferences: NotificationPreferences
    ) -> Bool {
        switch kind {
        case .analysisReady:
            return preferences.backgroundDoneEnabled
        case .dailyQuestion:
            return preferences.dailyQuestionEnabled
        case .reflectionReady:
            return preferences.stageFormingEnabled
        case .repeatedTheme:
            return preferences.repeatedThemeEnabled
        case .stageForming:
            return preferences.stageFormingEnabled
        case .revisit:
            return preferences.revisitEnabled
        case .debugTest:
            return preferences.enabled
        }
    }

    private func reachesDailyLimit(
        candidate: NotificationIntent,
        existingIntents: [NotificationIntent],
        maxPerDay: Int
    ) -> Bool {
        guard maxPerDay > 0 else { return true }
        let count = existingIntents.filter { intent in
            guard intent.status == .pending || intent.status == .scheduled || intent.status == .delivered else {
                return false
            }
            return calendar.isDate(intent.scheduledAt, inSameDayAs: candidate.scheduledAt)
        }.count
        return count >= maxPerDay
    }

    private func violatesMinimumInterval(
        candidate: NotificationIntent,
        existingIntents: [NotificationIntent],
        minimumMinutes: Int
    ) -> Bool {
        guard minimumMinutes > 0 else { return false }
        let minimumInterval = TimeInterval(minimumMinutes * 60)
        return existingIntents.contains { intent in
            guard intent.status == .pending || intent.status == .scheduled || intent.status == .delivered else {
                return false
            }
            return abs(intent.scheduledAt.timeIntervalSince(candidate.scheduledAt)) < minimumInterval
        }
    }

    private func isInsideQuietHours(_ date: Date, preferences: NotificationPreferences) -> Bool {
        guard let startHour = preferences.quietHoursStartHour,
              let endHour = preferences.quietHoursEndHour,
              startHour != endHour else {
            return false
        }
        let normalizedStart = max(0, min(23, startHour))
        let normalizedEnd = max(0, min(23, endHour))
        let startMinute = max(0, min(59, preferences.quietHoursStartMinute ?? 0))
        let endMinute = max(0, min(59, preferences.quietHoursEndMinute ?? 0))
        let startTotalMinutes = normalizedStart * 60 + startMinute
        let endTotalMinutes = normalizedEnd * 60 + endMinute
        guard startTotalMinutes != endTotalMinutes else {
            return false
        }
        let components = calendar.dateComponents([.hour, .minute], from: date)
        let candidateTotalMinutes = (components.hour ?? 0) * 60 + (components.minute ?? 0)

        if startTotalMinutes < endTotalMinutes {
            return candidateTotalMinutes >= startTotalMinutes && candidateTotalMinutes < endTotalMinutes
        }
        return candidateTotalMinutes >= startTotalMinutes || candidateTotalMinutes < endTotalMinutes
    }

    private func isSensitiveBlocked(
        _ sensitivity: QuestionSensitivity?,
        policy: SensitiveTopicPolicy
    ) -> Bool {
        guard let sensitivity else { return false }
        switch (sensitivity, policy) {
        case (.sensitive, .allow):
            return false
        case (.sensitive, _):
            return true
        case (.personal, .suppress):
            return true
        default:
            return false
        }
    }

    private func sanitize(
        _ intent: NotificationIntent,
        preferences: IntelligencePreferences,
        questionSensitivity: QuestionSensitivity?,
        now: Date
    ) -> NotificationIntent {
        var sanitized = intent
        let shouldUseGenericCopy = intent.privacyLevel != .generic
            && (!preferences.notificationPreferences.richPreviewsEnabled || questionSensitivity == .personal)
        guard shouldUseGenericCopy else { return sanitized }

        sanitized.privacyLevel = .generic
        sanitized.title = "Mory"
        sanitized.body = genericBody(for: intent.kind)
        sanitized.createdAt = intent.createdAt > now ? now : intent.createdAt
        return sanitized
    }

    private func genericBody(for kind: NotificationIntentKind) -> String {
        switch kind {
        case .analysisReady:
            return "Your memories are ready to review."
        case .dailyQuestion:
            return "A question is ready for today."
        case .reflectionReady:
            return "A reflection is ready to review."
        case .repeatedTheme:
            return "A recurring pattern is ready to review."
        case .stageForming:
            return "A memory chapter may be forming."
        case .revisit:
            return "A meaningful memory is ready to revisit."
        case .debugTest:
            return "A debug notification is ready."
        }
    }
}

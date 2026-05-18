import XCTest
@testable import mory

final class IntelligenceDomainTests: XCTestCase {
    func testIntelligencePreferencesDefaultToLocalFirstAndQuietNotifications() {
        let preferences = IntelligencePreferences.defaults

        XCTAssertTrue(preferences.localIntelligenceEnabled)
        XCTAssertFalse(preferences.cloudIntelligenceEnabled)
        XCTAssertTrue(preferences.semanticSearchEnabled)
        XCTAssertTrue(preferences.homeSuggestionsEnabled)
        XCTAssertFalse(preferences.dailyQuestionsEnabled)
        XCTAssertFalse(preferences.notificationPreferences.enabled)
        XCTAssertFalse(preferences.notificationPreferences.richPreviewsEnabled)
        XCTAssertEqual(preferences.questionTone, .evidenceBased)
        XCTAssertEqual(preferences.sensitiveTopicPolicy, .askBeforeShowing)
    }

    func testV6FeatureFlagsDefaultToOffForSafeRollout() {
        let flags = V6FeatureFlags.defaults

        XCTAssertFalse(flags.intelligenceJobs)
        XCTAssertFalse(flags.entityProfiles)
        XCTAssertFalse(flags.clarificationQuestions)
        XCTAssertFalse(flags.homeGrid)
        XCTAssertFalse(flags.semanticSearch)
        XCTAssertFalse(flags.dailyQuestions)
        XCTAssertFalse(flags.localNotifications)
        XCTAssertFalse(flags.cloudQuestionSuggestions)
        XCTAssertFalse(flags.cloudChapterSuggestions)
        XCTAssertFalse(flags.multimediaViews)
    }

    func testClarificationQuestionCarriesEvidenceAndCandidateAnswers() {
        let entityID = UUID()
        let recordID = UUID()
        let question = ClarificationQuestion(
            kind: .entityRelationship,
            prompt: "Who is Alex to you?",
            targetType: .entity,
            targetID: entityID,
            sourceRecordIDs: [recordID],
            candidateAnswers: [
                ClarificationAnswerOption(label: "Coworker", value: EntityRelationshipToUser.coworker.rawValue),
                ClarificationAnswerOption(label: "Friend", value: EntityRelationshipToUser.friend.rawValue),
            ],
            priority: 0.8,
            reason: "Alex appeared in several recent memories."
        )

        XCTAssertEqual(question.status, .pending)
        XCTAssertEqual(question.targetType, .entity)
        XCTAssertEqual(question.sourceRecordIDs, [recordID])
        XCTAssertEqual(question.candidateAnswers.first?.value, EntityRelationshipToUser.coworker.rawValue)
        XCTAssertFalse(question.reason.isEmpty)
    }
}


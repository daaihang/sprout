import XCTest
@testable import mory

final class IntelligenceDomainTests: XCTestCase {
    func testIntelligencePreferencesDefaultToCloudDeepIntelligenceAndQuietNotifications() {
        let preferences = IntelligencePreferences.defaults

        XCTAssertTrue(preferences.localIntelligenceEnabled)
        XCTAssertTrue(preferences.cloudIntelligenceEnabled)
        XCTAssertTrue(preferences.voiceRefinementEnabled)
        XCTAssertTrue(preferences.semanticSearchEnabled)
        XCTAssertTrue(preferences.homeSuggestionsEnabled)
        XCTAssertFalse(preferences.dailyQuestionsEnabled)
        XCTAssertFalse(preferences.notificationPreferences.enabled)
        XCTAssertFalse(preferences.notificationPreferences.richPreviewsEnabled)
        XCTAssertEqual(preferences.questionTone, .evidenceBased)
        XCTAssertEqual(preferences.sensitiveTopicPolicy, .askBeforeShowing)
    }

    func testV6FeatureFlagsDefaultToCloudCooperativeV6On() {
        let flags = V6FeatureFlags.defaults

        XCTAssertTrue(flags.intelligenceJobs)
        XCTAssertTrue(flags.entityProfiles)
        XCTAssertTrue(flags.clarificationQuestions)
        XCTAssertTrue(flags.homeGrid)
        XCTAssertTrue(flags.semanticSearch)
        XCTAssertTrue(flags.dailyQuestions)
        XCTAssertTrue(flags.localNotifications)
        XCTAssertTrue(flags.cloudQuestionSuggestions)
        XCTAssertTrue(flags.cloudChapterSuggestions)
        XCTAssertTrue(flags.multimediaViews)
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

    func testOrderedCollectionsPreserveFirstSeenOrder() {
        XCTAssertEqual(
            OrderedCollections.unique(["a", "b", "a", "c", "b"]),
            ["a", "b", "c"]
        )
        XCTAssertEqual(
            OrderedCollections.stableUnion(["a", "b"], ["b", "c", "a", "d"]),
            ["a", "b", "c", "d"]
        )
    }
}

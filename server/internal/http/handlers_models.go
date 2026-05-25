package http

import (
	"sprout/server/internal/ai"
	"sprout/server/internal/notification"
)

type authAppleRequest struct {
	IdentityToken string `json:"identity_token"`
	Nonce         string `json:"nonce"`
}

type authResponse struct {
	AccessToken            string   `json:"access_token"`
	RefreshToken           string   `json:"refresh_token,omitempty"`
	ExpiresAt              string   `json:"expires_at"`
	User                   authUser `json:"user"`
	Mode                   string   `json:"mode"`
	IsNewUser              bool     `json:"is_new_user"`
	HasCompletedOnboarding bool     `json:"has_completed_onboarding"`
}

type authUser struct {
	ID   string `json:"id"`
	Tier string `json:"tier"`
}

type onboardingCompleteResponse struct {
	HasCompletedOnboarding bool `json:"has_completed_onboarding"`
}

type analyzePreviewResponseEnvelope struct {
	ai.AnalyzeResponse
	Mode string `json:"mode"`
}

type pushRegisterRequest struct {
	DeviceID                           string `json:"device_id"`
	APNSToken                          string `json:"apns_token"`
	Timezone                           string `json:"timezone"`
	HasQuestionReady                   bool   `json:"has_question_ready"`
	NotificationsEnabled               bool   `json:"notifications_enabled"`
	AnalysisReadyEnabled               bool   `json:"analysis_ready_enabled"`
	DailyQuestionEnabled               bool   `json:"daily_question_enabled"`
	ReflectionReadyEnabled             bool   `json:"reflection_ready_enabled"`
	DeliveryPace                       string `json:"delivery_pace"`
	MaxPerDay                          int    `json:"max_per_day"`
	MinimumMinutesBetweenNotifications int    `json:"minimum_minutes_between_notifications"`
	QuietStart                         string `json:"quiet_start"`
	QuietEnd                           string `json:"quiet_end"`
	RichPreviewsEnabled                bool   `json:"rich_previews_enabled"`
	LocalIntelligenceEnabled           bool   `json:"local_intelligence_enabled"`
	CloudIntelligenceEnabled           bool   `json:"cloud_intelligence_enabled"`
	SemanticSearchEnabled              bool   `json:"semantic_search_enabled"`
	HomeSuggestionsEnabled             bool   `json:"home_suggestions_enabled"`
}

type pushRegisterResponse struct {
	Registered bool   `json:"registered"`
	UserID     string `json:"user_id"`
}

type pushDeliveryWritebackRequest struct {
	DeviceID   string `json:"device_id"`
	IntentID   string `json:"intent_id"`
	Action     string `json:"action"`
	Kind       string `json:"kind"`
	TargetType string `json:"target_type"`
	TargetID   string `json:"target_id"`
	OccurredAt string `json:"occurred_at"`
}

type pushDeliveryWritebackResponse struct {
	Accepted bool   `json:"accepted"`
	UserID   string `json:"user_id"`
}

type pushEnqueueRequest struct {
	IntentID     string                       `json:"intent_id"`
	Kind         string                       `json:"kind"`
	Title        string                       `json:"title"`
	Body         string                       `json:"body"`
	TargetType   string                       `json:"target_type"`
	TargetID     string                       `json:"target_id"`
	PrivacyLevel string                       `json:"privacy_level"`
	DeepLink     string                       `json:"deep_link"`
	Target       notification.DeliveryTarget  `json:"target"`
	Payload      notification.DeliveryPayload `json:"payload"`
	ScheduledAt  string                       `json:"scheduled_at"`
}

type pushEnqueueResponse struct {
	Accepted             bool   `json:"accepted"`
	UserID               string `json:"user_id"`
	QueuedCount          int    `json:"queued_count"`
	SkippedCount         int    `json:"skipped_count"`
	SentCount            int    `json:"sent_count"`
	FailedCount          int    `json:"failed_count"`
	RetriedCount         int    `json:"retried_count"`
	PermanentFailedCount int    `json:"permanent_failed_count"`
}

type analyzeResponseEnvelope struct {
	ai.AnalyzeResponse
	Meta analyzeMeta `json:"meta"`
}

type analyzeV7ResponseEnvelope struct {
	ai.AnalyzeV7Response
	Meta analyzeMeta `json:"meta"`
}

type analyzeMeta struct {
	Provider      string   `json:"provider"`
	Model         string   `json:"model"`
	Usage         ai.Usage `json:"usage"`
	RequestID     string   `json:"request_id,omitempty"`
	PromptVersion string   `json:"prompt_version,omitempty"`
}

type transcriptRefinementResponseEnvelope struct {
	ai.TranscriptRefinementResponse
	Meta analyzeMeta `json:"meta"`
}

type questionSuggestionResponseEnvelope struct {
	ai.QuestionSuggestionResponse
	Meta analyzeMeta `json:"meta"`
}

type chapterSuggestionResponseEnvelope struct {
	ai.ChapterSuggestionResponse
	Meta analyzeMeta `json:"meta"`
}

type photoSemanticAnalysisResponseEnvelope struct {
	ai.PhotoSemanticAnalysisResponse
	Meta analyzeMeta `json:"meta"`
}

type notificationIntentSuggestionResponseEnvelope struct {
	ai.NotificationIntentSuggestionResponse
	Meta analyzeMeta `json:"meta"`
}

type cloudIntelligenceEvalCase struct {
	Operation  string `json:"operation"`
	Success    bool   `json:"success"`
	Provider   string `json:"provider,omitempty"`
	Model      string `json:"model,omitempty"`
	Error      string `json:"error,omitempty"`
	ErrorClass string `json:"error_class,omitempty"`
	Retryable  bool   `json:"retryable,omitempty"`
}

type cloudIntelligenceEvalResponse struct {
	PromptVersion string                      `json:"prompt_version"`
	RequestID     string                      `json:"request_id,omitempty"`
	Cases         []cloudIntelligenceEvalCase `json:"cases"`
}

type reflectionRequest struct {
	RecordShell   ai.AnalyzeRecordShell     `json:"record_shell"`
	Artifacts     []ai.AnalyzeArtifact      `json:"artifacts"`
	LinkedArcID   string                    `json:"linked_arc_id,omitempty"`
	KnownEntities []ai.KnownEntityReference `json:"known_entities,omitempty"`
	Prompt        string                    `json:"prompt,omitempty"`
	DebugOptions  *ai.DebugOptions          `json:"debug_options,omitempty"`
}

type reflectionResponse struct {
	Title           string      `json:"title"`
	Body            string      `json:"body"`
	EvidenceSummary string      `json:"evidence_summary"`
	Confidence      float64     `json:"confidence"`
	SourceRecordIDs []string    `json:"source_record_ids"`
	Meta            analyzeMeta `json:"meta"`
}

package db

import (
	"context"
	"time"
)

type PushToken struct {
	UserID                             string    `json:"user_id"`
	DeviceID                           string    `json:"device_id"`
	APNSToken                          string    `json:"apns_token"`
	Timezone                           string    `json:"timezone"`
	HasQuestionReady                   bool      `json:"has_question_ready"`
	NotificationsEnabled               bool      `json:"notifications_enabled"`
	BackgroundDoneEnabled              bool      `json:"background_done_enabled"`
	DailyQuestionEnabled               bool      `json:"daily_question_enabled"`
	RepeatedThemeEnabled               bool      `json:"repeated_theme_enabled"`
	StageFormingEnabled                bool      `json:"stage_forming_enabled"`
	RevisitEnabled                     bool      `json:"revisit_enabled"`
	DeliveryPace                       string    `json:"delivery_pace,omitempty"`
	MaxPerDay                          int       `json:"max_per_day,omitempty"`
	MinimumMinutesBetweenNotifications int       `json:"minimum_minutes_between_notifications,omitempty"`
	QuietStart                         string    `json:"quiet_start,omitempty"`
	QuietEnd                           string    `json:"quiet_end,omitempty"`
	RichPreviewsEnabled                bool      `json:"rich_previews_enabled"`
	LocalIntelligenceEnabled           bool      `json:"local_intelligence_enabled"`
	CloudIntelligenceEnabled           bool      `json:"cloud_intelligence_enabled"`
	SemanticSearchEnabled              bool      `json:"semantic_search_enabled"`
	HomeSuggestionsEnabled             bool      `json:"home_suggestions_enabled"`
	CreatedAt                          time.Time `json:"created_at,omitempty"`
	UpdatedAt                          time.Time `json:"updated_at,omitempty"`
}

type PushDelivery struct {
	UserID        string     `json:"user_id"`
	DeviceID      string     `json:"device_id"`
	IntentID      string     `json:"intent_id"`
	Kind          string     `json:"kind"`
	Title         string     `json:"title"`
	Body          string     `json:"body"`
	TargetType    string     `json:"target_type"`
	TargetID      string     `json:"target_id"`
	PrivacyLevel  string     `json:"privacy_level,omitempty"`
	DeepLink      string     `json:"deep_link,omitempty"`
	PayloadJSON   string     `json:"payload_json,omitempty"`
	ScheduledAt   time.Time  `json:"scheduled_at"`
	AttemptCount  int        `json:"attempt_count"`
	NextAttemptAt *time.Time `json:"next_attempt_at,omitempty"`
	Status        string     `json:"status"`
	LastError     string     `json:"last_error,omitempty"`
	SentAt        *time.Time `json:"sent_at,omitempty"`
	DeliveredAt   *time.Time `json:"delivered_at,omitempty"`
	OpenedAt      *time.Time `json:"opened_at,omitempty"`
	DismissedAt   *time.Time `json:"dismissed_at,omitempty"`
	CreatedAt     time.Time  `json:"created_at,omitempty"`
	UpdatedAt     time.Time  `json:"updated_at,omitempty"`
}

type PushDeliveryEvent struct {
	ID         int64     `json:"id"`
	UserID     string    `json:"user_id"`
	DeviceID   string    `json:"device_id"`
	IntentID   string    `json:"intent_id"`
	Action     string    `json:"action"`
	Kind       string    `json:"kind"`
	TargetType string    `json:"target_type"`
	TargetID   string    `json:"target_id"`
	OccurredAt time.Time `json:"occurred_at"`
	CreatedAt  time.Time `json:"created_at,omitempty"`
}

type UserProfile struct {
	UserID                 string    `json:"user_id"`
	HasCompletedOnboarding bool      `json:"has_completed_onboarding"`
	CreatedAt              time.Time `json:"created_at,omitempty"`
	UpdatedAt              time.Time `json:"updated_at,omitempty"`
}

type PushTokenStore interface {
	UpsertPushToken(ctx context.Context, token PushToken) error
	GetPushToken(ctx context.Context, userID, deviceID string) (PushToken, error)
	ListPushTokens(ctx context.Context, userID string) ([]PushToken, error)
	UpsertPushDelivery(ctx context.Context, delivery PushDelivery) error
	GetPushDelivery(ctx context.Context, userID, deviceID, intentID string) (PushDelivery, error)
	ListPushDeliveries(ctx context.Context, userID string) ([]PushDelivery, error)
	ListDuePushDeliveries(ctx context.Context, now time.Time, limit int) ([]PushDelivery, error)
	UpdatePushDeliveryStatus(ctx context.Context, userID, deviceID, intentID, status string, eventAt time.Time, lastError string) error
	UpdatePushDeliveryAttempt(ctx context.Context, userID, deviceID, intentID, status string, eventAt time.Time, lastError string, nextAttemptAt *time.Time, incrementAttempt bool) error
	InsertPushDeliveryEvent(ctx context.Context, event PushDeliveryEvent) error
	ListPushDeliveryEvents(ctx context.Context, userID string) ([]PushDeliveryEvent, error)
	Close() error
}

type UserProfileStore interface {
	GetOrCreateUserProfile(ctx context.Context, userID string) (UserProfile, bool, error)
	MarkOnboardingComplete(ctx context.Context, userID string) (UserProfile, error)
}

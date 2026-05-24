package db

import (
	"database/sql"
	"fmt"
	"strings"
	"time"
)

func (s *SQLiteStore) Close() error {
	return s.db.Close()
}

func boolToInt(value bool) int {
	if value {
		return 1
	}
	return 0
}

func (s *SQLiteStore) migratePushTokenColumns() error {
	columnDefinitions := []string{
		"notifications_enabled INTEGER NOT NULL DEFAULT 0",
		"background_done_enabled INTEGER NOT NULL DEFAULT 1",
		"daily_question_enabled INTEGER NOT NULL DEFAULT 0",
		"repeated_theme_enabled INTEGER NOT NULL DEFAULT 1",
		"stage_forming_enabled INTEGER NOT NULL DEFAULT 1",
		"revisit_enabled INTEGER NOT NULL DEFAULT 1",
		"delivery_pace TEXT NOT NULL DEFAULT ''",
		"max_per_day INTEGER NOT NULL DEFAULT 0",
		"minimum_minutes_between_notifications INTEGER NOT NULL DEFAULT 0",
		"quiet_start TEXT NOT NULL DEFAULT ''",
		"quiet_end TEXT NOT NULL DEFAULT ''",
		"rich_previews_enabled INTEGER NOT NULL DEFAULT 0",
		"local_intelligence_enabled INTEGER NOT NULL DEFAULT 0",
		"cloud_intelligence_enabled INTEGER NOT NULL DEFAULT 0",
		"semantic_search_enabled INTEGER NOT NULL DEFAULT 0",
		"home_suggestions_enabled INTEGER NOT NULL DEFAULT 0",
	}
	for _, definition := range columnDefinitions {
		if err := s.addColumnIfMissing("push_tokens", definition); err != nil {
			return err
		}
	}
	return nil
}

func (s *SQLiteStore) migratePushDeliveryColumns() error {
	columnDefinitions := []string{
		"privacy_level TEXT NOT NULL DEFAULT ''",
		"deep_link TEXT NOT NULL DEFAULT ''",
		"payload_json TEXT NOT NULL DEFAULT ''",
		"attempt_count INTEGER NOT NULL DEFAULT 0",
		"next_attempt_at TEXT NOT NULL DEFAULT ''",
	}
	for _, definition := range columnDefinitions {
		if err := s.addColumnIfMissing("push_deliveries", definition); err != nil {
			return err
		}
	}
	return nil
}

func scanPushToken(scanner interface {
	Scan(dest ...any) error
}) (PushToken, error) {
	var token PushToken
	var hasQuestionReady int
	var notificationsEnabled int
	var backgroundDoneEnabled int
	var dailyQuestionEnabled int
	var repeatedThemeEnabled int
	var stageFormingEnabled int
	var revisitEnabled int
	var richPreviewsEnabled int
	var localIntelligenceEnabled int
	var cloudIntelligenceEnabled int
	var semanticSearchEnabled int
	var homeSuggestionsEnabled int
	var createdAt string
	var updatedAt string

	err := scanner.Scan(
		&token.UserID,
		&token.DeviceID,
		&token.APNSToken,
		&token.Timezone,
		&hasQuestionReady,
		&notificationsEnabled,
		&backgroundDoneEnabled,
		&dailyQuestionEnabled,
		&repeatedThemeEnabled,
		&stageFormingEnabled,
		&revisitEnabled,
		&token.DeliveryPace,
		&token.MaxPerDay,
		&token.MinimumMinutesBetweenNotifications,
		&token.QuietStart,
		&token.QuietEnd,
		&richPreviewsEnabled,
		&localIntelligenceEnabled,
		&cloudIntelligenceEnabled,
		&semanticSearchEnabled,
		&homeSuggestionsEnabled,
		&createdAt,
		&updatedAt,
	)
	if err != nil {
		return PushToken{}, fmt.Errorf("scan push token: %w", err)
	}

	token.HasQuestionReady = hasQuestionReady == 1
	token.NotificationsEnabled = notificationsEnabled == 1
	token.BackgroundDoneEnabled = backgroundDoneEnabled == 1
	token.DailyQuestionEnabled = dailyQuestionEnabled == 1
	token.RepeatedThemeEnabled = repeatedThemeEnabled == 1
	token.StageFormingEnabled = stageFormingEnabled == 1
	token.RevisitEnabled = revisitEnabled == 1
	token.RichPreviewsEnabled = richPreviewsEnabled == 1
	token.LocalIntelligenceEnabled = localIntelligenceEnabled == 1
	token.CloudIntelligenceEnabled = cloudIntelligenceEnabled == 1
	token.SemanticSearchEnabled = semanticSearchEnabled == 1
	token.HomeSuggestionsEnabled = homeSuggestionsEnabled == 1
	token.CreatedAt, _ = time.Parse(time.RFC3339, createdAt)
	token.UpdatedAt, _ = time.Parse(time.RFC3339, updatedAt)
	return token, nil
}

func scanPushDelivery(scanner interface {
	Scan(dest ...any) error
}) (PushDelivery, error) {
	var delivery PushDelivery
	var scheduledAt string
	var nextAttemptAt string
	var sentAt string
	var deliveredAt string
	var openedAt string
	var dismissedAt string
	var createdAt string
	var updatedAt string

	err := scanner.Scan(
		&delivery.UserID,
		&delivery.DeviceID,
		&delivery.IntentID,
		&delivery.Kind,
		&delivery.Title,
		&delivery.Body,
		&delivery.TargetType,
		&delivery.TargetID,
		&delivery.PrivacyLevel,
		&delivery.DeepLink,
		&delivery.PayloadJSON,
		&scheduledAt,
		&delivery.AttemptCount,
		&nextAttemptAt,
		&delivery.Status,
		&delivery.LastError,
		&sentAt,
		&deliveredAt,
		&openedAt,
		&dismissedAt,
		&createdAt,
		&updatedAt,
	)
	if err != nil {
		return PushDelivery{}, fmt.Errorf("scan push delivery: %w", err)
	}

	delivery.ScheduledAt, _ = time.Parse(time.RFC3339, scheduledAt)
	delivery.NextAttemptAt = parseOptionalTime(nextAttemptAt)
	delivery.SentAt = parseOptionalTime(sentAt)
	delivery.DeliveredAt = parseOptionalTime(deliveredAt)
	delivery.OpenedAt = parseOptionalTime(openedAt)
	delivery.DismissedAt = parseOptionalTime(dismissedAt)
	delivery.CreatedAt, _ = time.Parse(time.RFC3339, createdAt)
	delivery.UpdatedAt, _ = time.Parse(time.RFC3339, updatedAt)
	return delivery, nil
}

func scanPushDeliveryRow(row *sql.Row) (PushDelivery, error) {
	return scanPushDelivery(row)
}

func nullableRFC3339(value *time.Time) string {
	if value == nil || value.IsZero() {
		return ""
	}
	return value.UTC().Format(time.RFC3339)
}

func parseOptionalTime(value string) *time.Time {
	if strings.TrimSpace(value) == "" {
		return nil
	}
	parsed, err := time.Parse(time.RFC3339, value)
	if err != nil {
		return nil
	}
	return &parsed
}

func deliveryStatusForEventAction(action string) string {
	switch strings.TrimSpace(action) {
	case "delivered":
		return "delivered"
	case "opened":
		return "opened"
	case "dismissed":
		return "dismissed"
	default:
		return ""
	}
}

func (s *SQLiteStore) addColumnIfMissing(table string, definition string) error {
	stmt := fmt.Sprintf("ALTER TABLE %s ADD COLUMN %s;", table, definition)
	if _, err := s.db.Exec(stmt); err != nil {
		if strings.Contains(strings.ToLower(err.Error()), "duplicate column name") {
			return nil
		}
		return fmt.Errorf("add column %q to %s: %w", definition, table, err)
	}
	return nil
}

package db

import (
	"context"
	"fmt"
	"time"
)

func (s *SQLiteStore) UpsertPushToken(ctx context.Context, token PushToken) error {
	now := time.Now().UTC()
	const stmt = `
	INSERT INTO push_tokens (
		user_id,
		device_id,
		apns_token,
		timezone,
		has_question_ready,
		notifications_enabled,
		analysis_ready_enabled,
		daily_question_enabled,
		reflection_ready_enabled,
		delivery_pace,
		max_per_day,
		minimum_minutes_between_notifications,
		quiet_start,
		quiet_end,
		rich_previews_enabled,
		local_intelligence_enabled,
		cloud_intelligence_enabled,
		semantic_search_enabled,
		home_suggestions_enabled,
		created_at,
		updated_at
	)
	VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
	ON CONFLICT(user_id, device_id) DO UPDATE SET
	    apns_token = excluded.apns_token,
	    timezone = excluded.timezone,
	    has_question_ready = excluded.has_question_ready,
	    notifications_enabled = excluded.notifications_enabled,
	    analysis_ready_enabled = excluded.analysis_ready_enabled,
	    daily_question_enabled = excluded.daily_question_enabled,
	    reflection_ready_enabled = excluded.reflection_ready_enabled,
	    delivery_pace = excluded.delivery_pace,
	    max_per_day = excluded.max_per_day,
	    minimum_minutes_between_notifications = excluded.minimum_minutes_between_notifications,
	    quiet_start = excluded.quiet_start,
	    quiet_end = excluded.quiet_end,
	    rich_previews_enabled = excluded.rich_previews_enabled,
	    local_intelligence_enabled = excluded.local_intelligence_enabled,
	    cloud_intelligence_enabled = excluded.cloud_intelligence_enabled,
	    semantic_search_enabled = excluded.semantic_search_enabled,
	    home_suggestions_enabled = excluded.home_suggestions_enabled,
	    updated_at = excluded.updated_at;`
	_, err := s.db.ExecContext(
		ctx,
		stmt,
		token.UserID,
		token.DeviceID,
		token.APNSToken,
		token.Timezone,
		boolToInt(token.HasQuestionReady),
		boolToInt(token.NotificationsEnabled),
		boolToInt(token.AnalysisReadyEnabled),
		boolToInt(token.DailyQuestionEnabled),
		boolToInt(token.ReflectionReadyEnabled),
		token.DeliveryPace,
		token.MaxPerDay,
		token.MinimumMinutesBetweenNotifications,
		token.QuietStart,
		token.QuietEnd,
		boolToInt(token.RichPreviewsEnabled),
		boolToInt(token.LocalIntelligenceEnabled),
		boolToInt(token.CloudIntelligenceEnabled),
		boolToInt(token.SemanticSearchEnabled),
		boolToInt(token.HomeSuggestionsEnabled),
		now.Format(time.RFC3339),
		now.Format(time.RFC3339),
	)
	if err != nil {
		return fmt.Errorf("upsert push token: %w", err)
	}
	return nil
}

func (s *SQLiteStore) GetPushToken(ctx context.Context, userID, deviceID string) (PushToken, error) {
	const stmt = `
	SELECT
		user_id,
		device_id,
		apns_token,
		timezone,
		has_question_ready,
		notifications_enabled,
		analysis_ready_enabled,
		daily_question_enabled,
		reflection_ready_enabled,
		delivery_pace,
		max_per_day,
		minimum_minutes_between_notifications,
		quiet_start,
		quiet_end,
		rich_previews_enabled,
		local_intelligence_enabled,
		cloud_intelligence_enabled,
		semantic_search_enabled,
		home_suggestions_enabled,
		created_at,
		updated_at
	FROM push_tokens
WHERE user_id = ? AND device_id = ?;`

	return scanPushToken(s.db.QueryRowContext(ctx, stmt, userID, deviceID))
}

func (s *SQLiteStore) ListPushTokens(ctx context.Context, userID string) ([]PushToken, error) {
	const stmt = `
	SELECT
		user_id,
		device_id,
		apns_token,
		timezone,
		has_question_ready,
		notifications_enabled,
		analysis_ready_enabled,
		daily_question_enabled,
		reflection_ready_enabled,
		delivery_pace,
		max_per_day,
		minimum_minutes_between_notifications,
		quiet_start,
		quiet_end,
		rich_previews_enabled,
		local_intelligence_enabled,
		cloud_intelligence_enabled,
		semantic_search_enabled,
		home_suggestions_enabled,
		created_at,
		updated_at
	FROM push_tokens
	WHERE user_id = ?
	ORDER BY updated_at DESC;`
	rows, err := s.db.QueryContext(ctx, stmt, userID)
	if err != nil {
		return nil, fmt.Errorf("query push tokens: %w", err)
	}
	defer rows.Close()

	tokens := make([]PushToken, 0)
	for rows.Next() {
		token, err := scanPushToken(rows)
		if err != nil {
			return nil, err
		}
		tokens = append(tokens, token)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterate push tokens: %w", err)
	}
	return tokens, nil
}

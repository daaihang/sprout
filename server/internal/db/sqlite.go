package db

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"path/filepath"
	"strings"
	"time"

	_ "modernc.org/sqlite"
)

type PushToken struct {
	UserID               string    `json:"user_id"`
	DeviceID             string    `json:"device_id"`
	APNSToken            string    `json:"apns_token"`
	Timezone             string    `json:"timezone"`
	HasQuestionReady     bool      `json:"has_question_ready"`
	NotificationsEnabled bool      `json:"notifications_enabled"`
	BackgroundDoneEnabled bool     `json:"background_done_enabled"`
	DailyQuestionEnabled bool      `json:"daily_question_enabled"`
	RepeatedThemeEnabled bool      `json:"repeated_theme_enabled"`
	StageFormingEnabled  bool      `json:"stage_forming_enabled"`
	RevisitEnabled       bool      `json:"revisit_enabled"`
	DeliveryPace         string    `json:"delivery_pace,omitempty"`
	MaxPerDay            int       `json:"max_per_day,omitempty"`
	MinimumMinutesBetweenNotifications int `json:"minimum_minutes_between_notifications,omitempty"`
	QuietStart           string    `json:"quiet_start,omitempty"`
	QuietEnd             string    `json:"quiet_end,omitempty"`
	RichPreviewsEnabled  bool      `json:"rich_previews_enabled"`
	LocalIntelligenceEnabled bool  `json:"local_intelligence_enabled"`
	CloudIntelligenceEnabled bool  `json:"cloud_intelligence_enabled"`
	SemanticSearchEnabled bool     `json:"semantic_search_enabled"`
	HomeSuggestionsEnabled bool    `json:"home_suggestions_enabled"`
	CreatedAt            time.Time `json:"created_at,omitempty"`
	UpdatedAt            time.Time `json:"updated_at,omitempty"`
}

type PushDelivery struct {
	UserID      string     `json:"user_id"`
	DeviceID    string     `json:"device_id"`
	IntentID    string     `json:"intent_id"`
	Kind        string     `json:"kind"`
	Title       string     `json:"title"`
	Body        string     `json:"body"`
	TargetType  string     `json:"target_type"`
	TargetID    string     `json:"target_id"`
	ScheduledAt time.Time  `json:"scheduled_at"`
	Status      string     `json:"status"`
	LastError   string     `json:"last_error,omitempty"`
	SentAt      *time.Time `json:"sent_at,omitempty"`
	DeliveredAt *time.Time `json:"delivered_at,omitempty"`
	OpenedAt    *time.Time `json:"opened_at,omitempty"`
	DismissedAt *time.Time `json:"dismissed_at,omitempty"`
	CreatedAt   time.Time  `json:"created_at,omitempty"`
	UpdatedAt   time.Time  `json:"updated_at,omitempty"`
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
	UserID                  string    `json:"user_id"`
	HasCompletedOnboarding  bool      `json:"has_completed_onboarding"`
	CreatedAt               time.Time `json:"created_at,omitempty"`
	UpdatedAt               time.Time `json:"updated_at,omitempty"`
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
	InsertPushDeliveryEvent(ctx context.Context, event PushDeliveryEvent) error
	ListPushDeliveryEvents(ctx context.Context, userID string) ([]PushDeliveryEvent, error)
	Close() error
}

type UserProfileStore interface {
	GetOrCreateUserProfile(ctx context.Context, userID string) (UserProfile, bool, error)
	MarkOnboardingComplete(ctx context.Context, userID string) (UserProfile, error)
}

type SQLiteStore struct {
	db *sql.DB
}

func NewSQLiteStore(path string) (*SQLiteStore, error) {
	if path == "" {
		return nil, errors.New("sqlite path is required")
	}

	if path != ":memory:" {
		dir := filepath.Dir(path)
		if dir == "." || dir == "" {
			dir = "."
		}
		if err := ensureDir(dir); err != nil {
			return nil, err
		}
	}

	db, err := sql.Open("sqlite", path)
	if err != nil {
		return nil, fmt.Errorf("open sqlite: %w", err)
	}

	store := &SQLiteStore{db: db}
	if err := store.configure(); err != nil {
		_ = db.Close()
		return nil, err
	}
	if err := store.migrate(); err != nil {
		_ = db.Close()
		return nil, err
	}

	return store, nil
}

func (s *SQLiteStore) configure() error {
	statements := []string{
		`PRAGMA journal_mode = WAL;`,
		`PRAGMA synchronous = NORMAL;`,
		`PRAGMA busy_timeout = 5000;`,
		`PRAGMA foreign_keys = ON;`,
	}
	for _, stmt := range statements {
		if _, err := s.db.Exec(stmt); err != nil {
			return fmt.Errorf("configure sqlite with %q: %w", stmt, err)
		}
	}
	return nil
}

func (s *SQLiteStore) migrate() error {
	const stmt = `
CREATE TABLE IF NOT EXISTS push_tokens (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id TEXT NOT NULL,
    device_id TEXT NOT NULL,
    apns_token TEXT NOT NULL,
    timezone TEXT NOT NULL,
    has_question_ready INTEGER NOT NULL DEFAULT 0,
    notifications_enabled INTEGER NOT NULL DEFAULT 0,
    background_done_enabled INTEGER NOT NULL DEFAULT 1,
    daily_question_enabled INTEGER NOT NULL DEFAULT 0,
    repeated_theme_enabled INTEGER NOT NULL DEFAULT 1,
    stage_forming_enabled INTEGER NOT NULL DEFAULT 1,
    revisit_enabled INTEGER NOT NULL DEFAULT 1,
    delivery_pace TEXT NOT NULL DEFAULT '',
    max_per_day INTEGER NOT NULL DEFAULT 0,
    minimum_minutes_between_notifications INTEGER NOT NULL DEFAULT 0,
    quiet_start TEXT NOT NULL DEFAULT '',
    quiet_end TEXT NOT NULL DEFAULT '',
    rich_previews_enabled INTEGER NOT NULL DEFAULT 0,
    local_intelligence_enabled INTEGER NOT NULL DEFAULT 0,
    cloud_intelligence_enabled INTEGER NOT NULL DEFAULT 0,
    semantic_search_enabled INTEGER NOT NULL DEFAULT 0,
    home_suggestions_enabled INTEGER NOT NULL DEFAULT 0,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    UNIQUE(user_id, device_id)
);
CREATE TABLE IF NOT EXISTS push_deliveries (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id TEXT NOT NULL,
    device_id TEXT NOT NULL,
    intent_id TEXT NOT NULL,
    kind TEXT NOT NULL,
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    target_type TEXT NOT NULL,
    target_id TEXT NOT NULL,
    scheduled_at TEXT NOT NULL,
    status TEXT NOT NULL,
    last_error TEXT NOT NULL DEFAULT '',
    sent_at TEXT NOT NULL DEFAULT '',
    delivered_at TEXT NOT NULL DEFAULT '',
    opened_at TEXT NOT NULL DEFAULT '',
    dismissed_at TEXT NOT NULL DEFAULT '',
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    UNIQUE(user_id, device_id, intent_id)
);
CREATE TABLE IF NOT EXISTS push_delivery_events (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id TEXT NOT NULL,
    device_id TEXT NOT NULL,
    intent_id TEXT NOT NULL,
    action TEXT NOT NULL,
    kind TEXT NOT NULL,
    target_type TEXT NOT NULL,
    target_id TEXT NOT NULL,
    occurred_at TEXT NOT NULL,
    created_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS user_profiles (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id TEXT NOT NULL UNIQUE,
    has_completed_onboarding INTEGER NOT NULL DEFAULT 0,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
);`
	_, err := s.db.Exec(stmt)
	if err != nil {
		return fmt.Errorf("migrate sqlite schema: %w", err)
	}
	if err := s.migratePushTokenColumns(); err != nil {
		return err
	}
	return nil
}

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
		background_done_enabled,
		daily_question_enabled,
		repeated_theme_enabled,
		stage_forming_enabled,
		revisit_enabled,
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
	VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
	ON CONFLICT(user_id, device_id) DO UPDATE SET
	    apns_token = excluded.apns_token,
	    timezone = excluded.timezone,
	    has_question_ready = excluded.has_question_ready,
	    notifications_enabled = excluded.notifications_enabled,
	    background_done_enabled = excluded.background_done_enabled,
	    daily_question_enabled = excluded.daily_question_enabled,
	    repeated_theme_enabled = excluded.repeated_theme_enabled,
	    stage_forming_enabled = excluded.stage_forming_enabled,
	    revisit_enabled = excluded.revisit_enabled,
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
			boolToInt(token.BackgroundDoneEnabled),
			boolToInt(token.DailyQuestionEnabled),
			boolToInt(token.RepeatedThemeEnabled),
			boolToInt(token.StageFormingEnabled),
			boolToInt(token.RevisitEnabled),
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
		background_done_enabled,
		daily_question_enabled,
		repeated_theme_enabled,
		stage_forming_enabled,
		revisit_enabled,
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
		background_done_enabled,
		daily_question_enabled,
		repeated_theme_enabled,
		stage_forming_enabled,
		revisit_enabled,
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

func (s *SQLiteStore) UpsertPushDelivery(ctx context.Context, delivery PushDelivery) error {
	now := time.Now().UTC()
	scheduledAt := delivery.ScheduledAt.UTC()
	if scheduledAt.IsZero() {
		scheduledAt = now
	}
	status := strings.TrimSpace(delivery.Status)
	if status == "" {
		status = "pending"
	}

	const stmt = `
	INSERT INTO push_deliveries (
		user_id,
		device_id,
		intent_id,
		kind,
		title,
		body,
		target_type,
		target_id,
		scheduled_at,
		status,
		last_error,
		sent_at,
		delivered_at,
		opened_at,
		dismissed_at,
		created_at,
		updated_at
	)
	VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
	ON CONFLICT(user_id, device_id, intent_id) DO UPDATE SET
		kind = excluded.kind,
		title = excluded.title,
		body = excluded.body,
		target_type = excluded.target_type,
		target_id = excluded.target_id,
		scheduled_at = excluded.scheduled_at,
		status = excluded.status,
		last_error = excluded.last_error,
		sent_at = excluded.sent_at,
		delivered_at = excluded.delivered_at,
		opened_at = excluded.opened_at,
		dismissed_at = excluded.dismissed_at,
		updated_at = excluded.updated_at;`
	_, err := s.db.ExecContext(
		ctx,
		stmt,
		delivery.UserID,
		delivery.DeviceID,
		delivery.IntentID,
		delivery.Kind,
		delivery.Title,
		delivery.Body,
		delivery.TargetType,
		delivery.TargetID,
		scheduledAt.Format(time.RFC3339),
		status,
		strings.TrimSpace(delivery.LastError),
		nullableRFC3339(delivery.SentAt),
		nullableRFC3339(delivery.DeliveredAt),
		nullableRFC3339(delivery.OpenedAt),
		nullableRFC3339(delivery.DismissedAt),
		now.Format(time.RFC3339),
		now.Format(time.RFC3339),
	)
	if err != nil {
		return fmt.Errorf("upsert push delivery: %w", err)
	}
	return nil
}

func (s *SQLiteStore) GetPushDelivery(ctx context.Context, userID, deviceID, intentID string) (PushDelivery, error) {
	const stmt = `
	SELECT
		user_id,
		device_id,
		intent_id,
		kind,
		title,
		body,
		target_type,
		target_id,
		scheduled_at,
		status,
		last_error,
		sent_at,
		delivered_at,
		opened_at,
		dismissed_at,
		created_at,
		updated_at
	FROM push_deliveries
	WHERE user_id = ? AND device_id = ? AND intent_id = ?;`
	return scanPushDeliveryRow(s.db.QueryRowContext(ctx, stmt, userID, deviceID, intentID))
}

func (s *SQLiteStore) ListPushDeliveries(ctx context.Context, userID string) ([]PushDelivery, error) {
	const stmt = `
	SELECT
		user_id,
		device_id,
		intent_id,
		kind,
		title,
		body,
		target_type,
		target_id,
		scheduled_at,
		status,
		last_error,
		sent_at,
		delivered_at,
		opened_at,
		dismissed_at,
		created_at,
		updated_at
	FROM push_deliveries
	WHERE user_id = ?
	ORDER BY created_at ASC;`
	rows, err := s.db.QueryContext(ctx, stmt, userID)
	if err != nil {
		return nil, fmt.Errorf("query push deliveries: %w", err)
	}
	defer rows.Close()

	deliveries := make([]PushDelivery, 0)
	for rows.Next() {
		delivery, err := scanPushDelivery(rows)
		if err != nil {
			return nil, err
		}
		deliveries = append(deliveries, delivery)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterate push deliveries: %w", err)
	}
	return deliveries, nil
}

func (s *SQLiteStore) ListDuePushDeliveries(ctx context.Context, now time.Time, limit int) ([]PushDelivery, error) {
	if limit <= 0 {
		limit = 32
	}
	const stmt = `
	SELECT
		user_id,
		device_id,
		intent_id,
		kind,
		title,
		body,
		target_type,
		target_id,
		scheduled_at,
		status,
		last_error,
		sent_at,
		delivered_at,
		opened_at,
		dismissed_at,
		created_at,
		updated_at
	FROM push_deliveries
	WHERE status = 'pending' AND scheduled_at <= ?
	ORDER BY scheduled_at ASC, created_at ASC
	LIMIT ?;`
	rows, err := s.db.QueryContext(ctx, stmt, now.UTC().Format(time.RFC3339), limit)
	if err != nil {
		return nil, fmt.Errorf("query due push deliveries: %w", err)
	}
	defer rows.Close()

	deliveries := make([]PushDelivery, 0)
	for rows.Next() {
		delivery, err := scanPushDelivery(rows)
		if err != nil {
			return nil, err
		}
		deliveries = append(deliveries, delivery)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterate due push deliveries: %w", err)
	}
	return deliveries, nil
}

func (s *SQLiteStore) UpdatePushDeliveryStatus(
	ctx context.Context,
	userID, deviceID, intentID, status string,
	eventAt time.Time,
	lastError string,
) error {
	status = strings.TrimSpace(status)
	if status == "" {
		return nil
	}
	updateTime := eventAt.UTC()
	if updateTime.IsZero() {
		updateTime = time.Now().UTC()
	}

	deliveredAt := ""
	openedAt := ""
	dismissedAt := ""
	sentAt := ""
	switch status {
	case "sent":
		sentAt = updateTime.Format(time.RFC3339)
	case "delivered":
		deliveredAt = updateTime.Format(time.RFC3339)
	case "opened":
		deliveredAt = updateTime.Format(time.RFC3339)
		openedAt = updateTime.Format(time.RFC3339)
	case "dismissed":
		deliveredAt = updateTime.Format(time.RFC3339)
		dismissedAt = updateTime.Format(time.RFC3339)
	}

	const stmt = `
	UPDATE push_deliveries
	SET
		status = ?,
		last_error = ?,
		sent_at = CASE WHEN ? <> '' THEN ? ELSE sent_at END,
		delivered_at = CASE WHEN ? <> '' THEN COALESCE(NULLIF(delivered_at, ''), ?) ELSE delivered_at END,
		opened_at = CASE WHEN ? <> '' THEN ? ELSE opened_at END,
		dismissed_at = CASE WHEN ? <> '' THEN ? ELSE dismissed_at END,
		updated_at = ?
	WHERE user_id = ? AND device_id = ? AND intent_id = ?;`
	_, err := s.db.ExecContext(
		ctx,
		stmt,
		status,
		strings.TrimSpace(lastError),
		sentAt,
		sentAt,
		deliveredAt,
		deliveredAt,
		openedAt,
		openedAt,
		dismissedAt,
		dismissedAt,
		updateTime.Format(time.RFC3339),
		userID,
		deviceID,
		intentID,
	)
	if err != nil {
		return fmt.Errorf("update push delivery status: %w", err)
	}
	return nil
}

func (s *SQLiteStore) InsertPushDeliveryEvent(ctx context.Context, event PushDeliveryEvent) error {
	now := time.Now().UTC()
	occurredAt := event.OccurredAt.UTC()
	if occurredAt.IsZero() {
		occurredAt = now
	}
	const stmt = `
INSERT INTO push_delivery_events (
	user_id,
	device_id,
	intent_id,
	action,
	kind,
	target_type,
	target_id,
	occurred_at,
	created_at
)
VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?);`
	_, err := s.db.ExecContext(
		ctx,
		stmt,
		event.UserID,
		event.DeviceID,
		event.IntentID,
		event.Action,
		event.Kind,
		event.TargetType,
		event.TargetID,
		occurredAt.Format(time.RFC3339),
		now.Format(time.RFC3339),
	)
	if err != nil {
		return fmt.Errorf("insert push delivery event: %w", err)
	}
	if err := s.UpdatePushDeliveryStatus(
		ctx,
		event.UserID,
		event.DeviceID,
		event.IntentID,
		deliveryStatusForEventAction(event.Action),
		occurredAt,
		"",
	); err != nil {
		return err
	}
	return nil
}

func (s *SQLiteStore) ListPushDeliveryEvents(ctx context.Context, userID string) ([]PushDeliveryEvent, error) {
	const stmt = `
SELECT id, user_id, device_id, intent_id, action, kind, target_type, target_id, occurred_at, created_at
FROM push_delivery_events
WHERE user_id = ?
ORDER BY id ASC;`
	rows, err := s.db.QueryContext(ctx, stmt, userID)
	if err != nil {
		return nil, fmt.Errorf("query push delivery events: %w", err)
	}
	defer rows.Close()

	events := make([]PushDeliveryEvent, 0)
	for rows.Next() {
		var event PushDeliveryEvent
		var occurredAt string
		var createdAt string
		if err := rows.Scan(
			&event.ID,
			&event.UserID,
			&event.DeviceID,
			&event.IntentID,
			&event.Action,
			&event.Kind,
			&event.TargetType,
			&event.TargetID,
			&occurredAt,
			&createdAt,
		); err != nil {
			return nil, fmt.Errorf("scan push delivery event: %w", err)
		}
		event.OccurredAt, _ = time.Parse(time.RFC3339, occurredAt)
		event.CreatedAt, _ = time.Parse(time.RFC3339, createdAt)
		events = append(events, event)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterate push delivery events: %w", err)
	}
	return events, nil
}

func (s *SQLiteStore) GetOrCreateUserProfile(ctx context.Context, userID string) (UserProfile, bool, error) {
	now := time.Now().UTC().Format(time.RFC3339)
	const insertStmt = `
INSERT OR IGNORE INTO user_profiles (user_id, has_completed_onboarding, created_at, updated_at)
VALUES (?, 0, ?, ?);`
	result, err := s.db.ExecContext(ctx, insertStmt, userID, now, now)
	if err != nil {
		return UserProfile{}, false, fmt.Errorf("upsert user profile: %w", err)
	}
	rowsAffected, err := result.RowsAffected()
	if err != nil {
		return UserProfile{}, false, fmt.Errorf("read user profile rows affected: %w", err)
	}

	profile, err := s.getUserProfile(ctx, userID)
	if err != nil {
		return UserProfile{}, false, err
	}
	return profile, rowsAffected > 0, nil
}

func (s *SQLiteStore) MarkOnboardingComplete(ctx context.Context, userID string) (UserProfile, error) {
	profile, _, err := s.GetOrCreateUserProfile(ctx, userID)
	if err != nil {
		return UserProfile{}, err
	}
	if profile.HasCompletedOnboarding {
		return profile, nil
	}

	const updateStmt = `
UPDATE user_profiles
SET has_completed_onboarding = 1, updated_at = ?
WHERE user_id = ?;`
	if _, err := s.db.ExecContext(ctx, updateStmt, time.Now().UTC().Format(time.RFC3339), userID); err != nil {
		return UserProfile{}, fmt.Errorf("mark onboarding complete: %w", err)
	}
	return s.getUserProfile(ctx, userID)
}

func (s *SQLiteStore) getUserProfile(ctx context.Context, userID string) (UserProfile, error) {
	const query = `
SELECT user_id, has_completed_onboarding, created_at, updated_at
FROM user_profiles
WHERE user_id = ?;`

	var profile UserProfile
	var hasCompletedOnboarding int
	var createdAt string
	var updatedAt string

	err := s.db.QueryRowContext(ctx, query, userID).Scan(
		&profile.UserID,
		&hasCompletedOnboarding,
		&createdAt,
		&updatedAt,
	)
	if err != nil {
		return UserProfile{}, fmt.Errorf("get user profile: %w", err)
	}

	profile.HasCompletedOnboarding = hasCompletedOnboarding == 1
	profile.CreatedAt, _ = time.Parse(time.RFC3339, createdAt)
	profile.UpdatedAt, _ = time.Parse(time.RFC3339, updatedAt)
	return profile, nil
}

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
		&scheduledAt,
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

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
	DailyQuestionEnabled bool      `json:"daily_question_enabled"`
	DeliveryPace         string    `json:"delivery_pace,omitempty"`
	MaxPerDay            int       `json:"max_per_day,omitempty"`
	QuietStart           string    `json:"quiet_start,omitempty"`
	QuietEnd             string    `json:"quiet_end,omitempty"`
	CreatedAt            time.Time `json:"created_at,omitempty"`
	UpdatedAt            time.Time `json:"updated_at,omitempty"`
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
    daily_question_enabled INTEGER NOT NULL DEFAULT 0,
    delivery_pace TEXT NOT NULL DEFAULT '',
    max_per_day INTEGER NOT NULL DEFAULT 0,
    quiet_start TEXT NOT NULL DEFAULT '',
    quiet_end TEXT NOT NULL DEFAULT '',
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    UNIQUE(user_id, device_id)
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
	daily_question_enabled,
	delivery_pace,
	max_per_day,
	quiet_start,
	quiet_end,
	created_at,
	updated_at
)
VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
ON CONFLICT(user_id, device_id) DO UPDATE SET
    apns_token = excluded.apns_token,
    timezone = excluded.timezone,
    has_question_ready = excluded.has_question_ready,
    notifications_enabled = excluded.notifications_enabled,
    daily_question_enabled = excluded.daily_question_enabled,
    delivery_pace = excluded.delivery_pace,
    max_per_day = excluded.max_per_day,
    quiet_start = excluded.quiet_start,
    quiet_end = excluded.quiet_end,
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
		boolToInt(token.DailyQuestionEnabled),
		token.DeliveryPace,
		token.MaxPerDay,
		token.QuietStart,
		token.QuietEnd,
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
	daily_question_enabled,
	delivery_pace,
	max_per_day,
	quiet_start,
	quiet_end,
	created_at,
	updated_at
FROM push_tokens
WHERE user_id = ? AND device_id = ?;`

	var token PushToken
	var hasQuestionReady int
	var notificationsEnabled int
	var dailyQuestionEnabled int
	var createdAt string
	var updatedAt string

	err := s.db.QueryRowContext(ctx, stmt, userID, deviceID).Scan(
		&token.UserID,
		&token.DeviceID,
		&token.APNSToken,
		&token.Timezone,
		&hasQuestionReady,
		&notificationsEnabled,
		&dailyQuestionEnabled,
		&token.DeliveryPace,
		&token.MaxPerDay,
		&token.QuietStart,
		&token.QuietEnd,
		&createdAt,
		&updatedAt,
	)
	if err != nil {
		return PushToken{}, err
	}

	token.HasQuestionReady = hasQuestionReady == 1
	token.NotificationsEnabled = notificationsEnabled == 1
	token.DailyQuestionEnabled = dailyQuestionEnabled == 1
	token.CreatedAt, _ = time.Parse(time.RFC3339, createdAt)
	token.UpdatedAt, _ = time.Parse(time.RFC3339, updatedAt)
	return token, nil
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
		"daily_question_enabled INTEGER NOT NULL DEFAULT 0",
		"delivery_pace TEXT NOT NULL DEFAULT ''",
		"max_per_day INTEGER NOT NULL DEFAULT 0",
		"quiet_start TEXT NOT NULL DEFAULT ''",
		"quiet_end TEXT NOT NULL DEFAULT ''",
	}
	for _, definition := range columnDefinitions {
		if err := s.addColumnIfMissing("push_tokens", definition); err != nil {
			return err
		}
	}
	return nil
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

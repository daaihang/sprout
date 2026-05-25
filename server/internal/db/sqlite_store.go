package db

import (
	"database/sql"
	"errors"
	"fmt"
	"path/filepath"

	_ "modernc.org/sqlite"
)

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
    analysis_ready_enabled INTEGER NOT NULL DEFAULT 1,
    daily_question_enabled INTEGER NOT NULL DEFAULT 0,
    reflection_ready_enabled INTEGER NOT NULL DEFAULT 1,
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
    privacy_level TEXT NOT NULL DEFAULT '',
    deep_link TEXT NOT NULL DEFAULT '',
    payload_json TEXT NOT NULL DEFAULT '',
    scheduled_at TEXT NOT NULL,
    attempt_count INTEGER NOT NULL DEFAULT 0,
    next_attempt_at TEXT NOT NULL DEFAULT '',
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
	if err := s.migratePushDeliveryColumns(); err != nil {
		return err
	}
	return nil
}

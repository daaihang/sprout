package db

import (
	"context"
	"fmt"
	"time"
)

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

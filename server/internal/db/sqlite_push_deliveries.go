package db

import (
	"context"
	"fmt"
	"strings"
	"time"
)

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
		privacy_level,
		deep_link,
		payload_json,
		scheduled_at,
		attempt_count,
		next_attempt_at,
		status,
		last_error,
		sent_at,
		delivered_at,
		opened_at,
		dismissed_at,
		created_at,
		updated_at
	)
	VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
	ON CONFLICT(user_id, device_id, intent_id) DO UPDATE SET
		kind = excluded.kind,
		title = excluded.title,
		body = excluded.body,
		target_type = excluded.target_type,
		target_id = excluded.target_id,
		privacy_level = excluded.privacy_level,
		deep_link = excluded.deep_link,
		payload_json = excluded.payload_json,
		scheduled_at = excluded.scheduled_at,
		attempt_count = excluded.attempt_count,
		next_attempt_at = excluded.next_attempt_at,
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
		strings.TrimSpace(delivery.PrivacyLevel),
		strings.TrimSpace(delivery.DeepLink),
		strings.TrimSpace(delivery.PayloadJSON),
		scheduledAt.Format(time.RFC3339),
		delivery.AttemptCount,
		nullableRFC3339(delivery.NextAttemptAt),
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
		privacy_level,
		deep_link,
		payload_json,
		scheduled_at,
		attempt_count,
		next_attempt_at,
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
		privacy_level,
		deep_link,
		payload_json,
		scheduled_at,
		attempt_count,
		next_attempt_at,
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
		privacy_level,
		deep_link,
		payload_json,
		scheduled_at,
		attempt_count,
		next_attempt_at,
		status,
		last_error,
		sent_at,
		delivered_at,
		opened_at,
		dismissed_at,
		created_at,
		updated_at
	FROM push_deliveries
	WHERE status IN ('pending', 'retrying')
	  AND scheduled_at <= ?
	  AND (next_attempt_at = '' OR next_attempt_at <= ?)
	ORDER BY scheduled_at ASC, created_at ASC
	LIMIT ?;`
	nowText := now.UTC().Format(time.RFC3339)
	rows, err := s.db.QueryContext(ctx, stmt, nowText, nowText, limit)
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

func (s *SQLiteStore) UpdatePushDeliveryAttempt(
	ctx context.Context,
	userID, deviceID, intentID, status string,
	eventAt time.Time,
	lastError string,
	nextAttemptAt *time.Time,
	incrementAttempt bool,
) error {
	status = strings.TrimSpace(status)
	if status == "" {
		return nil
	}
	updateTime := eventAt.UTC()
	if updateTime.IsZero() {
		updateTime = time.Now().UTC()
	}
	nextAttempt := nullableRFC3339(nextAttemptAt)
	attemptIncrement := 0
	if incrementAttempt {
		attemptIncrement = 1
	}

	const stmt = `
	UPDATE push_deliveries
	SET
		status = ?,
		last_error = ?,
		attempt_count = attempt_count + ?,
		next_attempt_at = ?,
		updated_at = ?
	WHERE user_id = ? AND device_id = ? AND intent_id = ?;`
	_, err := s.db.ExecContext(
		ctx,
		stmt,
		status,
		strings.TrimSpace(lastError),
		attemptIncrement,
		nextAttempt,
		updateTime.Format(time.RFC3339),
		userID,
		deviceID,
		intentID,
	)
	if err != nil {
		return fmt.Errorf("update push delivery attempt: %w", err)
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

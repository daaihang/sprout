package notification

import (
	"context"
	"log/slog"
	"net/http"
	"path/filepath"
	"testing"
	"time"

	"sprout/server/internal/db"
)

func TestPushDeliveryWorkerRetriesTransientAPNSErrors(t *testing.T) {
	ctx := context.Background()
	store := newWorkerTestStore(t)
	now := time.Date(2026, 5, 19, 10, 0, 0, 0, time.UTC)
	insertWorkerTestToken(t, store)

	if err := store.UpsertPushDelivery(ctx, db.PushDelivery{
		UserID:      "user-1",
		DeviceID:    "device-1",
		IntentID:    "intent-1",
		Kind:        "dailyQuestion",
		Title:       "Mory",
		Body:        "A question is ready.",
		TargetType:  "question",
		TargetID:    "q1",
		ScheduledAt: now.Add(-time.Minute),
		Status:      "pending",
	}); err != nil {
		t.Fatalf("upsert delivery: %v", err)
	}

	worker := NewPushDeliveryWorkerWithOptions(
		store,
		failingAPNSClient{err: APNSError{StatusCode: http.StatusInternalServerError, Reason: "InternalServerError"}},
		slog.Default(),
		"com.speculolabs.mory",
		PushDeliveryWorkerOptions{MaxAttempts: 5, RetryBackoff: time.Minute},
	)

	report, err := worker.DeliverDue(ctx, now, 8)
	if err != nil {
		t.Fatalf("deliver due: %v", err)
	}
	if report.RetriedCount != 1 || report.PermanentFailedCount != 0 {
		t.Fatalf("unexpected report: %+v", report)
	}

	delivery, err := store.GetPushDelivery(ctx, "user-1", "device-1", "intent-1")
	if err != nil {
		t.Fatalf("get delivery: %v", err)
	}
	if delivery.Status != "retrying" || delivery.AttemptCount != 1 || delivery.NextAttemptAt == nil {
		t.Fatalf("expected retrying attempt with next time, got %+v", delivery)
	}

	metrics := worker.MetricsSnapshot()
	if metrics.Retried != 1 || metrics.Failed != 1 || metrics.PermanentFailed != 0 {
		t.Fatalf("unexpected metrics: %+v", metrics)
	}
}

func TestPushDeliveryWorkerPermanentlyFailsAfterMaxAttempts(t *testing.T) {
	ctx := context.Background()
	store := newWorkerTestStore(t)
	now := time.Date(2026, 5, 19, 10, 0, 0, 0, time.UTC)
	insertWorkerTestToken(t, store)

	if err := store.UpsertPushDelivery(ctx, db.PushDelivery{
		UserID:       "user-1",
		DeviceID:     "device-1",
		IntentID:     "intent-2",
		Kind:         "dailyQuestion",
		Title:        "Mory",
		Body:         "A question is ready.",
		TargetType:   "question",
		TargetID:     "q2",
		ScheduledAt:  now.Add(-time.Minute),
		AttemptCount: 4,
		Status:       "retrying",
	}); err != nil {
		t.Fatalf("upsert delivery: %v", err)
	}

	worker := NewPushDeliveryWorkerWithOptions(
		store,
		failingAPNSClient{err: APNSError{StatusCode: http.StatusInternalServerError, Reason: "InternalServerError"}},
		slog.Default(),
		"com.speculolabs.mory",
		PushDeliveryWorkerOptions{MaxAttempts: 5, RetryBackoff: time.Minute},
	)

	report, err := worker.DeliverDue(ctx, now, 8)
	if err != nil {
		t.Fatalf("deliver due: %v", err)
	}
	if report.PermanentFailedCount != 1 || report.RetriedCount != 0 {
		t.Fatalf("unexpected report: %+v", report)
	}

	delivery, err := store.GetPushDelivery(ctx, "user-1", "device-1", "intent-2")
	if err != nil {
		t.Fatalf("get delivery: %v", err)
	}
	if delivery.Status != "failed" || delivery.AttemptCount != 5 || delivery.NextAttemptAt != nil {
		t.Fatalf("expected failed final attempt, got %+v", delivery)
	}
}

func TestPushDeliveryWorkerDebugTestBypassesPacing(t *testing.T) {
	now := time.Date(2026, 5, 19, 10, 0, 0, 0, time.UTC)
	token := db.PushToken{
		DeviceID:                           "device-1",
		NotificationsEnabled:               true,
		DailyQuestionEnabled:               true,
		MaxPerDay:                          1,
		MinimumMinutesBetweenNotifications: 120,
	}
	deliveries := []db.PushDelivery{{
		DeviceID:    "device-1",
		Kind:        "dailyQuestion",
		Status:      "sent",
		ScheduledAt: now.Add(-time.Minute),
		SentAt:      &now,
	}}

	allowed, reason := deliveryAllowedForToken(token, "dailyQuestion", now.Add(time.Minute), deliveries)
	if allowed {
		t.Fatalf("expected normal daily question to be blocked by pacing")
	}
	if reason != "daily_cap" && reason != "minimum_interval" {
		t.Fatalf("expected pacing block reason, got %q", reason)
	}
	allowed, reason = deliveryAllowedForToken(token, "debugTest", now.Add(time.Minute), deliveries)
	if !allowed {
		t.Fatalf("expected debug test push to bypass pacing")
	}
	if reason != "" {
		t.Fatalf("expected no block reason, got %q", reason)
	}
}

func TestPushDeliveryWorkerDebugTestStillRequiresNotificationsEnabled(t *testing.T) {
	allowed, reason := deliveryAllowedForToken(db.PushToken{NotificationsEnabled: false}, "debugTest", time.Now(), nil)
	if allowed {
		t.Fatalf("expected debug test push to require notifications enabled")
	}
	if reason != "notifications_disabled" {
		t.Fatalf("expected notifications_disabled reason, got %q", reason)
	}
}

func newWorkerTestStore(t *testing.T) *db.SQLiteStore {
	t.Helper()
	store, err := db.NewSQLiteStore(filepath.Join(t.TempDir(), "worker.db"))
	if err != nil {
		t.Fatalf("new sqlite store: %v", err)
	}
	t.Cleanup(func() { _ = store.Close() })
	return store
}

func insertWorkerTestToken(t *testing.T, store *db.SQLiteStore) {
	t.Helper()
	if err := store.UpsertPushToken(context.Background(), db.PushToken{
		UserID:                             "user-1",
		DeviceID:                           "device-1",
		APNSToken:                          "token-1",
		Timezone:                           "UTC",
		NotificationsEnabled:               true,
		DailyQuestionEnabled:               true,
		AnalysisReadyEnabled:               true,
		ReflectionReadyEnabled:             true,
		MaxPerDay:                          10,
		MinimumMinutesBetweenNotifications: 0,
	}); err != nil {
		t.Fatalf("upsert token: %v", err)
	}
}

type failingAPNSClient struct {
	err error
}

func (c failingAPNSClient) Send(context.Context, APNSMessage) error {
	return c.err
}

package notification

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"strings"
	"sync"
	"sync/atomic"
	"time"

	"sprout/server/internal/db"
)

var ErrAPNSNotConfigured = errors.New("apns client is not configured")

type APNSMessage struct {
	DeviceToken  string
	Topic        string
	Title        string
	Body         string
	IntentID     string
	Kind         string
	TargetType   string
	TargetID     string
	PrivacyLevel string
	DeepLink     string
	Target       DeliveryTarget
	Payload      DeliveryPayload
}

type APNSClient interface {
	Send(ctx context.Context, message APNSMessage) error
}

type DisabledAPNSClient struct{}

func (DisabledAPNSClient) Send(_ context.Context, _ APNSMessage) error {
	return ErrAPNSNotConfigured
}

type DeliveryIntent struct {
	IntentID     string
	Kind         string
	Title        string
	Body         string
	TargetType   string
	TargetID     string
	PrivacyLevel string
	DeepLink     string
	Target       DeliveryTarget
	Payload      DeliveryPayload
	ScheduledAt  time.Time
}

type EnqueueReport struct {
	QueuedCount  int
	SkippedCount int
}

type DeliveryReport struct {
	DueCount             int
	SentCount            int
	FailedCount          int
	RetriedCount         int
	PermanentFailedCount int
}

type PushDeliveryWorker struct {
	store                 db.PushTokenStore
	client                APNSClient
	logger                *slog.Logger
	topic                 string
	maxAttempts           int
	retryBackoff          time.Duration
	alertFailureThreshold int
	metrics               *DeliveryWorkerMetrics
}

type PushDeliveryWorkerOptions struct {
	MaxAttempts           int
	RetryBackoff          time.Duration
	AlertFailureThreshold int
}

func NewPushDeliveryWorker(store db.PushTokenStore, client APNSClient, logger *slog.Logger, topic string) *PushDeliveryWorker {
	return NewPushDeliveryWorkerWithOptions(store, client, logger, topic, PushDeliveryWorkerOptions{})
}

func NewPushDeliveryWorkerWithOptions(store db.PushTokenStore, client APNSClient, logger *slog.Logger, topic string, options PushDeliveryWorkerOptions) *PushDeliveryWorker {
	if client == nil {
		client = DisabledAPNSClient{}
	}
	if strings.TrimSpace(topic) == "" {
		topic = "com.speculolabs.mory"
	}
	if options.MaxAttempts <= 0 {
		options.MaxAttempts = 5
	}
	if options.RetryBackoff <= 0 {
		options.RetryBackoff = 2 * time.Minute
	}
	if options.AlertFailureThreshold <= 0 {
		options.AlertFailureThreshold = 3
	}
	return &PushDeliveryWorker{
		store:                 store,
		client:                client,
		logger:                logger,
		topic:                 topic,
		maxAttempts:           options.MaxAttempts,
		retryBackoff:          options.RetryBackoff,
		alertFailureThreshold: options.AlertFailureThreshold,
		metrics:               NewDeliveryWorkerMetrics(),
	}
}

func (w *PushDeliveryWorker) EnqueueIntent(
	ctx context.Context,
	userID string,
	intent DeliveryIntent,
	now time.Time,
) (EnqueueReport, error) {
	tokens, err := w.store.ListPushTokens(ctx, userID)
	if err != nil {
		return EnqueueReport{}, err
	}
	existingDeliveries, err := w.store.ListPushDeliveries(ctx, userID)
	if err != nil {
		return EnqueueReport{}, err
	}

	report := EnqueueReport{}
	for _, token := range tokens {
		if !deliveryAllowedForToken(token, intent.Kind, intent.ScheduledAt, existingDeliveries) {
			report.SkippedCount++
			w.metrics.RecordSkipped()
			continue
		}
		if err := w.store.UpsertPushDelivery(ctx, db.PushDelivery{
			UserID:       userID,
			DeviceID:     token.DeviceID,
			IntentID:     intent.IntentID,
			Kind:         intent.Kind,
			Title:        intent.Title,
			Body:         intent.Body,
			TargetType:   intent.TargetType,
			TargetID:     intent.TargetID,
			PrivacyLevel: intent.PrivacyLevel,
			DeepLink:     intent.DeepLink,
			PayloadJSON:  payloadJSONString(NormalizeDeliveryPayload(intent)),
			ScheduledAt:  intent.ScheduledAt,
			Status:       "pending",
			CreatedAt:    now.UTC(),
			UpdatedAt:    now.UTC(),
		}); err != nil {
			return report, err
		}
		report.QueuedCount++
		w.metrics.RecordEnqueued()
	}
	return report, nil
}

func (w *PushDeliveryWorker) DeliverDue(ctx context.Context, now time.Time, limit int) (DeliveryReport, error) {
	deliveries, err := w.store.ListDuePushDeliveries(ctx, now, limit)
	if err != nil {
		w.metrics.RecordLoopError(err)
		return DeliveryReport{}, err
	}

	report := DeliveryReport{DueCount: len(deliveries)}
	w.metrics.RecordBatch(len(deliveries), now)
	for _, delivery := range deliveries {
		token, err := w.store.GetPushToken(ctx, delivery.UserID, delivery.DeviceID)
		if err != nil {
			report.PermanentFailedCount++
			report.FailedCount++
			w.metrics.RecordPermanentFailure(err)
			if updateErr := w.store.UpdatePushDeliveryAttempt(ctx, delivery.UserID, delivery.DeviceID, delivery.IntentID, "failed", now, err.Error(), nil, true); updateErr != nil {
				w.metrics.RecordLoopError(updateErr)
				return report, updateErr
			}
			continue
		}

		err = w.client.Send(ctx, APNSMessage{
			DeviceToken:  token.APNSToken,
			Topic:        w.topic,
			Title:        delivery.Title,
			Body:         delivery.Body,
			IntentID:     delivery.IntentID,
			Kind:         delivery.Kind,
			TargetType:   delivery.TargetType,
			TargetID:     delivery.TargetID,
			PrivacyLevel: delivery.PrivacyLevel,
			DeepLink:     delivery.DeepLink,
			Payload:      payloadFromJSONString(delivery.PayloadJSON),
		})
		if err != nil {
			report.FailedCount++
			nextAttemptAt, retryable := w.nextAttempt(delivery, now, err)
			if retryable {
				report.RetriedCount++
				w.metrics.RecordRetry(err)
				if updateErr := w.store.UpdatePushDeliveryAttempt(ctx, delivery.UserID, delivery.DeviceID, delivery.IntentID, "retrying", now, err.Error(), &nextAttemptAt, true); updateErr != nil {
					w.metrics.RecordLoopError(updateErr)
					return report, updateErr
				}
			} else {
				report.PermanentFailedCount++
				w.metrics.RecordPermanentFailure(err)
				if updateErr := w.store.UpdatePushDeliveryAttempt(ctx, delivery.UserID, delivery.DeviceID, delivery.IntentID, "failed", now, err.Error(), nil, true); updateErr != nil {
					w.metrics.RecordLoopError(updateErr)
					return report, updateErr
				}
			}
			if w.logger != nil {
				w.logger.Warn("push delivery failed",
					"user_id", delivery.UserID,
					"device_id", delivery.DeviceID,
					"intent_id", delivery.IntentID,
					"attempt_count", delivery.AttemptCount+1,
					"retryable", retryable,
					"next_attempt_at", nextAttemptAt.Format(time.RFC3339),
					"error", err.Error(),
				)
			}
			continue
		}

		report.SentCount++
		w.metrics.RecordSent()
		if err := w.store.UpdatePushDeliveryStatus(ctx, delivery.UserID, delivery.DeviceID, delivery.IntentID, "sent", now, ""); err != nil {
			w.metrics.RecordLoopError(err)
			return report, err
		}
	}

	w.metrics.RecordLoopSuccess()
	return report, nil
}

func (w *PushDeliveryWorker) MetricsSnapshot() DeliveryWorkerMetricsSnapshot {
	if w == nil || w.metrics == nil {
		return DeliveryWorkerMetricsSnapshot{}
	}
	return w.metrics.Snapshot()
}

func (w *PushDeliveryWorker) nextAttempt(delivery db.PushDelivery, now time.Time, err error) (time.Time, bool) {
	attempt := delivery.AttemptCount + 1
	if attempt >= w.maxAttempts || !retryablePushError(err) {
		return time.Time{}, false
	}
	delay := w.retryBackoff * time.Duration(1<<(attempt-1))
	if delay > 30*time.Minute {
		delay = 30 * time.Minute
	}
	return now.UTC().Add(delay), true
}

func retryablePushError(err error) bool {
	if err == nil {
		return false
	}
	if errors.Is(err, context.Canceled) || errors.Is(err, context.DeadlineExceeded) {
		return true
	}
	var apnsErr APNSError
	if errors.As(err, &apnsErr) {
		return apnsErr.Retryable()
	}
	return !errors.Is(err, ErrAPNSNotConfigured)
}

func (w *PushDeliveryWorker) RunScheduledDeliveryLoop(ctx context.Context, interval time.Duration, limit int) {
	if interval <= 0 {
		interval = 30 * time.Second
	}
	if limit <= 0 {
		limit = 32
	}

	ticker := time.NewTicker(interval)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			return
		case now := <-ticker.C:
			report, err := w.DeliverDue(ctx, now.UTC(), limit)
			if err != nil {
				if w.logger != nil {
					w.logger.Warn("scheduled push delivery failed", "error", err.Error())
				}
				continue
			}
			if report.FailedCount >= w.alertFailureThreshold && w.logger != nil {
				w.logger.Error("push delivery alert threshold reached",
					"failed", report.FailedCount,
					"retried", report.RetriedCount,
					"permanent_failed", report.PermanentFailedCount,
					"threshold", w.alertFailureThreshold,
				)
			}
			if w.logger != nil && (report.SentCount > 0 || report.FailedCount > 0) {
				w.logger.Info("scheduled push delivery complete",
					"due", report.DueCount,
					"sent", report.SentCount,
					"failed", report.FailedCount,
					"retried", report.RetriedCount,
					"permanent_failed", report.PermanentFailedCount,
				)
			}
		}
	}
}

type DeliveryWorkerMetrics struct {
	enqueued              atomic.Uint64
	skipped               atomic.Uint64
	batches               atomic.Uint64
	dueFetched            atomic.Uint64
	sent                  atomic.Uint64
	failed                atomic.Uint64
	retried               atomic.Uint64
	permanentFailed       atomic.Uint64
	loopErrors            atomic.Uint64
	consecutiveLoopErrors atomic.Uint64
	lastRunUnix           atomic.Int64
	lastSuccessUnix       atomic.Int64
	mu                    sync.Mutex
	lastError             string
}

type DeliveryWorkerMetricsSnapshot struct {
	Enqueued              uint64
	Skipped               uint64
	Batches               uint64
	DueFetched            uint64
	Sent                  uint64
	Failed                uint64
	Retried               uint64
	PermanentFailed       uint64
	LoopErrors            uint64
	ConsecutiveLoopErrors uint64
	LastRunUnix           int64
	LastSuccessUnix       int64
	LastError             string
}

func NewDeliveryWorkerMetrics() *DeliveryWorkerMetrics {
	return &DeliveryWorkerMetrics{}
}

func (m *DeliveryWorkerMetrics) RecordEnqueued() {
	m.enqueued.Add(1)
}

func (m *DeliveryWorkerMetrics) RecordSkipped() {
	m.skipped.Add(1)
}

func (m *DeliveryWorkerMetrics) RecordBatch(due int, now time.Time) {
	m.batches.Add(1)
	m.dueFetched.Add(uint64(maxInt(due, 0)))
	m.lastRunUnix.Store(now.UTC().Unix())
}

func (m *DeliveryWorkerMetrics) RecordSent() {
	m.sent.Add(1)
}

func (m *DeliveryWorkerMetrics) RecordRetry(err error) {
	m.failed.Add(1)
	m.retried.Add(1)
	m.setLastError(err)
}

func (m *DeliveryWorkerMetrics) RecordPermanentFailure(err error) {
	m.failed.Add(1)
	m.permanentFailed.Add(1)
	m.setLastError(err)
}

func (m *DeliveryWorkerMetrics) RecordLoopError(err error) {
	m.loopErrors.Add(1)
	m.consecutiveLoopErrors.Add(1)
	m.setLastError(err)
}

func (m *DeliveryWorkerMetrics) RecordLoopSuccess() {
	m.consecutiveLoopErrors.Store(0)
	m.lastSuccessUnix.Store(time.Now().UTC().Unix())
}

func (m *DeliveryWorkerMetrics) Snapshot() DeliveryWorkerMetricsSnapshot {
	m.mu.Lock()
	lastError := m.lastError
	m.mu.Unlock()
	return DeliveryWorkerMetricsSnapshot{
		Enqueued:              m.enqueued.Load(),
		Skipped:               m.skipped.Load(),
		Batches:               m.batches.Load(),
		DueFetched:            m.dueFetched.Load(),
		Sent:                  m.sent.Load(),
		Failed:                m.failed.Load(),
		Retried:               m.retried.Load(),
		PermanentFailed:       m.permanentFailed.Load(),
		LoopErrors:            m.loopErrors.Load(),
		ConsecutiveLoopErrors: m.consecutiveLoopErrors.Load(),
		LastRunUnix:           m.lastRunUnix.Load(),
		LastSuccessUnix:       m.lastSuccessUnix.Load(),
		LastError:             lastError,
	}
}

func (m *DeliveryWorkerMetrics) setLastError(err error) {
	if err == nil {
		return
	}
	m.mu.Lock()
	m.lastError = fmt.Sprintf("%T: %v", err, err)
	m.mu.Unlock()
}

func maxInt(a, b int) int {
	if a > b {
		return a
	}
	return b
}

func deliveryAllowedForToken(
	token db.PushToken,
	kind string,
	scheduledAt time.Time,
	existingDeliveries []db.PushDelivery,
) bool {
	if !token.NotificationsEnabled {
		return false
	}
	if token.MaxPerDay <= 0 {
		return false
	}
	if !kindEnabled(token, kind) {
		return false
	}
	if isInsideQuietHours(token, scheduledAt) {
		return false
	}
	if exceedsDailyCap(token, scheduledAt, existingDeliveries) {
		return false
	}
	if violatesMinimumInterval(token, scheduledAt, existingDeliveries) {
		return false
	}
	return true
}

func kindEnabled(token db.PushToken, kind string) bool {
	switch strings.TrimSpace(kind) {
	case "backgroundDone":
		return token.BackgroundDoneEnabled
	case "dailyQuestion":
		return token.DailyQuestionEnabled
	case "repeatedTheme":
		return token.RepeatedThemeEnabled
	case "stageForming":
		return token.StageFormingEnabled
	case "revisit":
		return token.RevisitEnabled
	default:
		return true
	}
}

func exceedsDailyCap(token db.PushToken, scheduledAt time.Time, deliveries []db.PushDelivery) bool {
	count := 0
	for _, delivery := range deliveries {
		if delivery.DeviceID != token.DeviceID {
			continue
		}
		if !countsTowardPacing(delivery.Status) {
			continue
		}
		referenceTime := pacingReferenceTime(delivery)
		if referenceTime.IsZero() {
			continue
		}
		if sameCalendarDay(referenceTime, scheduledAt, token.Timezone) {
			count++
		}
	}
	return count >= token.MaxPerDay
}

func violatesMinimumInterval(token db.PushToken, scheduledAt time.Time, deliveries []db.PushDelivery) bool {
	if token.MinimumMinutesBetweenNotifications <= 0 {
		return false
	}
	threshold := time.Duration(token.MinimumMinutesBetweenNotifications) * time.Minute
	for _, delivery := range deliveries {
		if delivery.DeviceID != token.DeviceID {
			continue
		}
		if !countsTowardPacing(delivery.Status) {
			continue
		}
		referenceTime := pacingReferenceTime(delivery)
		if referenceTime.IsZero() {
			continue
		}
		delta := scheduledAt.Sub(referenceTime)
		if delta < 0 {
			delta = -delta
		}
		if delta < threshold {
			return true
		}
	}
	return false
}

func countsTowardPacing(status string) bool {
	switch strings.TrimSpace(status) {
	case "sent", "delivered", "opened", "dismissed":
		return true
	default:
		return false
	}
}

func pacingReferenceTime(delivery db.PushDelivery) time.Time {
	switch {
	case delivery.SentAt != nil:
		return delivery.SentAt.UTC()
	case delivery.DeliveredAt != nil:
		return delivery.DeliveredAt.UTC()
	case delivery.OpenedAt != nil:
		return delivery.OpenedAt.UTC()
	case delivery.DismissedAt != nil:
		return delivery.DismissedAt.UTC()
	default:
		return delivery.UpdatedAt.UTC()
	}
}

func isInsideQuietHours(token db.PushToken, scheduledAt time.Time) bool {
	start := strings.TrimSpace(token.QuietStart)
	end := strings.TrimSpace(token.QuietEnd)
	if start == "" || end == "" || start == end {
		return false
	}

	location := time.UTC
	if strings.TrimSpace(token.Timezone) != "" {
		if loaded, err := time.LoadLocation(token.Timezone); err == nil {
			location = loaded
		}
	}
	localTime := scheduledAt.In(location)

	startMinutes, okStart := parseClockMinutes(start)
	endMinutes, okEnd := parseClockMinutes(end)
	if !okStart || !okEnd || startMinutes == endMinutes {
		return false
	}
	currentMinutes := localTime.Hour()*60 + localTime.Minute()
	if startMinutes < endMinutes {
		return currentMinutes >= startMinutes && currentMinutes < endMinutes
	}
	return currentMinutes >= startMinutes || currentMinutes < endMinutes
}

func parseClockMinutes(value string) (int, bool) {
	parts := strings.Split(strings.TrimSpace(value), ":")
	if len(parts) != 2 {
		return 0, false
	}
	hour, errHour := time.Parse("15", parts[0])
	minute, errMinute := time.Parse("04", parts[1])
	if errHour != nil || errMinute != nil {
		return 0, false
	}
	return hour.Hour()*60 + minute.Minute(), true
}

func sameCalendarDay(lhs, rhs time.Time, timezone string) bool {
	location := time.UTC
	if strings.TrimSpace(timezone) != "" {
		if loaded, err := time.LoadLocation(timezone); err == nil {
			location = loaded
		}
	}
	left := lhs.In(location)
	right := rhs.In(location)
	return left.Year() == right.Year() && left.YearDay() == right.YearDay()
}

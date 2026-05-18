package notification

import (
	"context"
	"errors"
	"log/slog"
	"strings"
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
	SentCount   int
	FailedCount int
}

type PushDeliveryWorker struct {
	store  db.PushTokenStore
	client APNSClient
	logger *slog.Logger
	topic  string
}

func NewPushDeliveryWorker(store db.PushTokenStore, client APNSClient, logger *slog.Logger, topic string) *PushDeliveryWorker {
	if client == nil {
		client = DisabledAPNSClient{}
	}
	if strings.TrimSpace(topic) == "" {
		topic = "com.speculolabs.mory"
	}
	return &PushDeliveryWorker{
		store:  store,
		client: client,
		logger: logger,
		topic:  topic,
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
	}
	return report, nil
}

func (w *PushDeliveryWorker) DeliverDue(ctx context.Context, now time.Time, limit int) (DeliveryReport, error) {
	deliveries, err := w.store.ListDuePushDeliveries(ctx, now, limit)
	if err != nil {
		return DeliveryReport{}, err
	}

	report := DeliveryReport{}
	for _, delivery := range deliveries {
		token, err := w.store.GetPushToken(ctx, delivery.UserID, delivery.DeviceID)
		if err != nil {
			report.FailedCount++
			_ = w.store.UpdatePushDeliveryStatus(ctx, delivery.UserID, delivery.DeviceID, delivery.IntentID, "failed", now, err.Error())
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
			_ = w.store.UpdatePushDeliveryStatus(ctx, delivery.UserID, delivery.DeviceID, delivery.IntentID, "failed", now, err.Error())
			if w.logger != nil {
				w.logger.Warn("push delivery failed", "user_id", delivery.UserID, "device_id", delivery.DeviceID, "intent_id", delivery.IntentID, "error", err.Error())
			}
			continue
		}

		report.SentCount++
		if err := w.store.UpdatePushDeliveryStatus(ctx, delivery.UserID, delivery.DeviceID, delivery.IntentID, "sent", now, ""); err != nil {
			return report, err
		}
	}

	return report, nil
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
			if w.logger != nil && (report.SentCount > 0 || report.FailedCount > 0) {
				w.logger.Info("scheduled push delivery complete", "sent", report.SentCount, "failed", report.FailedCount)
			}
		}
	}
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

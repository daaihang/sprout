package http

import (
	"encoding/json"
	"net/http"
	"strings"
	"time"

	"sprout/server/internal/auth"
	"sprout/server/internal/db"
	"sprout/server/internal/notification"
)

func (s *Server) handlePushRegister(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.ClaimsFromContext(r.Context())
	if !ok {
		writeError(w, http.StatusUnauthorized, "missing auth claims")
		return
	}

	var req pushRegisterRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid JSON body")
		return
	}
	if strings.TrimSpace(req.DeviceID) == "" || strings.TrimSpace(req.APNSToken) == "" || strings.TrimSpace(req.Timezone) == "" {
		writeError(w, http.StatusBadRequest, "device_id, apns_token, and timezone are required")
		return
	}

	if err := s.pushTokens.UpsertPushToken(r.Context(), db.PushToken{
		UserID:                             claims.UserID,
		DeviceID:                           strings.TrimSpace(req.DeviceID),
		APNSToken:                          strings.TrimSpace(req.APNSToken),
		Timezone:                           strings.TrimSpace(req.Timezone),
		HasQuestionReady:                   req.HasQuestionReady,
		NotificationsEnabled:               req.NotificationsEnabled,
		BackgroundDoneEnabled:              req.BackgroundDoneEnabled,
		DailyQuestionEnabled:               req.DailyQuestionEnabled,
		RepeatedThemeEnabled:               req.RepeatedThemeEnabled,
		StageFormingEnabled:                req.StageFormingEnabled,
		RevisitEnabled:                     req.RevisitEnabled,
		DeliveryPace:                       strings.TrimSpace(req.DeliveryPace),
		MaxPerDay:                          req.MaxPerDay,
		MinimumMinutesBetweenNotifications: req.MinimumMinutesBetweenNotifications,
		QuietStart:                         strings.TrimSpace(req.QuietStart),
		QuietEnd:                           strings.TrimSpace(req.QuietEnd),
		RichPreviewsEnabled:                req.RichPreviewsEnabled,
		LocalIntelligenceEnabled:           req.LocalIntelligenceEnabled,
		CloudIntelligenceEnabled:           req.CloudIntelligenceEnabled,
		SemanticSearchEnabled:              req.SemanticSearchEnabled,
		HomeSuggestionsEnabled:             req.HomeSuggestionsEnabled,
	}); err != nil {
		writeError(w, http.StatusInternalServerError, "failed to register push token")
		return
	}
	if s.logger != nil {
		s.logger.Info("push token registered",
			"user_id", claims.UserID,
			"device_id", strings.TrimSpace(req.DeviceID),
			"timezone", strings.TrimSpace(req.Timezone),
			"notifications_enabled", req.NotificationsEnabled,
			"daily_question_enabled", req.DailyQuestionEnabled,
			"has_question_ready", req.HasQuestionReady,
			"apns_token_len", len(strings.TrimSpace(req.APNSToken)),
		)
	}

	writeJSON(w, http.StatusOK, pushRegisterResponse{
		Registered: true,
		UserID:     claims.UserID,
	})
}

func (s *Server) handlePushEnqueue(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.ClaimsFromContext(r.Context())
	if !ok {
		writeError(w, http.StatusUnauthorized, "missing auth claims")
		return
	}
	if s.pushDeliveryWorker == nil {
		writeError(w, http.StatusInternalServerError, "push delivery worker is not configured")
		return
	}

	var req pushEnqueueRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid JSON body")
		return
	}

	intentID := strings.TrimSpace(req.IntentID)
	kind := strings.TrimSpace(req.Kind)
	title := strings.TrimSpace(req.Title)
	body := strings.TrimSpace(req.Body)
	targetType := strings.TrimSpace(req.TargetType)
	targetID := strings.TrimSpace(req.TargetID)
	if strings.TrimSpace(req.Target.Type) != "" {
		targetType = strings.TrimSpace(req.Target.Type)
	}
	if strings.TrimSpace(req.Target.ID) != "" {
		targetID = strings.TrimSpace(req.Target.ID)
	}
	if intentID == "" || kind == "" || title == "" || body == "" || targetType == "" || targetID == "" {
		writeError(w, http.StatusBadRequest, "intent_id, kind, title, body, target_type, and target_id are required")
		return
	}
	if !notification.SupportedTargetType(targetType) {
		writeError(w, http.StatusBadRequest, "target_type must be one of record, artifact, question, entity, place, theme, decision, chapter, or reflection")
		return
	}

	scheduledAt := time.Now().UTC()
	if rawScheduledAt := strings.TrimSpace(req.ScheduledAt); rawScheduledAt != "" {
		parsed, err := time.Parse(time.RFC3339, rawScheduledAt)
		if err != nil {
			writeError(w, http.StatusBadRequest, "scheduled_at must be RFC3339")
			return
		}
		scheduledAt = parsed.UTC()
	}

	enqueueReport, err := s.pushDeliveryWorker.EnqueueIntent(
		r.Context(),
		claims.UserID,
		notification.DeliveryIntent{
			IntentID:     intentID,
			Kind:         kind,
			Title:        title,
			Body:         body,
			TargetType:   targetType,
			TargetID:     targetID,
			PrivacyLevel: strings.TrimSpace(req.PrivacyLevel),
			DeepLink:     strings.TrimSpace(req.DeepLink),
			Target:       req.Target,
			Payload:      req.Payload,
			ScheduledAt:  scheduledAt,
		},
		time.Now().UTC(),
	)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "failed to enqueue push delivery")
		return
	}

	deliveryReport, err := s.pushDeliveryWorker.DeliverDue(r.Context(), time.Now().UTC(), 32)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "failed to deliver queued push notifications")
		return
	}
	if s.logger != nil {
		s.logger.Info("push enqueue complete",
			"user_id", claims.UserID,
			"intent_id", intentID,
			"kind", kind,
			"target_type", targetType,
			"target_id", targetID,
			"queued", enqueueReport.QueuedCount,
			"skipped", enqueueReport.SkippedCount,
			"due", deliveryReport.DueCount,
			"sent", deliveryReport.SentCount,
			"failed", deliveryReport.FailedCount,
			"retried", deliveryReport.RetriedCount,
			"permanent_failed", deliveryReport.PermanentFailedCount,
		)
	}

	writeJSON(w, http.StatusOK, pushEnqueueResponse{
		Accepted:             true,
		UserID:               claims.UserID,
		QueuedCount:          enqueueReport.QueuedCount,
		SkippedCount:         enqueueReport.SkippedCount,
		SentCount:            deliveryReport.SentCount,
		FailedCount:          deliveryReport.FailedCount,
		RetriedCount:         deliveryReport.RetriedCount,
		PermanentFailedCount: deliveryReport.PermanentFailedCount,
	})
}

func (s *Server) handlePushDeliveryWriteback(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.ClaimsFromContext(r.Context())
	if !ok {
		writeError(w, http.StatusUnauthorized, "missing auth claims")
		return
	}

	var req pushDeliveryWritebackRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid JSON body")
		return
	}

	deviceID := strings.TrimSpace(req.DeviceID)
	intentID := strings.TrimSpace(req.IntentID)
	action := strings.TrimSpace(req.Action)
	targetType := strings.TrimSpace(req.TargetType)
	targetID := strings.TrimSpace(req.TargetID)
	if deviceID == "" || intentID == "" || action == "" || targetType == "" || targetID == "" {
		writeError(w, http.StatusBadRequest, "device_id, intent_id, action, target_type, and target_id are required")
		return
	}

	occurredAt := time.Now().UTC()
	if rawOccurredAt := strings.TrimSpace(req.OccurredAt); rawOccurredAt != "" {
		parsed, err := time.Parse(time.RFC3339, rawOccurredAt)
		if err != nil {
			writeError(w, http.StatusBadRequest, "occurred_at must be RFC3339")
			return
		}
		occurredAt = parsed.UTC()
	}

	if err := s.pushTokens.InsertPushDeliveryEvent(r.Context(), db.PushDeliveryEvent{
		UserID:     claims.UserID,
		DeviceID:   deviceID,
		IntentID:   intentID,
		Action:     action,
		Kind:       strings.TrimSpace(req.Kind),
		TargetType: targetType,
		TargetID:   targetID,
		OccurredAt: occurredAt,
	}); err != nil {
		writeError(w, http.StatusInternalServerError, "failed to write push delivery event")
		return
	}

	writeJSON(w, http.StatusOK, pushDeliveryWritebackResponse{
		Accepted: true,
		UserID:   claims.UserID,
	})
}

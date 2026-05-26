package http

import (
	"bytes"
	"context"
	"encoding/base64"
	"encoding/json"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"sprout/server/internal/ai"
	"sprout/server/internal/auth"
	"sprout/server/internal/config"
	"sprout/server/internal/db"
	"sprout/server/internal/push"
	"sprout/server/internal/subscription"
)

func TestAuthAnalyzeAndPushFlow(t *testing.T) {
	store, err := db.NewSQLiteStore(":memory:")
	if err != nil {
		t.Fatalf("new sqlite store: %v", err)
	}
	t.Cleanup(func() { _ = store.Close() })

	cfg := config.Config{
		AppEnv:           "test",
		Port:             "8080",
		JWTSecret:        "test-secret",
		JWTIssuer:        "sprout-test",
		TokenTTL:         0,
		DevAuthEnabled:   true,
		DevAuthUserID:    "dev-user",
		DefaultTier:      "seed",
		SubscriptionMode: "mock",
		AIMode:           config.AIModeMock,
		AIProvider:       config.AIProviderMock,
		AppleAudiences:   []string{"com.speculolabs.mory"},
	}
	authenticator := auth.NewAuthenticator(cfg.JWTSecret, cfg.JWTIssuer, 24*time.Hour)
	pushClient := &testAPNSClient{}
	pushDeliveryWorker := push.NewPushDeliveryWorker(
		store,
		pushClient,
		slog.New(slog.NewTextHandler(io.Discard, nil)),
		"com.speculolabs.mory",
	)
	server := NewServer(Dependencies{
		Config:             cfg,
		Logger:             slog.New(slog.NewTextHandler(io.Discard, nil)),
		Authenticator:      authenticator,
		AppleVerifier:      nil,
		AIProvider:         ai.NewMockProvider(),
		Subscription:       subscription.NewService("mock", "seed"),
		PushTokens:         store,
		UserProfiles:       store,
		PushDeliveryWorker: pushDeliveryWorker,
	})

	token := issueDevToken(t, server, `{"identity_token":"tester-1"}`)
	refreshToken := issueDevRefreshToken(t, server, `{"identity_token":"tester-1"}`)

	t.Run("auth response includes onboarding state", func(t *testing.T) {
		req := httptest.NewRequest(http.MethodPost, "/auth/refresh", nil)
		req.Header.Set("Authorization", "Bearer "+refreshToken)
		rec := httptest.NewRecorder()

		server.Handler().ServeHTTP(rec, req)
		if rec.Code != http.StatusOK {
			t.Fatalf("refresh status = %d, body = %s", rec.Code, rec.Body.String())
		}

		var resp authResponse
		if err := json.Unmarshal(rec.Body.Bytes(), &resp); err != nil {
			t.Fatalf("decode refresh response: %v", err)
		}
		if resp.HasCompletedOnboarding {
			t.Fatalf("expected onboarding to be incomplete")
		}
	})

	t.Run("analyze", func(t *testing.T) {
		body := `{
			"client_request_id":"client-analysis-test",
			"record_shell":{"id":"rec-analysis","raw_text":"今天和妈妈看电影，很开心","capture_source":"composer","user_mood":"开心"},
			"artifacts":[{"id":"a1","kind":"text","title":"电影夜晚","summary":"和妈妈看电影","text_content":"今天和妈妈看电影，很开心"}],
			"known_entities":[{"id":"p1","kind":"person","name":"妈妈","aliases":["母亲"]}],
			"mood_evidence":[],
			"context_pack":{
				"pack_id":"pack-analysis",
				"target_record_id":"rec-analysis",
				"self_brief":{"self_entity_id":"self-1","aliases":["我"],"privacy_mode":"localFirst"},
				"known_profiles":[{"entity_id":"p1","kind":"person","display_name":"妈妈","relationship_to_user":"family","mention_count":4,"common_context_labels":["movie"],"inclusion_reason":"entity overlap"}],
				"related_memories":[{"record_id":"rec-old","title":"上次电影","snippet":"上次也和妈妈看电影后觉得开心。","score":0.82,"inclusion_reasons":["entity overlap"]}],
				"privacy_decisions":[{"source_type":"memory","source_id":"sensitive-old","action":"redact","reason":"sensitive boundary"}],
				"budget_report":{"max_profiles":8,"max_related_memories":12,"selected_profiles":1,"selected_related_memories":1,"dropped_by_privacy":1},
				"retrieval_report":{"semantic_search_status":"available","retrieval_sources":["semantic"],"candidate_memory_count":1}
			},
			"client_capabilities":{"supports_affect_snapshot":true,"supports_context_aware_reflection":true,"supports_proposal_only_writeback":true}
		}`
		req := httptest.NewRequest(http.MethodPost, "/api/analyze", bytes.NewBufferString(body))
		req.Header.Set("Authorization", "Bearer "+token)
		req.Header.Set("Content-Type", "application/json")
		rec := httptest.NewRecorder()

		server.Handler().ServeHTTP(rec, req)
		if rec.Code != http.StatusOK {
			t.Fatalf("analyze status = %d, body = %s", rec.Code, rec.Body.String())
		}

		var resp analyzeMemoryResponseEnvelope
		if err := json.Unmarshal(rec.Body.Bytes(), &resp); err != nil {
			t.Fatalf("decode analyze response: %v", err)
		}
		if resp.Meta.Provider != "mock" {
			t.Fatalf("expected mock provider, got %q", resp.Meta.Provider)
		}
		if resp.Meta.PromptVersion != ai.AnalysisPromptVersion {
			t.Fatalf("expected prompt version %q, got %q", ai.AnalysisPromptVersion, resp.Meta.PromptVersion)
		}
		if len(resp.AffectProposals) == 0 {
			t.Fatalf("expected affect proposals")
		}
		if len(resp.ReflectionCandidates) == 0 {
			t.Fatalf("expected context-aware reflection candidate")
		}
		if !containsString(resp.Quality.UncertaintyReasons, "sensitive_content_redacted") {
			t.Fatalf("expected privacy uncertainty reason, got %+v", resp.Quality)
		}
		if !containsString(resp.Quality.NeedsUserCheck, "tone") {
			t.Fatalf("expected tone user check, got %+v", resp.Quality)
		}
	})

	t.Run("complete onboarding", func(t *testing.T) {
		req := httptest.NewRequest(http.MethodPost, "/api/me/onboarding/complete", nil)
		req.Header.Set("Authorization", "Bearer "+token)
		rec := httptest.NewRecorder()

		server.Handler().ServeHTTP(rec, req)
		if rec.Code != http.StatusOK {
			t.Fatalf("complete onboarding status = %d, body = %s", rec.Code, rec.Body.String())
		}

		var resp onboardingCompleteResponse
		if err := json.Unmarshal(rec.Body.Bytes(), &resp); err != nil {
			t.Fatalf("decode onboarding complete response: %v", err)
		}
		if !resp.HasCompletedOnboarding {
			t.Fatalf("expected onboarding to be completed")
		}

		refreshReq := httptest.NewRequest(http.MethodPost, "/auth/refresh", nil)
		refreshReq.Header.Set("Authorization", "Bearer "+refreshToken)
		refreshRec := httptest.NewRecorder()

		server.Handler().ServeHTTP(refreshRec, refreshReq)
		if refreshRec.Code != http.StatusOK {
			t.Fatalf("refresh after onboarding status = %d, body = %s", refreshRec.Code, refreshRec.Body.String())
		}

		var refreshResp authResponse
		if err := json.Unmarshal(refreshRec.Body.Bytes(), &refreshResp); err != nil {
			t.Fatalf("decode post-onboarding refresh response: %v", err)
		}
		if !refreshResp.HasCompletedOnboarding {
			t.Fatalf("expected refreshed auth response to include completed onboarding")
		}
	})

	t.Run("push register upsert", func(t *testing.T) {
		body := `{"device_id":"iphone-1","apns_token":"token-a","timezone":"Asia/Shanghai","has_question_ready":true,"notifications_enabled":true,"analysis_ready_enabled":true,"daily_question_enabled":true,"reflection_ready_enabled":true,"delivery_pace":"balanced","max_per_day":3,"minimum_minutes_between_notifications":90,"quiet_start":"22:00","quiet_end":"07:00","rich_previews_enabled":true,"local_intelligence_enabled":true,"cloud_intelligence_enabled":true,"semantic_search_enabled":true,"home_suggestions_enabled":true}`
		req := httptest.NewRequest(http.MethodPost, "/api/push/register", bytes.NewBufferString(body))
		req.Header.Set("Authorization", "Bearer "+token)
		req.Header.Set("Content-Type", "application/json")
		rec := httptest.NewRecorder()

		server.Handler().ServeHTTP(rec, req)
		if rec.Code != http.StatusOK {
			t.Fatalf("push register status = %d, body = %s", rec.Code, rec.Body.String())
		}

		stored, err := store.GetPushToken(context.Background(), "tester-1", "iphone-1")
		if err != nil {
			t.Fatalf("get push token after insert: %v", err)
		}
		if stored.APNSToken != "token-a" || !stored.HasQuestionReady || !stored.NotificationsEnabled || !stored.DailyQuestionEnabled {
			t.Fatalf("unexpected stored token after insert: %+v", stored)
		}
		if !stored.AnalysisReadyEnabled || !stored.ReflectionReadyEnabled {
			t.Fatalf("expected expanded notification toggles to persist: %+v", stored)
		}
		if stored.DeliveryPace != "balanced" || stored.MaxPerDay != 3 || stored.MinimumMinutesBetweenNotifications != 90 || stored.QuietStart != "22:00" || stored.QuietEnd != "07:00" {
			t.Fatalf("unexpected push preference fields after insert: %+v", stored)
		}
		if !stored.RichPreviewsEnabled || !stored.LocalIntelligenceEnabled || !stored.CloudIntelligenceEnabled || !stored.SemanticSearchEnabled || !stored.HomeSuggestionsEnabled {
			t.Fatalf("expected expanded intelligence preference fields after insert: %+v", stored)
		}

		updateBody := `{"device_id":"iphone-1","apns_token":"token-b","timezone":"America/Los_Angeles","has_question_ready":false,"notifications_enabled":false,"analysis_ready_enabled":false,"daily_question_enabled":false,"reflection_ready_enabled":false,"delivery_pace":"light","max_per_day":1,"minimum_minutes_between_notifications":15,"quiet_start":"23:00","quiet_end":"08:00","rich_previews_enabled":false,"local_intelligence_enabled":false,"cloud_intelligence_enabled":false,"semantic_search_enabled":false,"home_suggestions_enabled":false}`
		updateReq := httptest.NewRequest(http.MethodPost, "/api/push/register", bytes.NewBufferString(updateBody))
		updateReq.Header.Set("Authorization", "Bearer "+token)
		updateReq.Header.Set("Content-Type", "application/json")
		updateRec := httptest.NewRecorder()

		server.Handler().ServeHTTP(updateRec, updateReq)
		if updateRec.Code != http.StatusOK {
			t.Fatalf("push register update status = %d, body = %s", updateRec.Code, updateRec.Body.String())
		}

		updated, err := store.GetPushToken(context.Background(), "tester-1", "iphone-1")
		if err != nil {
			t.Fatalf("get push token after update: %v", err)
		}
		if updated.APNSToken != "token-b" || updated.Timezone != "America/Los_Angeles" || updated.HasQuestionReady || updated.NotificationsEnabled || updated.DailyQuestionEnabled {
			t.Fatalf("unexpected stored token after update: %+v", updated)
		}
		if updated.AnalysisReadyEnabled || updated.ReflectionReadyEnabled {
			t.Fatalf("expected expanded notification toggles to update: %+v", updated)
		}
		if updated.DeliveryPace != "light" || updated.MaxPerDay != 1 || updated.MinimumMinutesBetweenNotifications != 15 || updated.QuietStart != "23:00" || updated.QuietEnd != "08:00" {
			t.Fatalf("unexpected push preference fields after update: %+v", updated)
		}
		if updated.RichPreviewsEnabled || updated.LocalIntelligenceEnabled || updated.CloudIntelligenceEnabled || updated.SemanticSearchEnabled || updated.HomeSuggestionsEnabled {
			t.Fatalf("expected expanded intelligence preference fields to update: %+v", updated)
		}
	})

	t.Run("push enqueue queues eligible registered device", func(t *testing.T) {
		registerBody := `{"device_id":"iphone-1","apns_token":"token-a","timezone":"Asia/Shanghai","has_question_ready":true,"notifications_enabled":true,"analysis_ready_enabled":true,"daily_question_enabled":true,"reflection_ready_enabled":true,"delivery_pace":"balanced","max_per_day":3,"minimum_minutes_between_notifications":90,"quiet_start":"22:00","quiet_end":"07:00","rich_previews_enabled":true,"local_intelligence_enabled":true,"cloud_intelligence_enabled":true,"semantic_search_enabled":true,"home_suggestions_enabled":true}`
		registerReq := httptest.NewRequest(http.MethodPost, "/api/push/register", bytes.NewBufferString(registerBody))
		registerReq.Header.Set("Authorization", "Bearer "+token)
		registerReq.Header.Set("Content-Type", "application/json")
		registerRec := httptest.NewRecorder()
		server.Handler().ServeHTTP(registerRec, registerReq)
		if registerRec.Code != http.StatusOK {
			t.Fatalf("push register before enqueue status = %d, body = %s", registerRec.Code, registerRec.Body.String())
		}

		pushClient.messages = nil
		body := `{"intent_id":"intent-queued-1","kind":"dailyQuestion","title":"Mory","body":"A question is ready.","target":{"type":"question","id":"question-1","label":"Evening reflection"},"privacy_level":"contextual","deep_link":"mory://home/question/question-1","scheduled_at":"2025-05-19T12:00:00Z"}`
		req := httptest.NewRequest(http.MethodPost, "/api/push/enqueue", bytes.NewBufferString(body))
		req.Header.Set("Authorization", "Bearer "+token)
		req.Header.Set("Content-Type", "application/json")
		rec := httptest.NewRecorder()

		server.Handler().ServeHTTP(rec, req)
		if rec.Code != http.StatusOK {
			t.Fatalf("push enqueue status = %d, body = %s", rec.Code, rec.Body.String())
		}
		var enqueueResp map[string]any
		if err := json.Unmarshal(rec.Body.Bytes(), &enqueueResp); err != nil {
			t.Fatalf("decode push enqueue response: %v", err)
		}
		if len(enqueueResp) != 4 {
			t.Fatalf("push enqueue response should only include enqueue fields: %+v", enqueueResp)
		}

		if len(pushClient.messages) != 0 {
			t.Fatalf("expected no synchronous APNS send, got %d", len(pushClient.messages))
		}
		delivery, err := store.GetPushDelivery(context.Background(), "tester-1", "iphone-1", "intent-queued-1")
		if err != nil {
			t.Fatalf("get push delivery after enqueue: %v", err)
		}
		if delivery.Status != "pending" || delivery.SentAt != nil {
			t.Fatalf("expected pending push delivery after enqueue, got %+v", delivery)
		}
		if !strings.Contains(delivery.PayloadJSON, `"target"`) || !strings.Contains(delivery.PayloadJSON, `"question"`) {
			t.Fatalf("expected stored production payload JSON, got %q", delivery.PayloadJSON)
		}

		report, err := pushDeliveryWorker.DeliverDue(context.Background(), time.Date(2025, 5, 19, 12, 1, 0, 0, time.UTC), 32)
		if err != nil {
			t.Fatalf("deliver due after enqueue: %v", err)
		}
		if report.SentCount != 1 {
			t.Fatalf("expected scheduled worker to send one notification, got %+v", report)
		}

		if len(pushClient.messages) != 1 {
			t.Fatalf("expected one APNS send after scheduled delivery, got %d", len(pushClient.messages))
		}
		if pushClient.messages[0].IntentID != "intent-queued-1" || pushClient.messages[0].Kind != "dailyQuestion" {
			t.Fatalf("unexpected APNS message: %+v", pushClient.messages[0])
		}
		if pushClient.messages[0].TargetType != "question" || pushClient.messages[0].TargetID != "question-1" || pushClient.messages[0].DeepLink == "" {
			t.Fatalf("expected full push target payload, got %+v", pushClient.messages[0])
		}

		delivery, err = store.GetPushDelivery(context.Background(), "tester-1", "iphone-1", "intent-queued-1")
		if err != nil {
			t.Fatalf("get push delivery after scheduled delivery: %v", err)
		}
		if delivery.Status != "sent" || delivery.SentAt == nil {
			t.Fatalf("expected sent push delivery, got %+v", delivery)
		}
	})

	t.Run("push delivery writeback inserts event", func(t *testing.T) {
		body := `{"device_id":"iphone-1","intent_id":"intent-queued-1","action":"opened","kind":"dailyQuestion","target_type":"question","target_id":"question-1","occurred_at":"2026-05-19T12:34:56Z"}`
		req := httptest.NewRequest(http.MethodPost, "/api/push/delivery-writeback", bytes.NewBufferString(body))
		req.Header.Set("Authorization", "Bearer "+token)
		req.Header.Set("Content-Type", "application/json")
		rec := httptest.NewRecorder()

		server.Handler().ServeHTTP(rec, req)
		if rec.Code != http.StatusOK {
			t.Fatalf("push delivery writeback status = %d, body = %s", rec.Code, rec.Body.String())
		}

		events, err := store.ListPushDeliveryEvents(context.Background(), "tester-1")
		if err != nil {
			t.Fatalf("list push delivery events: %v", err)
		}
		if len(events) != 1 {
			t.Fatalf("expected one delivery event, got %d", len(events))
		}
		event := events[0]
		if event.Action != "opened" || event.TargetType != "question" || event.TargetID != "question-1" || event.IntentID != "intent-queued-1" {
			t.Fatalf("unexpected delivery event: %+v", event)
		}

		queuedDelivery, err := store.GetPushDelivery(context.Background(), "tester-1", "iphone-1", "intent-queued-1")
		if err != nil {
			t.Fatalf("get queued push delivery after writeback: %v", err)
		}
		if queuedDelivery.Status != "opened" || queuedDelivery.OpenedAt == nil || queuedDelivery.DeliveredAt == nil {
			t.Fatalf("expected queued delivery to be updated by writeback, got %+v", queuedDelivery)
		}
	})

	t.Run("v6 cloud intelligence contracts use mock provider", func(t *testing.T) {
		cases := []struct {
			name   string
			path   string
			body   string
			assert func(t *testing.T, body []byte)
		}{
			{
				name: "refine transcript",
				path: "/api/intelligence/refine-transcript",
				body: `{"schema_version":1,"locale":"zh-Hans","record_id":"record-1","audio_artifact_id":"audio-1","raw_transcript":"今天 和 妈妈 看 电影 很 开心","style":"clean_spoken_memory","allow_title":true}`,
				assert: func(t *testing.T, body []byte) {
					var resp transcriptRefinementResponseEnvelope
					if err := json.Unmarshal(body, &resp); err != nil {
						t.Fatalf("decode transcript response: %v", err)
					}
					if resp.RefinedTranscript == "" || resp.Meta.Provider != "mock" {
						t.Fatalf("unexpected transcript response: %+v", resp)
					}
					if resp.Meta.PromptVersion != ai.V6PromptVersion {
						t.Fatalf("expected prompt version %q, got %q", ai.V6PromptVersion, resp.Meta.PromptVersion)
					}
				},
			},
			{
				name: "suggest questions",
				path: "/api/intelligence/suggest-questions",
				body: `{"schema_version":1,"locale":"zh-Hans","target":{"type":"entity","id":"person-1","kind":"person"},"evidence":[{"record_id":"record-1","snippet":"Alex joined dinner again."}],"known_profile":{"display_name":"Alex","aliases":[]},"user_preferences":{"allow_sensitive_questions":false,"question_tone":"evidence_based"}}`,
				assert: func(t *testing.T, body []byte) {
					var resp questionSuggestionResponseEnvelope
					if err := json.Unmarshal(body, &resp); err != nil {
						t.Fatalf("decode question response: %v", err)
					}
					if len(resp.Questions) == 0 || resp.Questions[0].Kind != "entityRelationship" {
						t.Fatalf("unexpected question response: %+v", resp)
					}
				},
			},
			{
				name: "suggest chapters",
				path: "/api/intelligence/suggest-chapters",
				body: `{"schema_version":1,"locale":"zh-Hans","time_window":{"start":"2026-05-01T00:00:00Z","end":"2026-05-18T23:59:59Z"},"signals":[{"kind":"theme","label":"career transition","record_count":7,"salience":0.74}],"evidence_snippets":[{"record_id":"record-1","snippet":"I updated my resume again."}]}`,
				assert: func(t *testing.T, body []byte) {
					var resp chapterSuggestionResponseEnvelope
					if err := json.Unmarshal(body, &resp); err != nil {
						t.Fatalf("decode chapter response: %v", err)
					}
					if len(resp.ChapterCandidates) == 0 || !resp.ChapterCandidates[0].RequiresConfirmation {
						t.Fatalf("unexpected chapter response: %+v", resp)
					}
				},
			},
			{
				name: "analyze photo",
				path: "/api/intelligence/analyze-photo",
				body: `{"schema_version":1,"locale":"zh-Hans","record_id":"record-1","photo_artifact_id":"photo-1","local_labels":["receipt","restaurant"],"ocr_text":"Table 4 total 128","metadata":{"source":"vision"}}`,
				assert: func(t *testing.T, body []byte) {
					var resp photoSemanticAnalysisResponseEnvelope
					if err := json.Unmarshal(body, &resp); err != nil {
						t.Fatalf("decode photo response: %v", err)
					}
					if resp.SemanticSummary == "" || len(resp.Tags) == 0 {
						t.Fatalf("unexpected photo response: %+v", resp)
					}
				},
			},
		}

		for _, tc := range cases {
			t.Run(tc.name, func(t *testing.T) {
				req := httptest.NewRequest(http.MethodPost, tc.path, bytes.NewBufferString(tc.body))
				req.Header.Set("Authorization", "Bearer "+token)
				req.Header.Set("Content-Type", "application/json")
				rec := httptest.NewRecorder()

				server.Handler().ServeHTTP(rec, req)
				if rec.Code != http.StatusOK {
					t.Fatalf("%s status = %d, body = %s", tc.path, rec.Code, rec.Body.String())
				}
				tc.assert(t, rec.Body.Bytes())
			})
		}

		t.Run("provider eval returns prompt version and cases", func(t *testing.T) {
			req := httptest.NewRequest(http.MethodPost, "/api/intelligence/eval", nil)
			req.Header.Set("Authorization", "Bearer "+token)
			rec := httptest.NewRecorder()

			server.Handler().ServeHTTP(rec, req)
			if rec.Code != http.StatusOK {
				t.Fatalf("provider eval status = %d, body = %s", rec.Code, rec.Body.String())
			}
			var resp cloudIntelligenceEvalResponse
			if err := json.Unmarshal(rec.Body.Bytes(), &resp); err != nil {
				t.Fatalf("decode provider eval response: %v", err)
			}
			if resp.PromptVersion != ai.V6PromptVersion || len(resp.Cases) < 2 {
				t.Fatalf("unexpected provider eval response: %+v", resp)
			}
		})
	})
}

func TestCloudIntelligenceRateLimitReturnsClassifiedError(t *testing.T) {
	store, err := db.NewSQLiteStore(":memory:")
	if err != nil {
		t.Fatalf("new sqlite store: %v", err)
	}
	t.Cleanup(func() { _ = store.Close() })

	cfg := config.Config{
		AppEnv:               "test",
		Port:                 "8080",
		JWTSecret:            "test-secret",
		JWTIssuer:            "sprout-test",
		DevAuthEnabled:       true,
		DevAuthUserID:        "dev-user",
		DefaultTier:          "seed",
		SubscriptionMode:     "mock",
		AIMode:               config.AIModeMock,
		AIProvider:           config.AIProviderMock,
		AIRateLimitPerMinute: 1,
	}
	server := NewServer(Dependencies{
		Config:        cfg,
		Logger:        slog.New(slog.NewTextHandler(io.Discard, nil)),
		Authenticator: auth.NewAuthenticator(cfg.JWTSecret, cfg.JWTIssuer, 24*time.Hour),
		AIProvider:    ai.NewMockProvider(),
		Subscription:  subscription.NewService("mock", "seed"),
		PushTokens:    store,
		UserProfiles:  store,
	})
	token := issueDevToken(t, server, `{"identity_token":"tester-rate"}`)
	body := `{"schema_version":1,"locale":"zh-Hans","record_id":"record-1","audio_artifact_id":"audio-1","raw_transcript":"hello world","style":"clean_spoken_memory","allow_title":true}`

	for i := 0; i < 2; i++ {
		req := httptest.NewRequest(http.MethodPost, "/api/intelligence/refine-transcript", bytes.NewBufferString(body))
		req.Header.Set("Authorization", "Bearer "+token)
		req.Header.Set("Content-Type", "application/json")
		rec := httptest.NewRecorder()
		server.Handler().ServeHTTP(rec, req)
		if i == 0 && rec.Code != http.StatusOK {
			t.Fatalf("first request status = %d, body = %s", rec.Code, rec.Body.String())
		}
		if i == 1 {
			if rec.Code != http.StatusTooManyRequests {
				t.Fatalf("second request status = %d, body = %s", rec.Code, rec.Body.String())
			}
			var resp errorResponse
			if err := json.Unmarshal(rec.Body.Bytes(), &resp); err != nil {
				t.Fatalf("decode rate limit error: %v", err)
			}
			if resp.Class != string(aiErrorClassRateLimit) || !resp.Retryable {
				t.Fatalf("unexpected rate limit error: %+v", resp)
			}
		}
	}
}

func TestRefreshRequiresRefreshToken(t *testing.T) {
	store, err := db.NewSQLiteStore(":memory:")
	if err != nil {
		t.Fatalf("new sqlite store: %v", err)
	}
	t.Cleanup(func() { _ = store.Close() })

	cfg := config.Config{
		AppEnv:           "test",
		Port:             "8080",
		JWTSecret:        "test-secret",
		JWTIssuer:        "sprout-test",
		DevAuthEnabled:   true,
		DevAuthUserID:    "dev-user",
		DefaultTier:      "seed",
		SubscriptionMode: "mock",
		AIMode:           config.AIModeMock,
		AIProvider:       config.AIProviderMock,
	}
	authenticator := auth.NewAuthenticator(cfg.JWTSecret, cfg.JWTIssuer, 24*time.Hour)
	server := NewServer(Dependencies{
		Config:        cfg,
		Logger:        slog.New(slog.NewTextHandler(io.Discard, nil)),
		Authenticator: authenticator,
		AppleVerifier: nil,
		AIProvider:    ai.NewMockProvider(),
		Subscription:  subscription.NewService("mock", "seed"),
		PushTokens:    store,
		UserProfiles:  store,
	})

	accessToken := issueDevToken(t, server, `{"identity_token":"tester-refresh"}`)
	req := httptest.NewRequest(http.MethodPost, "/auth/refresh", nil)
	req.Header.Set("Authorization", "Bearer "+accessToken)
	rec := httptest.NewRecorder()

	server.Handler().ServeHTTP(rec, req)
	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("expected 401 when using access token on refresh endpoint, got %d body=%s", rec.Code, rec.Body.String())
	}
}

func TestUnauthorizedAnalyze(t *testing.T) {
	store, err := db.NewSQLiteStore(":memory:")
	if err != nil {
		t.Fatalf("new sqlite store: %v", err)
	}
	t.Cleanup(func() { _ = store.Close() })

	server := NewServer(Dependencies{
		Config:        config.Config{AppEnv: "test"},
		Logger:        slog.New(slog.NewTextHandler(io.Discard, nil)),
		Authenticator: auth.NewAuthenticator("secret", "issuer", 24*time.Hour),
		AppleVerifier: nil,
		AIProvider:    ai.NewMockProvider(),
		Subscription:  subscription.NewService("mock", "seed"),
		PushTokens:    store,
		UserProfiles:  store,
	})

	req := httptest.NewRequest(http.MethodPost, "/api/analyze", bytes.NewBufferString(`{
		"client_request_id":"unauthorized-analysis",
		"record_shell":{"id":"rec-unauthorized","raw_text":"hi","capture_source":"composer"},
		"artifacts":[],
		"known_entities":[],
		"context_pack":{"pack_id":"pack-unauthorized","target_record_id":"rec-unauthorized"},
		"client_capabilities":{"supports_proposal_only_writeback":true}
	}`))
	req.Header.Set("Content-Type", "application/json")
	rec := httptest.NewRecorder()

	server.Handler().ServeHTTP(rec, req)
	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("expected 401, got %d", rec.Code)
	}
}

func TestAuthAppleDevelopmentFallbackAcceptsAppleJWTWhenVerificationFails(t *testing.T) {
	store, err := db.NewSQLiteStore(":memory:")
	if err != nil {
		t.Fatalf("new sqlite store: %v", err)
	}
	t.Cleanup(func() { _ = store.Close() })

	server := NewServer(Dependencies{
		Config: config.Config{
			AppEnv:           "test",
			DevAuthEnabled:   true,
			DefaultTier:      "seed",
			SubscriptionMode: "mock",
		},
		Logger:        slog.New(slog.NewTextHandler(io.Discard, nil)),
		Authenticator: auth.NewAuthenticator("secret", "issuer", 24*time.Hour),
		AppleVerifier: failingAppleVerifier{err: auth.ErrAppleAudienceMismatch},
		AIProvider:    ai.NewMockProvider(),
		Subscription:  subscription.NewService("mock", "seed"),
		PushTokens:    store,
		UserProfiles:  store,
	})

	body := `{"identity_token":"` + fakeAppleJWT(t, "apple-user-123") + `","nonce":"nonce"}`
	req := httptest.NewRequest(http.MethodPost, "/auth/apple", bytes.NewBufferString(body))
	req.Header.Set("Content-Type", "application/json")
	rec := httptest.NewRecorder()

	server.Handler().ServeHTTP(rec, req)
	if rec.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d, body = %s", rec.Code, rec.Body.String())
	}

	var resp authResponse
	if err := json.Unmarshal(rec.Body.Bytes(), &resp); err != nil {
		t.Fatalf("decode auth response: %v", err)
	}
	if resp.User.ID != "apple-user-123" {
		t.Fatalf("expected fallback user id, got %q", resp.User.ID)
	}
	if resp.Mode != "development_stub" {
		t.Fatalf("expected development_stub mode, got %q", resp.Mode)
	}
}

func TestMetricsAndRequestID(t *testing.T) {
	store, err := db.NewSQLiteStore(":memory:")
	if err != nil {
		t.Fatalf("new sqlite store: %v", err)
	}
	t.Cleanup(func() { _ = store.Close() })

	server := NewServer(Dependencies{
		Config:        config.Config{AppEnv: "test", RequestTimeout: 2 * time.Second, DevAuthEnabled: true, DevAuthUserID: "dev-user"},
		Logger:        slog.New(slog.NewTextHandler(io.Discard, nil)),
		Authenticator: auth.NewAuthenticator("secret", "issuer", 24*time.Hour),
		AIProvider:    ai.NewMockProvider(),
		Subscription:  subscription.NewService("mock", "seed"),
		PushTokens:    store,
		UserProfiles:  store,
	})

	req := httptest.NewRequest(http.MethodGet, "/healthz", nil)
	rec := httptest.NewRecorder()
	server.Handler().ServeHTTP(rec, req)
	if rec.Header().Get("X-Request-ID") == "" {
		t.Fatalf("expected X-Request-ID header")
	}

	metricsReq := httptest.NewRequest(http.MethodGet, "/metrics", nil)
	metricsRec := httptest.NewRecorder()
	server.Handler().ServeHTTP(metricsRec, metricsReq)
	if metricsRec.Code != http.StatusOK {
		t.Fatalf("metrics status = %d", metricsRec.Code)
	}
	if !strings.Contains(metricsRec.Body.String(), "requests_total") {
		t.Fatalf("expected metrics output, got %q", metricsRec.Body.String())
	}
	if !strings.Contains(metricsRec.Body.String(), "push_delivery_sent_total") {
		t.Fatalf("expected push delivery metrics output, got %q", metricsRec.Body.String())
	}
	if !strings.Contains(metricsRec.Body.String(), "cloud_intelligence_prompt_version_info") {
		t.Fatalf("expected cloud intelligence prompt version metric, got %q", metricsRec.Body.String())
	}
}

func TestAuthAppleRequiresIdentityTokenWhenDevDisabled(t *testing.T) {
	store, err := db.NewSQLiteStore(":memory:")
	if err != nil {
		t.Fatalf("new sqlite store: %v", err)
	}
	t.Cleanup(func() { _ = store.Close() })

	server := NewServer(Dependencies{
		Config:        config.Config{AppEnv: "test", DevAuthEnabled: false},
		Logger:        slog.New(slog.NewTextHandler(io.Discard, nil)),
		Authenticator: auth.NewAuthenticator("secret", "issuer", 24*time.Hour),
		AIProvider:    ai.NewMockProvider(),
		Subscription:  subscription.NewService("mock", "seed"),
		PushTokens:    store,
		UserProfiles:  store,
	})

	req := httptest.NewRequest(http.MethodPost, "/auth/apple", bytes.NewBufferString(`{"identity_token":""}`))
	req.Header.Set("Content-Type", "application/json")
	rec := httptest.NewRecorder()

	server.Handler().ServeHTTP(rec, req)
	if rec.Code != http.StatusBadRequest {
		t.Fatalf("expected 400, got %d", rec.Code)
	}
}

func TestCanonicalAnalysisRoutesAndSchema(t *testing.T) {
	store, err := db.NewSQLiteStore(":memory:")
	if err != nil {
		t.Fatalf("new sqlite store: %v", err)
	}
	t.Cleanup(func() { _ = store.Close() })

	cfg := config.Config{
		AppEnv:           "test",
		Port:             "8080",
		JWTSecret:        "test-secret",
		JWTIssuer:        "sprout-test",
		DevAuthEnabled:   true,
		DevAuthUserID:    "dev-user",
		DefaultTier:      "seed",
		SubscriptionMode: "mock",
		AIMode:           config.AIModeMock,
		AIProvider:       config.AIProviderMock,
	}
	authenticator := auth.NewAuthenticator(cfg.JWTSecret, cfg.JWTIssuer, 24*time.Hour)
	server := NewServer(Dependencies{
		Config:        cfg,
		Logger:        slog.New(slog.NewTextHandler(io.Discard, nil)),
		Authenticator: authenticator,
		AppleVerifier: nil,
		AIProvider:    ai.NewMockProvider(),
		Subscription:  subscription.NewService("mock", "seed"),
		PushTokens:    store,
		UserProfiles:  store,
	})

	token := issueDevToken(t, server, `{"identity_token":"tester-schema"}`)
	body := `{
		"client_request_id":"client-analysis-route-test",
		"record_shell":{"id":"rec-analysis-route","raw_text":"A local-first note about Linh.","capture_source":"composer"},
		"artifacts":[{"id":"a1","kind":"text","title":"Note","summary":"Local-first note","text_content":"A local-first note about Linh.","metadata":{"source":"composer"}}],
		"known_entities":[{"id":"p1","kind":"person","name":"Linh","aliases":["Linh Tran"]}],
		"mood_evidence":[],
		"context_pack":{"pack_id":"pack-analysis-route","target_record_id":"rec-analysis-route","budget_report":{"max_profiles":8,"max_related_memories":12},"retrieval_report":{"semantic_search_status":"disabled"}},
		"client_capabilities":{"supports_affect_snapshot":true,"supports_context_aware_reflection":true,"supports_proposal_only_writeback":true}
	}`

	analyzeReq := httptest.NewRequest(http.MethodPost, "/api/analyze", bytes.NewBufferString(body))
	analyzeReq.Header.Set("Authorization", "Bearer "+token)
	analyzeReq.Header.Set("Content-Type", "application/json")
	analyzeRec := httptest.NewRecorder()
	server.Handler().ServeHTTP(analyzeRec, analyzeReq)
	if analyzeRec.Code != http.StatusOK {
		t.Fatalf("canonical analyze status = %d, body = %s", analyzeRec.Code, analyzeRec.Body.String())
	}

	previewReq := httptest.NewRequest(http.MethodPost, "/api/analysis/"+"preview", bytes.NewBufferString(body))
	previewReq.Header.Set("Content-Type", "application/json")
	previewRec := httptest.NewRecorder()
	server.Handler().ServeHTTP(previewRec, previewReq)
	if previewRec.Code != http.StatusNotFound {
		t.Fatalf("analysis preview route should be removed, got %d", previewRec.Code)
	}

	legacyReq := httptest.NewRequest(http.MethodPost, "/api/analysis/"+"records", bytes.NewBufferString(body))
	legacyReq.Header.Set("Authorization", "Bearer "+token)
	legacyReq.Header.Set("Content-Type", "application/json")
	legacyRec := httptest.NewRecorder()
	server.Handler().ServeHTTP(legacyRec, legacyReq)
	if legacyRec.Code != http.StatusNotFound {
		t.Fatalf("analysis records route should be removed, got %d", legacyRec.Code)
	}

	vRouteReq := httptest.NewRequest(http.MethodPost, "/api/analyze/"+"v"+"7", bytes.NewBufferString(body))
	vRouteReq.Header.Set("Authorization", "Bearer "+token)
	vRouteReq.Header.Set("Content-Type", "application/json")
	vRouteRec := httptest.NewRecorder()
	server.Handler().ServeHTTP(vRouteRec, vRouteReq)
	if vRouteRec.Code != http.StatusNotFound {
		t.Fatalf("versioned analyze route should be removed, got %d", vRouteRec.Code)
	}
}

func TestReflectionRoutes(t *testing.T) {
	store, err := db.NewSQLiteStore(":memory:")
	if err != nil {
		t.Fatalf("new sqlite store: %v", err)
	}
	t.Cleanup(func() { _ = store.Close() })

	cfg := config.Config{
		AppEnv:           "test",
		Port:             "8080",
		JWTSecret:        "test-secret",
		JWTIssuer:        "sprout-test",
		DevAuthEnabled:   true,
		DevAuthUserID:    "dev-user",
		DefaultTier:      "seed",
		SubscriptionMode: "mock",
		AIMode:           config.AIModeMock,
		AIProvider:       config.AIProviderMock,
	}
	authenticator := auth.NewAuthenticator(cfg.JWTSecret, cfg.JWTIssuer, 24*time.Hour)
	server := NewServer(Dependencies{
		Config:        cfg,
		Logger:        slog.New(slog.NewTextHandler(io.Discard, nil)),
		Authenticator: authenticator,
		AppleVerifier: nil,
		AIProvider:    ai.NewMockProvider(),
		Subscription:  subscription.NewService("mock", "seed"),
		PushTokens:    store,
		UserProfiles:  store,
	})

	token := issueDevToken(t, server, `{"identity_token":"tester-reflection"}`)
	body := `{
		"record_shell":{"id":"r1","raw_text":"Dinner with Linh clarified the quarter plan.","capture_source":"composer","input_context":"typed in debug"},
		"artifacts":[{"id":"a1","kind":"text","title":"Dinner note","summary":"Planning dinner","text_content":"Dinner with Linh clarified the quarter plan.","metadata":{"source":"composer"}}],
		"known_entities":[{"id":"p1","kind":"person","name":"Linh","aliases":["Linh Tran"]}]
	}`

	generateReq := httptest.NewRequest(http.MethodPost, "/api/reflections/generate", bytes.NewBufferString(body))
	generateReq.Header.Set("Authorization", "Bearer "+token)
	generateReq.Header.Set("Content-Type", "application/json")
	generateRec := httptest.NewRecorder()
	server.Handler().ServeHTTP(generateRec, generateReq)
	if generateRec.Code != http.StatusOK {
		t.Fatalf("reflection generate status = %d, body = %s", generateRec.Code, generateRec.Body.String())
	}

	var generateResp reflectionResponse
	if err := json.Unmarshal(generateRec.Body.Bytes(), &generateResp); err != nil {
		t.Fatalf("decode reflection generate response: %v", err)
	}
	if strings.TrimSpace(generateResp.Body) == "" {
		t.Fatalf("expected reflection body")
	}
	if generateResp.Meta.Provider != "mock" {
		t.Fatalf("expected reflection meta provider, got %q", generateResp.Meta.Provider)
	}

	replayBody := `{
		"record_shell":{"id":"r1","raw_text":"Dinner with Linh clarified the quarter plan.","capture_source":"composer"},
		"artifacts":[],
		"linked_arc_id":"arc-1",
		"prompt":"Restate the reflection with more emphasis on the planning pattern."
	}`
	replayReq := httptest.NewRequest(http.MethodPost, "/api/reflections/replay", bytes.NewBufferString(replayBody))
	replayReq.Header.Set("Authorization", "Bearer "+token)
	replayReq.Header.Set("Content-Type", "application/json")
	replayRec := httptest.NewRecorder()
	server.Handler().ServeHTTP(replayRec, replayReq)
	if replayRec.Code != http.StatusOK {
		t.Fatalf("reflection replay status = %d, body = %s", replayRec.Code, replayRec.Body.String())
	}

	var replayResp reflectionResponse
	if err := json.Unmarshal(replayRec.Body.Bytes(), &replayResp); err != nil {
		t.Fatalf("decode reflection replay response: %v", err)
	}
	if strings.TrimSpace(replayResp.Body) == "" {
		t.Fatalf("expected replay body, got %q", replayResp.Body)
	}
	if replayResp.Meta.Provider != "mock" {
		t.Fatalf("expected reflection replay meta provider, got %q", replayResp.Meta.Provider)
	}
}

func issueDevToken(t *testing.T, server *Server, body string) string {
	t.Helper()
	req := httptest.NewRequest(http.MethodPost, "/auth/apple", bytes.NewBufferString(body))
	req.Header.Set("Content-Type", "application/json")
	rec := httptest.NewRecorder()

	server.Handler().ServeHTTP(rec, req)
	if rec.Code != http.StatusOK {
		t.Fatalf("auth status = %d, body = %s", rec.Code, rec.Body.String())
	}

	var resp authResponse
	if err := json.Unmarshal(rec.Body.Bytes(), &resp); err != nil {
		t.Fatalf("decode auth response: %v", err)
	}
	return resp.AccessToken
}

func issueDevRefreshToken(t *testing.T, server *Server, body string) string {
	t.Helper()
	req := httptest.NewRequest(http.MethodPost, "/auth/apple", bytes.NewBufferString(body))
	req.Header.Set("Content-Type", "application/json")
	rec := httptest.NewRecorder()

	server.Handler().ServeHTTP(rec, req)
	if rec.Code != http.StatusOK {
		t.Fatalf("auth status = %d, body = %s", rec.Code, rec.Body.String())
	}

	var resp authResponse
	if err := json.Unmarshal(rec.Body.Bytes(), &resp); err != nil {
		t.Fatalf("decode auth response: %v", err)
	}
	if strings.TrimSpace(resp.RefreshToken) == "" {
		t.Fatalf("expected refresh token in auth response")
	}
	return resp.RefreshToken
}

type failingAppleVerifier struct {
	err error
}

func (v failingAppleVerifier) VerifyIdentityToken(_ context.Context, _, _ string) (auth.AppleIdentity, error) {
	return auth.AppleIdentity{}, v.err
}

type testAPNSClient struct {
	messages []push.APNSMessage
}

func (c *testAPNSClient) Send(_ context.Context, message push.APNSMessage) error {
	c.messages = append(c.messages, message)
	return nil
}

func fakeAppleJWT(t *testing.T, sub string) string {
	t.Helper()

	headerJSON := `{"alg":"ES256","kid":"test","typ":"JWT"}`
	claimsJSON := `{"iss":"https://appleid.apple.com","aud":"com.speculolabs.mory","exp":4102444800,"sub":"` + sub + `"}`

	return base64.RawURLEncoding.EncodeToString([]byte(headerJSON)) + "." +
		base64.RawURLEncoding.EncodeToString([]byte(claimsJSON)) + "." +
		base64.RawURLEncoding.EncodeToString([]byte("signature"))
}

func containsString(values []string, needle string) bool {
	for _, value := range values {
		if value == needle {
			return true
		}
	}
	return false
}

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
			"schema_version":"record_aggregate.v1",
			"analysis_reason":"manual",
			"record_shell":{"raw_text":"今天和妈妈看了一部电影，感觉很开心","capture_source":"composer"},
			"artifacts":[{"id":"a1","kind":"text","title":"电影夜晚","summary":"和妈妈看电影","text_content":"今天和妈妈看了一部电影，感觉很开心"}],
			"known_entities":[{"id":"p1","kind":"person","name":"妈妈","aliases":["母亲"]}]
		}`
		req := httptest.NewRequest(http.MethodPost, "/api/analysis/records", bytes.NewBufferString(body))
		req.Header.Set("Authorization", "Bearer "+token)
		req.Header.Set("Content-Type", "application/json")
		rec := httptest.NewRecorder()

		server.Handler().ServeHTTP(rec, req)
		if rec.Code != http.StatusOK {
			t.Fatalf("analyze status = %d, body = %s", rec.Code, rec.Body.String())
		}

		var resp analyzeResponseEnvelope
		if err := json.Unmarshal(rec.Body.Bytes(), &resp); err != nil {
			t.Fatalf("decode analyze response: %v", err)
		}
		if resp.Meta.Provider != "mock" {
			t.Fatalf("expected mock provider, got %q", resp.Meta.Provider)
		}
		if len(resp.Tags) == 0 {
			t.Fatalf("expected tags in analyze response")
		}
	})

	t.Run("analyze preview", func(t *testing.T) {
		body := `{
			"schema_version":"record_aggregate.v1",
			"analysis_reason":"preview",
			"record_shell":{"raw_text":"今天和妈妈看了一部电影，感觉很开心","capture_source":"composer"},
			"artifacts":[{"id":"a1","kind":"text","title":"电影夜晚","summary":"和妈妈看电影","text_content":"今天和妈妈看了一部电影，感觉很开心"}],
			"known_entities":[]
		}`
		req := httptest.NewRequest(http.MethodPost, "/api/analysis/preview", bytes.NewBufferString(body))
		req.Header.Set("Content-Type", "application/json")
		rec := httptest.NewRecorder()

		server.Handler().ServeHTTP(rec, req)
		if rec.Code != http.StatusOK {
			t.Fatalf("preview status = %d, body = %s", rec.Code, rec.Body.String())
		}

		var resp analyzePreviewResponseEnvelope
		if err := json.Unmarshal(rec.Body.Bytes(), &resp); err != nil {
			t.Fatalf("decode preview response: %v", err)
		}
		if resp.Mode != "preview" {
			t.Fatalf("expected preview mode, got %q", resp.Mode)
		}
		if len(resp.Tags) == 0 {
			t.Fatalf("expected preview tags in response")
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
		body := `{"device_id":"iphone-1","apns_token":"token-a","timezone":"Asia/Shanghai","has_question_ready":true,"notifications_enabled":true,"daily_question_enabled":true,"delivery_pace":"balanced","max_per_day":3,"quiet_start":"22:00","quiet_end":"07:00"}`
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
		if stored.DeliveryPace != "balanced" || stored.MaxPerDay != 3 || stored.QuietStart != "22:00" || stored.QuietEnd != "07:00" {
			t.Fatalf("unexpected push preference fields after insert: %+v", stored)
		}

		updateBody := `{"device_id":"iphone-1","apns_token":"token-b","timezone":"America/Los_Angeles","has_question_ready":false,"notifications_enabled":false,"daily_question_enabled":false,"delivery_pace":"light","max_per_day":1,"quiet_start":"23:00","quiet_end":"08:00"}`
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
		if updated.DeliveryPace != "light" || updated.MaxPerDay != 1 || updated.QuietStart != "23:00" || updated.QuietEnd != "08:00" {
			t.Fatalf("unexpected push preference fields after update: %+v", updated)
		}
	})

	t.Run("push delivery writeback inserts event", func(t *testing.T) {
		body := `{"device_id":"iphone-1","intent_id":"intent-1","action":"opened","kind":"dailyQuestion","target_type":"question","target_id":"question-1","occurred_at":"2026-05-19T12:34:56Z"}`
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
		if event.Action != "opened" || event.TargetType != "question" || event.TargetID != "question-1" || event.IntentID != "intent-1" {
			t.Fatalf("unexpected delivery event: %+v", event)
		}
	})

	t.Run("v6 cloud intelligence contracts use mock provider", func(t *testing.T) {
		cases := []struct {
			name string
			path string
			body string
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
			{
				name: "suggest notification intent",
				path: "/api/intelligence/suggest-notification-intent",
				body: `{"schema_version":1,"locale":"zh-Hans","time_zone":"Asia/Shanghai","trigger":"dailyQuestion","question":{"kind":"dailyReflection","prompt":"What should Mory remember about today?","reason":"Daily cadence.","candidate_answers":[],"confidence":0.7,"sensitivity":"normal"},"preferences":{"max_per_day":2,"rich_previews_enabled":false}}`,
				assert: func(t *testing.T, body []byte) {
					var resp notificationIntentSuggestionResponseEnvelope
					if err := json.Unmarshal(body, &resp); err != nil {
						t.Fatalf("decode notification response: %v", err)
					}
					if resp.Intent.Title != "Mory" || resp.Intent.Body == "" {
						t.Fatalf("unexpected notification response: %+v", resp)
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
	})
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

	req := httptest.NewRequest(http.MethodPost, "/api/analysis/records", bytes.NewBufferString(`{
		"schema_version":"record_aggregate.v1",
		"analysis_reason":"manual",
		"record_shell":{"raw_text":"hi","capture_source":"composer"},
		"artifacts":[],
		"known_entities":[]
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
		"schema_version":"record_aggregate.v1",
		"client_version":"mory.v3",
		"analysis_reason":"capture_ingest",
		"record_shell":{"raw_text":"A local-first note about Linh.","capture_source":"composer"},
		"artifacts":[{"id":"a1","kind":"text","title":"Note","summary":"Local-first note","text_content":"A local-first note about Linh.","metadata":{"source":"composer"}}],
		"known_entities":[{"id":"p1","kind":"person","name":"Linh","aliases":["Linh Tran"]}]
	}`

	analyzeReq := httptest.NewRequest(http.MethodPost, "/api/analysis/records", bytes.NewBufferString(body))
	analyzeReq.Header.Set("Authorization", "Bearer "+token)
	analyzeReq.Header.Set("Content-Type", "application/json")
	analyzeRec := httptest.NewRecorder()
	server.Handler().ServeHTTP(analyzeRec, analyzeReq)
	if analyzeRec.Code != http.StatusOK {
		t.Fatalf("canonical analyze status = %d, body = %s", analyzeRec.Code, analyzeRec.Body.String())
	}

	previewReq := httptest.NewRequest(http.MethodPost, "/api/analysis/preview", bytes.NewBufferString(body))
	previewReq.Header.Set("Content-Type", "application/json")
	previewRec := httptest.NewRecorder()
	server.Handler().ServeHTTP(previewRec, previewReq)
	if previewRec.Code != http.StatusOK {
		t.Fatalf("canonical preview status = %d, body = %s", previewRec.Code, previewRec.Body.String())
	}

	legacyReq := httptest.NewRequest(http.MethodPost, "/api/records/analyze", bytes.NewBufferString(body))
	legacyReq.Header.Set("Authorization", "Bearer "+token)
	legacyReq.Header.Set("Content-Type", "application/json")
	legacyRec := httptest.NewRecorder()
	server.Handler().ServeHTTP(legacyRec, legacyReq)
	if legacyRec.Code != http.StatusNotFound {
		t.Fatalf("legacy analyze route should be removed, got %d", legacyRec.Code)
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

func fakeAppleJWT(t *testing.T, sub string) string {
	t.Helper()

	headerJSON := `{"alg":"ES256","kid":"test","typ":"JWT"}`
	claimsJSON := `{"iss":"https://appleid.apple.com","aud":"com.speculolabs.mory","exp":4102444800,"sub":"` + sub + `"}`

	return base64.RawURLEncoding.EncodeToString([]byte(headerJSON)) + "." +
		base64.RawURLEncoding.EncodeToString([]byte(claimsJSON)) + "." +
		base64.RawURLEncoding.EncodeToString([]byte("signature"))
}

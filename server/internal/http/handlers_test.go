package http

import (
	"bytes"
	"context"
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
	})

	token := issueDevToken(t, server, `{"identity_token":"tester-1"}`)

	t.Run("analyze", func(t *testing.T) {
		body := `{"record":{"content":"今天和妈妈看了一部电影，感觉很开心"},"persons":[{"id":"p1","name":"妈妈","relationship":"family"}]}`
		req := httptest.NewRequest(http.MethodPost, "/api/records/analyze", bytes.NewBufferString(body))
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

	t.Run("push register upsert", func(t *testing.T) {
		body := `{"device_id":"iphone-1","apns_token":"token-a","timezone":"Asia/Shanghai","has_question_ready":true}`
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
		if stored.APNSToken != "token-a" || !stored.HasQuestionReady {
			t.Fatalf("unexpected stored token after insert: %+v", stored)
		}

		updateBody := `{"device_id":"iphone-1","apns_token":"token-b","timezone":"America/Los_Angeles","has_question_ready":false}`
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
		if updated.APNSToken != "token-b" || updated.Timezone != "America/Los_Angeles" || updated.HasQuestionReady {
			t.Fatalf("unexpected stored token after update: %+v", updated)
		}
	})
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
	})

	req := httptest.NewRequest(http.MethodPost, "/api/records/analyze", bytes.NewBufferString(`{"record":{"content":"hi"}}`))
	req.Header.Set("Content-Type", "application/json")
	rec := httptest.NewRecorder()

	server.Handler().ServeHTTP(rec, req)
	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("expected 401, got %d", rec.Code)
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
	})

	req := httptest.NewRequest(http.MethodPost, "/auth/apple", bytes.NewBufferString(`{"identity_token":""}`))
	req.Header.Set("Content-Type", "application/json")
	rec := httptest.NewRecorder()

	server.Handler().ServeHTTP(rec, req)
	if rec.Code != http.StatusBadRequest {
		t.Fatalf("expected 400, got %d", rec.Code)
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

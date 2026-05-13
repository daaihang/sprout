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

	t.Run("auth response includes onboarding state", func(t *testing.T) {
		req := httptest.NewRequest(http.MethodPost, "/auth/refresh", nil)
		req.Header.Set("Authorization", "Bearer "+token)
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

	t.Run("analyze preview", func(t *testing.T) {
		body := `{"record":{"content":"今天和妈妈看了一部电影，感觉很开心"}}`
		req := httptest.NewRequest(http.MethodPost, "/api/onboarding/analyze-preview", bytes.NewBufferString(body))
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
		refreshReq.Header.Set("Authorization", "Bearer "+token)
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
		UserProfiles:  store,
	})

	req := httptest.NewRequest(http.MethodPost, "/api/records/analyze", bytes.NewBufferString(`{"record":{"content":"hi"}}`))
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

type failingAppleVerifier struct {
	err error
}

func (v failingAppleVerifier) VerifyIdentityToken(_ context.Context, _, _ string) (auth.AppleIdentity, error) {
	return auth.AppleIdentity{}, v.err
}

func fakeAppleJWT(t *testing.T, sub string) string {
	t.Helper()

	headerJSON := `{"alg":"ES256","kid":"test","typ":"JWT"}`
	claimsJSON := `{"iss":"https://appleid.apple.com","aud":"com.speculolabs.sprout","exp":4102444800,"sub":"` + sub + `"}`

	return base64.RawURLEncoding.EncodeToString([]byte(headerJSON)) + "." +
		base64.RawURLEncoding.EncodeToString([]byte(claimsJSON)) + "." +
		base64.RawURLEncoding.EncodeToString([]byte("signature"))
}

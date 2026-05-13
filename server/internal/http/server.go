package http

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"log/slog"
	"net/http"
	"strconv"
	"strings"
	"sync/atomic"
	"time"

	"sprout/server/internal/ai"
	"sprout/server/internal/auth"
	"sprout/server/internal/config"
	"sprout/server/internal/db"
	"sprout/server/internal/subscription"
)

type Dependencies struct {
	Config        config.Config
	Logger        *slog.Logger
	Authenticator *auth.Authenticator
	AppleVerifier auth.AppleIdentityVerifier
	AIProvider    ai.Provider
	Subscription  *subscription.Service
	PushTokens    db.PushTokenStore
	UserProfiles  db.UserProfileStore
}

type Server struct {
	cfg           config.Config
	logger        *slog.Logger
	authenticator *auth.Authenticator
	appleVerifier auth.AppleIdentityVerifier
	aiProvider    ai.Provider
	subscription  *subscription.Service
	pushTokens    db.PushTokenStore
	userProfiles  db.UserProfileStore
	metrics       *metrics
	mux           *http.ServeMux
}

func NewServer(deps Dependencies) *Server {
	s := &Server{
		cfg:           deps.Config,
		logger:        deps.Logger,
		authenticator: deps.Authenticator,
		appleVerifier: deps.AppleVerifier,
		aiProvider:    deps.AIProvider,
		subscription:  deps.Subscription,
		pushTokens:    deps.PushTokens,
		userProfiles:  deps.UserProfiles,
		metrics:       newMetrics(),
		mux:           http.NewServeMux(),
	}

	s.registerRoutes()
	return s
}

func (s *Server) Handler() http.Handler {
	return s.withRecovery(s.withRequestTimeout(s.withRequestID(s.withLogging(s.mux))))
}

func (s *Server) registerRoutes() {
	s.mux.HandleFunc("GET /healthz", s.handleHealthz)
	s.mux.HandleFunc("GET /metrics", s.handleMetrics)
	s.mux.HandleFunc("POST /auth/apple", s.handleAuthApple)
	s.mux.Handle("POST /auth/refresh", s.withAuth(http.HandlerFunc(s.handleAuthRefresh)))
	s.mux.HandleFunc("POST /api/analysis/preview", s.handleAnalyzePreview)
	s.mux.Handle("POST /api/analysis/records", s.withAuth(http.HandlerFunc(s.handleAnalyze)))
	s.mux.HandleFunc("POST /api/onboarding/analyze-preview", s.handleAnalyzePreview)
	s.mux.Handle("POST /api/records/analyze", s.withAuth(http.HandlerFunc(s.handleAnalyze)))
	s.mux.Handle("POST /api/me/onboarding/complete", s.withAuth(http.HandlerFunc(s.handleOnboardingComplete)))
	s.mux.Handle("GET /api/subscription/verify", s.withAuth(http.HandlerFunc(s.handleSubscriptionVerify)))
	s.mux.Handle("POST /api/push/register", s.withAuth(http.HandlerFunc(s.handlePushRegister)))
}

func (s *Server) withAuth(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		authorization := strings.TrimSpace(r.Header.Get("Authorization"))
		if !strings.HasPrefix(authorization, "Bearer ") {
			writeError(w, http.StatusUnauthorized, "missing bearer token")
			return
		}

		token := strings.TrimSpace(strings.TrimPrefix(authorization, "Bearer "))
		claims, err := s.authenticator.ValidateToken(token)
		if err != nil {
			if errors.Is(err, auth.ErrExpiredToken) {
				writeError(w, http.StatusUnauthorized, "token expired")
				return
			}
			writeError(w, http.StatusUnauthorized, "invalid token")
			return
		}

		next.ServeHTTP(w, r.WithContext(auth.ContextWithClaims(r.Context(), claims)))
	})
}

func (s *Server) withLogging(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		recorder := &statusRecorder{ResponseWriter: w, status: http.StatusOK}
		next.ServeHTTP(recorder, r)

		duration := time.Since(start)
		requestID := requestIDFromContext(r.Context())
		s.metrics.Record(recorder.status, duration)

		s.logger.Info(
			"request",
			"request_id", requestID,
			"method", r.Method,
			"path", r.URL.Path,
			"status", recorder.status,
			"duration_ms", duration.Milliseconds(),
		)
	})
}

func (s *Server) withRequestID(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		requestID := strings.TrimSpace(r.Header.Get("X-Request-ID"))
		if requestID == "" {
			requestID = nextRequestID()
		}
		w.Header().Set("X-Request-ID", requestID)
		next.ServeHTTP(w, r.WithContext(contextWithRequestID(r.Context(), requestID)))
	})
}

func (s *Server) withRequestTimeout(next http.Handler) http.Handler {
	if s.cfg.RequestTimeout <= 0 {
		return next
	}
	return http.TimeoutHandler(next, s.cfg.RequestTimeout, `{"error":"request timed out"}`)
}

func (s *Server) withRecovery(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		defer func() {
			if recovered := recover(); recovered != nil {
				s.logger.Error("panic recovered", "panic", recovered, "path", r.URL.Path)
				writeError(w, http.StatusInternalServerError, "internal server error")
			}
		}()
		next.ServeHTTP(w, r)
	})
}

type statusRecorder struct {
	http.ResponseWriter
	status int
}

func (r *statusRecorder) WriteHeader(status int) {
	r.status = status
	r.ResponseWriter.WriteHeader(status)
}

type errorResponse struct {
	Error string `json:"error"`
}

type metrics struct {
	requestsTotal  atomic.Uint64
	requests4xx    atomic.Uint64
	requests5xx    atomic.Uint64
	latencyTotalMS atomic.Int64
}

func newMetrics() *metrics {
	return &metrics{}
}

func (m *metrics) Record(status int, duration time.Duration) {
	m.requestsTotal.Add(1)
	m.latencyTotalMS.Add(duration.Milliseconds())
	if status >= 400 && status < 500 {
		m.requests4xx.Add(1)
	}
	if status >= 500 {
		m.requests5xx.Add(1)
	}
}

func (m *metrics) Snapshot() map[string]any {
	total := m.requestsTotal.Load()
	avgLatency := int64(0)
	if total > 0 {
		avgLatency = m.latencyTotalMS.Load() / int64(total)
	}
	return map[string]any{
		"requests_total":     total,
		"requests_4xx_total": m.requests4xx.Load(),
		"requests_5xx_total": m.requests5xx.Load(),
		"average_latency_ms": avgLatency,
	}
}

type requestIDContextKey string

const requestIDKey requestIDContextKey = "request_id"

var requestCounter atomic.Uint64

func nextRequestID() string {
	return "req_" + strconv.FormatUint(requestCounter.Add(1), 10)
}

func contextWithRequestID(ctx context.Context, requestID string) context.Context {
	return context.WithValue(ctx, requestIDKey, requestID)
}

func requestIDFromContext(ctx context.Context) string {
	value, _ := ctx.Value(requestIDKey).(string)
	return value
}

func writeJSON(w http.ResponseWriter, status int, value any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(value)
}

func writeError(w http.ResponseWriter, status int, message string) {
	writeJSON(w, status, errorResponse{Error: message})
}

func writeText(w http.ResponseWriter, status int, body string) {
	w.Header().Set("Content-Type", "text/plain; charset=utf-8")
	w.WriteHeader(status)
	_, _ = w.Write([]byte(body))
}

func metricsText(snapshot map[string]any) string {
	return fmt.Sprintf(
		"requests_total %v\nrequests_4xx_total %v\nrequests_5xx_total %v\naverage_latency_ms %v\n",
		snapshot["requests_total"],
		snapshot["requests_4xx_total"],
		snapshot["requests_5xx_total"],
		snapshot["average_latency_ms"],
	)
}

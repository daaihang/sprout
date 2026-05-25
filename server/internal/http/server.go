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
	"sync"
	"sync/atomic"
	"time"

	"sprout/server/internal/ai"
	"sprout/server/internal/auth"
	"sprout/server/internal/config"
	"sprout/server/internal/db"
	"sprout/server/internal/notification"
	"sprout/server/internal/subscription"
)

type Dependencies struct {
	Config             config.Config
	Logger             *slog.Logger
	Authenticator      *auth.Authenticator
	AppleVerifier      auth.AppleIdentityVerifier
	AIProvider         ai.Provider
	Subscription       *subscription.Service
	PushTokens         db.PushTokenStore
	UserProfiles       db.UserProfileStore
	PushDeliveryWorker *notification.PushDeliveryWorker
}

type Server struct {
	cfg                config.Config
	logger             *slog.Logger
	authenticator      *auth.Authenticator
	appleVerifier      auth.AppleIdentityVerifier
	aiProvider         ai.Provider
	subscription       *subscription.Service
	pushTokens         db.PushTokenStore
	userProfiles       db.UserProfileStore
	pushDeliveryWorker *notification.PushDeliveryWorker
	metrics            *metrics
	aiRateLimiter      *aiRateLimiter
	mux                *http.ServeMux
}

func NewServer(deps Dependencies) *Server {
	pushDeliveryWorker := deps.PushDeliveryWorker
	if pushDeliveryWorker == nil && deps.PushTokens != nil {
		pushDeliveryWorker = notification.NewPushDeliveryWorker(
			deps.PushTokens,
			notification.DisabledAPNSClient{},
			deps.Logger,
			firstNonEmpty(firstString(deps.Config.AppleAudiences), "com.speculolabs.mory"),
		)
	}

	s := &Server{
		cfg:                deps.Config,
		logger:             deps.Logger,
		authenticator:      deps.Authenticator,
		appleVerifier:      deps.AppleVerifier,
		aiProvider:         deps.AIProvider,
		subscription:       deps.Subscription,
		pushTokens:         deps.PushTokens,
		userProfiles:       deps.UserProfiles,
		pushDeliveryWorker: pushDeliveryWorker,
		metrics:            newMetrics(),
		aiRateLimiter:      newAIRateLimiter(deps.Config.AIRateLimitPerMinute),
		mux:                http.NewServeMux(),
	}

	s.registerRoutes()
	return s
}

func firstString(values []string) string {
	if len(values) == 0 {
		return ""
	}
	return strings.TrimSpace(values[0])
}

func firstNonEmpty(values ...string) string {
	for _, value := range values {
		if trimmed := strings.TrimSpace(value); trimmed != "" {
			return trimmed
		}
	}
	return ""
}

func (s *Server) Handler() http.Handler {
	return s.withRecovery(s.withRequestTimeout(s.withRequestID(s.withLogging(s.mux))))
}

func (s *Server) registerRoutes() {
	s.mux.HandleFunc("GET /healthz", s.handleHealthz)
	s.mux.HandleFunc("GET /metrics", s.handleMetrics)
	s.mux.HandleFunc("POST /auth/apple", s.handleAuthApple)
	s.mux.HandleFunc("POST /auth/refresh", s.handleAuthRefresh)
	s.mux.HandleFunc("POST /api/auth/refresh", s.handleAuthRefresh)
	s.mux.HandleFunc("POST /api/analysis/preview", s.handleAnalyzePreview)
	s.mux.Handle("POST /api/analysis/records", s.withAuth(http.HandlerFunc(s.handleAnalyze)))
	s.mux.Handle("POST /api/analyze/v7", s.withAuth(http.HandlerFunc(s.handleAnalyzeV7)))
	s.mux.Handle("POST /api/reflections/generate", s.withAuth(http.HandlerFunc(s.handleReflectionGenerate)))
	s.mux.Handle("POST /api/reflections/replay", s.withAuth(http.HandlerFunc(s.handleReflectionReplay)))
	s.mux.Handle("POST /api/intelligence/refine-transcript", s.withAuth(http.HandlerFunc(s.handleTranscriptRefinement)))
	s.mux.Handle("POST /api/intelligence/suggest-questions", s.withAuth(http.HandlerFunc(s.handleQuestionSuggestions)))
	s.mux.Handle("POST /api/intelligence/suggest-chapters", s.withAuth(http.HandlerFunc(s.handleChapterSuggestions)))
	s.mux.Handle("POST /api/intelligence/analyze-photo", s.withAuth(http.HandlerFunc(s.handlePhotoSemanticAnalysis)))
	s.mux.Handle("POST /api/intelligence/eval", s.withAuth(http.HandlerFunc(s.handleCloudIntelligenceEval)))
	s.mux.Handle("POST /api/me/onboarding/complete", s.withAuth(http.HandlerFunc(s.handleOnboardingComplete)))
	s.mux.Handle("GET /api/subscription/verify", s.withAuth(http.HandlerFunc(s.handleSubscriptionVerify)))
	s.mux.Handle("POST /api/push/register", s.withAuth(http.HandlerFunc(s.handlePushRegister)))
	s.mux.Handle("POST /api/push/enqueue", s.withAuth(http.HandlerFunc(s.handlePushEnqueue)))
	s.mux.Handle("POST /api/push/delivery-writeback", s.withAuth(http.HandlerFunc(s.handlePushDeliveryWriteback)))
}

func (s *Server) recordAI(operation string, provider string, usage ai.Usage, duration time.Duration, err error) {
	if s == nil || s.metrics == nil {
		return
	}
	s.metrics.RecordAI(operation, provider, usage, duration, err)
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
	Error     string `json:"error"`
	Code      string `json:"code,omitempty"`
	Class     string `json:"class,omitempty"`
	Retryable bool   `json:"retryable,omitempty"`
	RequestID string `json:"request_id,omitempty"`
}

type metrics struct {
	requestsTotal  atomic.Uint64
	requests4xx    atomic.Uint64
	requests5xx    atomic.Uint64
	latencyTotalMS atomic.Int64
	mu             sync.Mutex
	aiOperations   map[string]*aiOperationMetrics
}

type aiOperationMetrics struct {
	requestsTotal  uint64
	errorsTotal    uint64
	latencyTotalMS int64
	inputTokens    uint64
	outputTokens   uint64
	errorClasses   map[string]uint64
}

type aiOperationSnapshot struct {
	Operation        string
	Provider         string
	RequestsTotal    uint64
	ErrorsTotal      uint64
	AverageLatencyMS int64
	InputTokens      uint64
	OutputTokens     uint64
	ErrorClasses     map[string]uint64
}

func newMetrics() *metrics {
	return &metrics{
		aiOperations: map[string]*aiOperationMetrics{},
	}
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

func (m *metrics) RecordAI(operation string, provider string, usage ai.Usage, duration time.Duration, err error) {
	operation = strings.TrimSpace(operation)
	if operation == "" {
		operation = "unknown"
	}
	provider = strings.TrimSpace(provider)
	if provider == "" {
		provider = "unknown"
	}
	key := operation + "\x00" + provider

	m.mu.Lock()
	defer m.mu.Unlock()
	bucket := m.aiOperations[key]
	if bucket == nil {
		bucket = &aiOperationMetrics{}
		m.aiOperations[key] = bucket
	}
	bucket.requestsTotal++
	bucket.latencyTotalMS += duration.Milliseconds()
	bucket.inputTokens += uint64(maxInt(usage.InputTokens, 0))
	bucket.outputTokens += uint64(maxInt(usage.OutputTokens, 0))
	if err != nil {
		bucket.errorsTotal++
		if bucket.errorClasses == nil {
			bucket.errorClasses = map[string]uint64{}
		}
		class, _ := classifyAIError(err)
		if class == "" {
			class = aiErrorClassUnknown
		}
		bucket.errorClasses[string(class)]++
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
		"ai_operations":      m.aiSnapshot(),
	}
}

func (m *metrics) aiSnapshot() []aiOperationSnapshot {
	m.mu.Lock()
	defer m.mu.Unlock()
	snapshots := make([]aiOperationSnapshot, 0, len(m.aiOperations))
	for key, bucket := range m.aiOperations {
		parts := strings.SplitN(key, "\x00", 2)
		operation := parts[0]
		provider := "unknown"
		if len(parts) > 1 {
			provider = parts[1]
		}
		averageLatency := int64(0)
		if bucket.requestsTotal > 0 {
			averageLatency = bucket.latencyTotalMS / int64(bucket.requestsTotal)
		}
		snapshots = append(snapshots, aiOperationSnapshot{
			Operation:        operation,
			Provider:         provider,
			RequestsTotal:    bucket.requestsTotal,
			ErrorsTotal:      bucket.errorsTotal,
			AverageLatencyMS: averageLatency,
			InputTokens:      bucket.inputTokens,
			OutputTokens:     bucket.outputTokens,
			ErrorClasses:     copyStringUint64Map(bucket.errorClasses),
		})
	}
	return snapshots
}

func copyStringUint64Map(source map[string]uint64) map[string]uint64 {
	if len(source) == 0 {
		return nil
	}
	copied := make(map[string]uint64, len(source))
	for key, value := range source {
		copied[key] = value
	}
	return copied
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

func writeClassifiedError(w http.ResponseWriter, status int, message string, class aiErrorClass, retryable bool, requestID string) {
	writeJSON(w, status, errorResponse{
		Error:     message,
		Code:      string(class),
		Class:     string(class),
		Retryable: retryable,
		RequestID: requestID,
	})
}

func writeText(w http.ResponseWriter, status int, body string) {
	w.Header().Set("Content-Type", "text/plain; charset=utf-8")
	w.WriteHeader(status)
	_, _ = w.Write([]byte(body))
}

func metricsText(cfg config.Config, snapshot map[string]any, worker notification.DeliveryWorkerMetricsSnapshot) string {
	var builder strings.Builder
	builder.WriteString(fmt.Sprintf(
		"requests_total %v\nrequests_4xx_total %v\nrequests_5xx_total %v\naverage_latency_ms %v\n",
		snapshot["requests_total"],
		snapshot["requests_4xx_total"],
		snapshot["requests_5xx_total"],
		snapshot["average_latency_ms"],
	))
	if aiSnapshots, ok := snapshot["ai_operations"].([]aiOperationSnapshot); ok {
		for _, item := range aiSnapshots {
			labels := fmt.Sprintf(`operation="%s",provider="%s"`, metricLabel(item.Operation), metricLabel(item.Provider))
			builder.WriteString(fmt.Sprintf("ai_operation_requests_total{%s} %d\n", labels, item.RequestsTotal))
			builder.WriteString(fmt.Sprintf("ai_operation_errors_total{%s} %d\n", labels, item.ErrorsTotal))
			builder.WriteString(fmt.Sprintf("ai_operation_average_latency_ms{%s} %d\n", labels, item.AverageLatencyMS))
			builder.WriteString(fmt.Sprintf("ai_operation_input_tokens_total{%s} %d\n", labels, item.InputTokens))
			builder.WriteString(fmt.Sprintf("ai_operation_output_tokens_total{%s} %d\n", labels, item.OutputTokens))
			for class, count := range item.ErrorClasses {
				errorLabels := fmt.Sprintf(`operation="%s",provider="%s",class="%s"`, metricLabel(item.Operation), metricLabel(item.Provider), metricLabel(class))
				builder.WriteString(fmt.Sprintf("ai_operation_errors_by_class_total{%s} %d\n", errorLabels, count))
			}
		}
	}
	builder.WriteString(fmt.Sprintf("cloud_intelligence_prompt_version_info{version=\"%s\"} 1\n", metricLabel(ai.V6PromptVersion)))
	builder.WriteString(fmt.Sprintf("cloud_intelligence_rate_limit_per_minute %d\n", cfg.AIRateLimitPerMinute))
	builder.WriteString(fmt.Sprintf(
		"apns_environment_info{environment=\"%s\",topic=\"%s\",enabled=\"%t\"} 1\n",
		metricLabel(cfg.APNSEnvironment),
		metricLabel(cfg.APNSTopic),
		cfg.APNSEnabled,
	))
	builder.WriteString(fmt.Sprintf("push_delivery_worker_enabled_info{enabled=\"%t\"} 1\n", cfg.PushDeliveryWorkerEnabled))
	builder.WriteString(fmt.Sprintf("push_delivery_enqueued_total %d\n", worker.Enqueued))
	builder.WriteString(fmt.Sprintf("push_delivery_skipped_total %d\n", worker.Skipped))
	builder.WriteString(fmt.Sprintf("push_delivery_batches_total %d\n", worker.Batches))
	builder.WriteString(fmt.Sprintf("push_delivery_due_fetched_total %d\n", worker.DueFetched))
	builder.WriteString(fmt.Sprintf("push_delivery_sent_total %d\n", worker.Sent))
	builder.WriteString(fmt.Sprintf("push_delivery_failed_total %d\n", worker.Failed))
	builder.WriteString(fmt.Sprintf("push_delivery_retried_total %d\n", worker.Retried))
	builder.WriteString(fmt.Sprintf("push_delivery_permanent_failed_total %d\n", worker.PermanentFailed))
	builder.WriteString(fmt.Sprintf("push_delivery_loop_errors_total %d\n", worker.LoopErrors))
	builder.WriteString(fmt.Sprintf("push_delivery_consecutive_loop_errors %d\n", worker.ConsecutiveLoopErrors))
	builder.WriteString(fmt.Sprintf("push_delivery_last_run_unix %d\n", worker.LastRunUnix))
	builder.WriteString(fmt.Sprintf("push_delivery_last_success_unix %d\n", worker.LastSuccessUnix))
	if strings.TrimSpace(worker.LastError) != "" {
		builder.WriteString(fmt.Sprintf("push_delivery_last_error_info{message=\"%s\"} 1\n", metricLabel(worker.LastError)))
	}
	return builder.String()
}

func metricLabel(value string) string {
	return strings.NewReplacer("\\", "\\\\", "\"", "\\\"").Replace(value)
}

func maxInt(a, b int) int {
	if a > b {
		return a
	}
	return b
}

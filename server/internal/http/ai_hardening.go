package http

import (
	"context"
	"errors"
	"fmt"
	"net/http"
	"strings"
	"sync"
	"time"

	"sprout/server/internal/ai"
)

type aiErrorClass string

const (
	aiErrorClassInvalid       aiErrorClass = "invalid_request"
	aiErrorClassRateLimit     aiErrorClass = "rate_limit"
	aiErrorClassTimeout       aiErrorClass = "timeout"
	aiErrorClassProviderAuth  aiErrorClass = "provider_auth"
	aiErrorClassProviderQuota aiErrorClass = "provider_quota"
	aiErrorClassProvider5xx   aiErrorClass = "provider_5xx"
	aiErrorClassProvider4xx   aiErrorClass = "provider_4xx"
	aiErrorClassParsing       aiErrorClass = "provider_parse"
	aiErrorClassNetwork       aiErrorClass = "network"
	aiErrorClassUnknown       aiErrorClass = "unknown"
)

type aiRateLimiter struct {
	limitPerMinute int
	mu             sync.Mutex
	windows        map[string]aiRateWindow
}

type aiRateWindow struct {
	start time.Time
	count int
}

func newAIRateLimiter(limitPerMinute int) *aiRateLimiter {
	return &aiRateLimiter{
		limitPerMinute: limitPerMinute,
		windows:        map[string]aiRateWindow{},
	}
}

func (l *aiRateLimiter) allow(userID string, operation string, now time.Time) (bool, time.Duration) {
	if l == nil || l.limitPerMinute <= 0 {
		return true, 0
	}
	key := strings.TrimSpace(userID) + "\x00" + strings.TrimSpace(operation)
	if key == "\x00" {
		key = "anonymous\x00unknown"
	}
	windowStart := now.UTC().Truncate(time.Minute)

	l.mu.Lock()
	defer l.mu.Unlock()

	window := l.windows[key]
	if window.start.IsZero() || !window.start.Equal(windowStart) {
		l.windows[key] = aiRateWindow{start: windowStart, count: 1}
		l.pruneLocked(windowStart.Add(-2 * time.Minute))
		return true, 0
	}
	if window.count >= l.limitPerMinute {
		return false, windowStart.Add(time.Minute).Sub(now.UTC())
	}
	window.count++
	l.windows[key] = window
	return true, 0
}

func (l *aiRateLimiter) pruneLocked(cutoff time.Time) {
	for key, window := range l.windows {
		if window.start.Before(cutoff) {
			delete(l.windows, key)
		}
	}
}

func classifyAIError(err error) (aiErrorClass, bool) {
	if err == nil {
		return "", false
	}
	if errors.Is(err, ai.ErrInvalidAnalyzeRequest) {
		return aiErrorClassInvalid, false
	}
	if errors.Is(err, context.Canceled) || errors.Is(err, context.DeadlineExceeded) {
		return aiErrorClassTimeout, true
	}

	lower := strings.ToLower(err.Error())
	switch {
	case strings.Contains(lower, "status 401") || strings.Contains(lower, "status 403") || strings.Contains(lower, "unauthorized"):
		return aiErrorClassProviderAuth, false
	case strings.Contains(lower, "status 429") || strings.Contains(lower, "rate limit") || strings.Contains(lower, "quota"):
		return aiErrorClassProviderQuota, true
	case strings.Contains(lower, "status 5") || strings.Contains(lower, "bad gateway") || strings.Contains(lower, "overloaded"):
		return aiErrorClassProvider5xx, true
	case strings.Contains(lower, "status 4"):
		return aiErrorClassProvider4xx, false
	case strings.Contains(lower, "parse") || strings.Contains(lower, "json") || strings.Contains(lower, "decode"):
		return aiErrorClassParsing, true
	case strings.Contains(lower, "timeout"):
		return aiErrorClassTimeout, true
	case strings.Contains(lower, "network") || strings.Contains(lower, "connection") || strings.Contains(lower, "tls"):
		return aiErrorClassNetwork, true
	default:
		return aiErrorClassUnknown, true
	}
}

func statusForAIError(class aiErrorClass) int {
	switch class {
	case aiErrorClassInvalid:
		return http.StatusBadRequest
	case aiErrorClassRateLimit:
		return http.StatusTooManyRequests
	case aiErrorClassTimeout:
		return http.StatusGatewayTimeout
	case aiErrorClassProviderAuth, aiErrorClassProvider4xx:
		return http.StatusBadGateway
	default:
		return http.StatusBadGateway
	}
}

func (s *Server) allowAIRequest(w http.ResponseWriter, r *http.Request, userID string, operation string) bool {
	if s == nil || s.aiRateLimiter == nil {
		return true
	}
	allowed, retryAfter := s.aiRateLimiter.allow(userID, operation, time.Now())
	if allowed {
		return true
	}
	if retryAfter < time.Second {
		retryAfter = time.Second
	}
	w.Header().Set("Retry-After", fmt.Sprintf("%.0f", retryAfter.Seconds()))
	writeClassifiedError(
		w,
		http.StatusTooManyRequests,
		"cloud intelligence rate limit exceeded",
		aiErrorClassRateLimit,
		true,
		requestIDFromContext(r.Context()),
	)
	return false
}

func writeAIProviderError(w http.ResponseWriter, r *http.Request, prefix string, err error) {
	class, retryable := classifyAIError(err)
	if class == "" {
		class = aiErrorClassUnknown
	}
	message := strings.TrimSpace(prefix)
	if message == "" {
		message = "cloud intelligence request failed"
	}
	if err != nil && class != aiErrorClassInvalid {
		message = message + ": " + err.Error()
	}
	writeClassifiedError(
		w,
		statusForAIError(class),
		message,
		class,
		retryable,
		requestIDFromContext(r.Context()),
	)
}

package ai

import (
	"context"
	"fmt"
	"log/slog"
	"net/http"
	"time"
)

func doRequestWithRetry(ctx context.Context, client *http.Client, req *http.Request, maxRetries int, backoff time.Duration) (*http.Response, error) {
	logger := slog.Default()
	var lastErr error
	for attempt := 0; attempt <= maxRetries; attempt++ {
		if attempt > 0 {
			wait := backoff * time.Duration(attempt)
			logger.Warn("🔄 retrying AI request",
				"attempt", attempt+1,
				"max_retries", maxRetries+1,
				"wait_ms", wait.Milliseconds(),
				"last_error", lastErr,
				"url", req.URL.String(),
			)
		}

		cloned := req.Clone(ctx)
		start := time.Now()
		resp, err := client.Do(cloned)
		elapsed := time.Since(start)

		if err == nil && resp.StatusCode < 500 && resp.StatusCode != http.StatusTooManyRequests {
			if attempt > 0 {
				logger.Info("✅ retry succeeded",
					"attempt", attempt+1,
					"status", resp.StatusCode,
					"duration_ms", elapsed.Milliseconds(),
				)
			}
			return resp, nil
		}

		if resp != nil && err == nil {
			lastErr = fmt.Errorf("status %d", resp.StatusCode)
			logger.Warn("⚠️ AI request got retryable status",
				"attempt", attempt+1,
				"status", resp.StatusCode,
				"duration_ms", elapsed.Milliseconds(),
				"url", req.URL.String(),
			)
			resp.Body.Close()
		} else {
			lastErr = err
			logger.Warn("⚠️ AI request error",
				"attempt", attempt+1,
				"duration_ms", elapsed.Milliseconds(),
				"error", err,
				"url", req.URL.String(),
			)
		}
		if attempt == maxRetries {
			break
		}
		select {
		case <-ctx.Done():
			logger.Error("❌ AI request context cancelled during retry",
				"attempt", attempt+1,
				"context_error", ctx.Err(),
			)
			return nil, ctx.Err()
		case <-time.After(backoff * time.Duration(attempt+1)):
		}
	}
	logger.Error("❌ AI request all retries exhausted",
		"total_attempts", maxRetries+1,
		"last_error", lastErr,
		"url", req.URL.String(),
	)
	return nil, lastErr
}

package ai

import (
	"context"
	"fmt"
	"net/http"
	"time"
)

func doRequestWithRetry(ctx context.Context, client *http.Client, req *http.Request, maxRetries int, backoff time.Duration) (*http.Response, error) {
	var lastErr error
	for attempt := 0; attempt <= maxRetries; attempt++ {
		cloned := req.Clone(ctx)
		resp, err := client.Do(cloned)
		if err == nil && resp.StatusCode < 500 && resp.StatusCode != http.StatusTooManyRequests {
			return resp, nil
		}
		if resp != nil && err == nil {
			lastErr = fmt.Errorf("status %d", resp.StatusCode)
			resp.Body.Close()
		} else {
			lastErr = err
		}
		if attempt == maxRetries {
			break
		}
		select {
		case <-ctx.Done():
			return nil, ctx.Err()
		case <-time.After(backoff * time.Duration(attempt+1)):
		}
	}
	return nil, lastErr
}

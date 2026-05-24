package ai

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"time"
)

func (p *AnthropicProvider) AnalyzeV7(ctx context.Context, req AnalyzeV7Request, user UserContext) (AnalyzeV7Result, error) {
	if err := req.Validate(); err != nil {
		return AnalyzeV7Result{}, err
	}

	userPrompt, err := buildAnalyzeV7UserPrompt(req, user)
	if err != nil {
		return AnalyzeV7Result{}, err
	}

	systemPrompt := buildAnalyzeV7SystemPrompt()
	payload := anthropicRequest{
		Model:     p.model,
		MaxTokens: 1600,
		System:    systemPrompt,
		Messages: []anthropicMessage{{
			Role: "user",
			Content: []anthropicContentRequest{{
				Type: "text",
				Text: userPrompt,
			}},
		}},
	}

	body, err := json.Marshal(payload)
	if err != nil {
		return AnalyzeV7Result{}, fmt.Errorf("marshal anthropic analyze v7 request: %w", err)
	}

	p.logger.Info("📤 anthropic analyze v7 request",
		"provider", p.Name(),
		"model", p.model,
		"endpoint", p.baseURL,
		"user_id", user.UserID,
		"system_prompt_len", len(systemPrompt),
		"user_prompt_len", len(userPrompt),
		"request_body_len", len(body),
		"record_id", req.RecordShell.ID,
		"artifact_count", len(req.Artifacts),
		"related_memory_count", len(req.ContextPack.RelatedMemories),
	)

	httpReq, err := http.NewRequestWithContext(ctx, http.MethodPost, p.baseURL, bytes.NewReader(body))
	if err != nil {
		return AnalyzeV7Result{}, fmt.Errorf("create anthropic analyze v7 request: %w", err)
	}
	httpReq.Header.Set("Content-Type", "application/json")
	httpReq.Header.Set("x-api-key", p.apiKey)
	httpReq.Header.Set("anthropic-version", p.version)
	if p.heliconeKey != "" {
		httpReq.Header.Set("Helicone-Auth", "Bearer "+p.heliconeKey)
		if user.UserID != "" {
			httpReq.Header.Set("Helicone-User-Id", user.UserID)
		}
	}

	start := time.Now()
	resp, err := doRequestWithRetry(ctx, p.client, httpReq, p.maxRetries, p.backoff)
	elapsed := time.Since(start)
	if err != nil {
		p.logger.Error("❌ anthropic analyze v7 request failed",
			"provider", p.Name(),
			"duration_ms", elapsed.Milliseconds(),
			"error", err,
		)
		return AnalyzeV7Result{}, fmt.Errorf("anthropic analyze v7 request failed: %w", err)
	}
	defer resp.Body.Close()

	responseBody, err := io.ReadAll(io.LimitReader(resp.Body, 2<<20))
	if err != nil {
		return AnalyzeV7Result{}, fmt.Errorf("read anthropic analyze v7 response: %w", err)
	}

	p.logger.Info("📥 anthropic analyze v7 response",
		"provider", p.Name(),
		"status", resp.StatusCode,
		"duration_ms", elapsed.Milliseconds(),
		"response_body_len", len(responseBody),
	)

	if resp.StatusCode >= 300 {
		p.logger.Error("❌ anthropic analyze v7 response failed",
			"status", resp.StatusCode,
			"provider", p.Name(),
			"duration_ms", elapsed.Milliseconds(),
			"body", truncateBody(responseBody, 2048),
		)
		return AnalyzeV7Result{}, fmt.Errorf("anthropic analyze v7 status %d", resp.StatusCode)
	}

	var decoded anthropicResponse
	if err := json.Unmarshal(responseBody, &decoded); err != nil {
		p.logger.Error("❌ anthropic analyze v7 decode failed",
			"provider", p.Name(),
			"duration_ms", elapsed.Milliseconds(),
			"body", truncateBody(responseBody, 2048),
			"error", err,
		)
		return AnalyzeV7Result{}, fmt.Errorf("decode anthropic analyze v7 response: %w", err)
	}

	text := joinAnthropicText(decoded.Content)
	analyzeResp, err := parseAnalyzeV7Response(text)
	if err != nil {
		p.logger.Error("❌ anthropic analyze v7 parse failed",
			"provider", p.Name(),
			"duration_ms", elapsed.Milliseconds(),
			"raw_text", truncateBody([]byte(text), 1024),
			"error", err,
		)
		return AnalyzeV7Result{}, err
	}

	return AnalyzeV7Result{
		Response: analyzeResp,
		Provider: p.Name(),
		Model:    decoded.Model,
		Usage: Usage{
			InputTokens:  decoded.Usage.InputTokens,
			OutputTokens: decoded.Usage.OutputTokens,
		},
	}, nil
}

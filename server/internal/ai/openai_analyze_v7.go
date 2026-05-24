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

func (p *OpenAICompatibleProvider) AnalyzeV7(ctx context.Context, req AnalyzeV7Request, user UserContext) (AnalyzeV7Result, error) {
	if err := req.Validate(); err != nil {
		return AnalyzeV7Result{}, err
	}

	userPrompt, err := buildAnalyzeV7UserPrompt(req, user)
	if err != nil {
		return AnalyzeV7Result{}, err
	}

	systemPrompt := buildAnalyzeV7SystemPrompt()
	payload := openAIChatRequest{
		Model:          p.model,
		ResponseFormat: map[string]string{"type": "json_object"},
		Temperature:    0.2,
		Messages: []openAIMessage{
			{Role: "system", Content: systemPrompt},
			{Role: "user", Content: userPrompt},
		},
		Thinking: p.thinkingConfig(),
	}

	body, err := json.Marshal(payload)
	if err != nil {
		return AnalyzeV7Result{}, fmt.Errorf("marshal openai analyze v7 request: %w", err)
	}

	p.logger.Info("📤 openai analyze v7 request",
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
		return AnalyzeV7Result{}, fmt.Errorf("create openai analyze v7 request: %w", err)
	}
	httpReq.Header.Set("Content-Type", "application/json")
	httpReq.Header.Set("Authorization", "Bearer "+p.apiKey)

	start := time.Now()
	resp, err := doRequestWithRetry(ctx, p.client, httpReq, p.maxRetries, p.backoff)
	elapsed := time.Since(start)
	if err != nil {
		p.logger.Error("❌ openai analyze v7 request failed",
			"provider", p.Name(),
			"duration_ms", elapsed.Milliseconds(),
			"error", err,
		)
		return AnalyzeV7Result{}, fmt.Errorf("openai-compatible analyze v7 request failed: %w", err)
	}
	defer resp.Body.Close()

	responseBody, err := io.ReadAll(io.LimitReader(resp.Body, 2<<20))
	if err != nil {
		return AnalyzeV7Result{}, fmt.Errorf("read openai analyze v7 response: %w", err)
	}

	p.logger.Info("📥 openai analyze v7 response",
		"provider", p.Name(),
		"status", resp.StatusCode,
		"duration_ms", elapsed.Milliseconds(),
		"response_body_len", len(responseBody),
	)

	if resp.StatusCode >= 300 {
		p.logger.Error("❌ openai analyze v7 response failed",
			"status", resp.StatusCode,
			"provider", p.Name(),
			"duration_ms", elapsed.Milliseconds(),
			"body", truncateBody(responseBody, 2048),
		)
		return AnalyzeV7Result{}, fmt.Errorf("openai-compatible analyze v7 status %d: %s", resp.StatusCode, truncateBody(responseBody, 256))
	}

	var decoded openAIChatResponse
	if err := json.Unmarshal(responseBody, &decoded); err != nil {
		p.logger.Error("❌ openai analyze v7 decode failed",
			"provider", p.Name(),
			"status", resp.StatusCode,
			"duration_ms", elapsed.Milliseconds(),
			"body", truncateBody(responseBody, 2048),
			"error", err,
		)
		return AnalyzeV7Result{}, fmt.Errorf("decode openai analyze v7 response: %w", err)
	}
	if len(decoded.Choices) == 0 {
		return AnalyzeV7Result{}, fmt.Errorf("openai-compatible analyze v7 response contained no choices")
	}

	text := flattenOpenAIContent(decoded.Choices[0].Message.Content)
	analyzeResp, err := parseAnalyzeV7Response(text)
	if err != nil {
		p.logger.Error("❌ openai analyze v7 parse failed",
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
			InputTokens:  decoded.Usage.PromptTokens,
			OutputTokens: decoded.Usage.CompletionTokens,
		},
	}, nil
}

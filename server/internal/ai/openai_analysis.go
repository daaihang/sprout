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

func (p *OpenAICompatibleProvider) Analyze(ctx context.Context, req AnalysisRequest, user UserContext) (AnalysisResult, error) {
	if err := req.Validate(); err != nil {
		return AnalysisResult{}, err
	}

	userPrompt, err := buildAnalysisUserPrompt(req, user)
	if err != nil {
		return AnalysisResult{}, err
	}

	systemPrompt := buildAnalysisSystemPrompt()
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
		return AnalysisResult{}, fmt.Errorf("marshal openai analysis request: %w", err)
	}

	p.logger.Info("📤 openai analysis request",
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
		return AnalysisResult{}, fmt.Errorf("create openai analysis request: %w", err)
	}
	httpReq.Header.Set("Content-Type", "application/json")
	httpReq.Header.Set("Authorization", "Bearer "+p.apiKey)

	start := time.Now()
	resp, err := doRequestWithRetry(ctx, p.client, httpReq, p.maxRetries, p.backoff)
	elapsed := time.Since(start)
	if err != nil {
		p.logger.Error("❌ openai analysis request failed",
			"provider", p.Name(),
			"duration_ms", elapsed.Milliseconds(),
			"error", err,
		)
		return AnalysisResult{}, fmt.Errorf("openai-compatible analysis request failed: %w", err)
	}
	defer resp.Body.Close()

	responseBody, err := io.ReadAll(io.LimitReader(resp.Body, 2<<20))
	if err != nil {
		return AnalysisResult{}, fmt.Errorf("read openai analysis response: %w", err)
	}

	p.logger.Info("📥 openai analysis response",
		"provider", p.Name(),
		"status", resp.StatusCode,
		"duration_ms", elapsed.Milliseconds(),
		"response_body_len", len(responseBody),
	)

	if resp.StatusCode >= 300 {
		p.logger.Error("❌ openai analysis response failed",
			"status", resp.StatusCode,
			"provider", p.Name(),
			"duration_ms", elapsed.Milliseconds(),
			"body", truncateBody(responseBody, 2048),
		)
		return AnalysisResult{}, fmt.Errorf("openai-compatible analysis status %d: %s", resp.StatusCode, truncateBody(responseBody, 256))
	}

	var decoded openAIChatResponse
	if err := json.Unmarshal(responseBody, &decoded); err != nil {
		p.logger.Error("❌ openai analysis decode failed",
			"provider", p.Name(),
			"status", resp.StatusCode,
			"duration_ms", elapsed.Milliseconds(),
			"body", truncateBody(responseBody, 2048),
			"error", err,
		)
		return AnalysisResult{}, fmt.Errorf("decode openai analysis response: %w", err)
	}
	if len(decoded.Choices) == 0 {
		return AnalysisResult{}, fmt.Errorf("openai-compatible analysis response contained no choices")
	}

	text := flattenOpenAIContent(decoded.Choices[0].Message.Content)
	analyzeResp, err := parseAnalysisResponse(text)
	if err != nil {
		p.logger.Error("❌ openai analysis parse failed",
			"provider", p.Name(),
			"duration_ms", elapsed.Milliseconds(),
			"raw_text", truncateBody([]byte(text), 1024),
			"error", err,
		)
		return AnalysisResult{}, err
	}

	return AnalysisResult{
		Response: analyzeResp,
		Provider: p.Name(),
		Model:    decoded.Model,
		Usage: Usage{
			InputTokens:  decoded.Usage.PromptTokens,
			OutputTokens: decoded.Usage.CompletionTokens,
		},
	}, nil
}

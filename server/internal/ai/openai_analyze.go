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

func (p *OpenAICompatibleProvider) Analyze(ctx context.Context, req AnalyzeRequest, user UserContext) (AnalyzeResult, error) {
	if err := req.Validate(); err != nil {
		return AnalyzeResult{}, err
	}

	userPrompt, err := buildAnalyzeUserPrompt(req, user)
	if err != nil {
		return AnalyzeResult{}, err
	}

	systemPrompt := buildAnalyzeSystemPromptForProfile(req.DebugOptions.PromptProfileOrDefault())
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
		return AnalyzeResult{}, fmt.Errorf("marshal openai request: %w", err)
	}

	p.logger.Info("📤 openai analyze request",
		"provider", p.Name(),
		"model", p.model,
		"endpoint", p.baseURL,
		"user_id", user.UserID,
		"system_prompt_len", len(systemPrompt),
		"user_prompt_len", len(userPrompt),
		"request_body_len", len(body),
		"record_id", req.RecordShell.ID,
		"artifact_count", len(req.Artifacts),
	)

	httpReq, err := http.NewRequestWithContext(ctx, http.MethodPost, p.baseURL, bytes.NewReader(body))
	if err != nil {
		return AnalyzeResult{}, fmt.Errorf("create openai request: %w", err)
	}
	httpReq.Header.Set("Content-Type", "application/json")
	httpReq.Header.Set("Authorization", "Bearer "+p.apiKey)

	start := time.Now()
	resp, err := doRequestWithRetry(ctx, p.client, httpReq, p.maxRetries, p.backoff)
	elapsed := time.Since(start)
	if err != nil {
		p.logger.Error("❌ openai analyze request failed",
			"provider", p.Name(),
			"duration_ms", elapsed.Milliseconds(),
			"error", err,
		)
		return AnalyzeResult{}, fmt.Errorf("openai-compatible request failed: %w", err)
	}
	defer resp.Body.Close()

	responseBody, err := io.ReadAll(io.LimitReader(resp.Body, 2<<20))
	if err != nil {
		return AnalyzeResult{}, fmt.Errorf("read openai response: %w", err)
	}

	p.logger.Info("📥 openai analyze response",
		"provider", p.Name(),
		"status", resp.StatusCode,
		"duration_ms", elapsed.Milliseconds(),
		"response_body_len", len(responseBody),
	)

	if resp.StatusCode >= 300 {
		p.logger.Error("❌ openai analyze response failed",
			"status", resp.StatusCode,
			"provider", p.Name(),
			"duration_ms", elapsed.Milliseconds(),
			"body", truncateBody(responseBody, 2048),
		)
		return AnalyzeResult{}, fmt.Errorf("openai-compatible status %d: %s", resp.StatusCode, truncateBody(responseBody, 256))
	}

	var decoded openAIChatResponse
	if err := json.Unmarshal(responseBody, &decoded); err != nil {
		p.logger.Error("❌ openai analyze decode failed",
			"provider", p.Name(),
			"status", resp.StatusCode,
			"duration_ms", elapsed.Milliseconds(),
			"body", truncateBody(responseBody, 2048),
			"error", err,
		)
		return AnalyzeResult{}, fmt.Errorf("decode openai response: %w", err)
	}
	if len(decoded.Choices) == 0 {
		p.logger.Error("❌ openai analyze empty choices",
			"provider", p.Name(),
			"duration_ms", elapsed.Milliseconds(),
			"response_body", truncateBody(responseBody, 1024),
		)
		return AnalyzeResult{}, fmt.Errorf("openai-compatible response contained no choices")
	}

	text := flattenOpenAIContent(decoded.Choices[0].Message.Content)
	analyzeResp, err := parseAnalyzeResponse(text)
	if err != nil {
		p.logger.Error("❌ openai analyze parse failed",
			"provider", p.Name(),
			"duration_ms", elapsed.Milliseconds(),
			"raw_text", truncateBody([]byte(text), 1024),
			"error", err,
		)
		return AnalyzeResult{}, err
	}

	p.logger.Info("✅ openai analyze complete",
		"provider", p.Name(),
		"model", decoded.Model,
		"duration_ms", elapsed.Milliseconds(),
		"input_tokens", decoded.Usage.PromptTokens,
		"output_tokens", decoded.Usage.CompletionTokens,
		"entities_found", len(analyzeResp.Entities),
		"tags_found", len(analyzeResp.Tags),
		"edges_found", len(analyzeResp.Edges),
	)

	return AnalyzeResult{
		Response: analyzeResp,
		Provider: p.Name(),
		Model:    decoded.Model,
		Usage: Usage{
			InputTokens:  decoded.Usage.PromptTokens,
			OutputTokens: decoded.Usage.CompletionTokens,
		},
	}, nil
}

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

func (p *OpenAICompatibleProvider) GenerateReflection(ctx context.Context, req ReflectionRequest, user UserContext) (ReflectionResult, error) {
	return p.runReflection(ctx, req, user, "generate")
}

func (p *OpenAICompatibleProvider) ReplayReflection(ctx context.Context, req ReflectionRequest, user UserContext) (ReflectionResult, error) {
	return p.runReflection(ctx, req, user, "replay")
}

func (p *OpenAICompatibleProvider) runReflection(
	ctx context.Context,
	req ReflectionRequest,
	user UserContext,
	mode string,
) (ReflectionResult, error) {
	var validateErr error
	switch mode {
	case "generate":
		validateErr = req.ValidateGenerate()
	case "replay":
		validateErr = req.ValidateReplay()
	default:
		validateErr = fmt.Errorf("unsupported reflection mode %q", mode)
	}
	if validateErr != nil {
		return ReflectionResult{}, validateErr
	}

	userPrompt, err := buildReflectionUserPrompt(req, user, mode)
	if err != nil {
		return ReflectionResult{}, err
	}

	systemPrompt := buildReflectionSystemPromptForProfile(mode, req.DebugOptions.PromptProfileOrDefault())
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
		return ReflectionResult{}, fmt.Errorf("marshal openai reflection request: %w", err)
	}

	p.logger.Info("📤 openai reflection request",
		"provider", p.Name(),
		"model", p.model,
		"endpoint", p.baseURL,
		"mode", mode,
		"user_id", user.UserID,
		"system_prompt_len", len(systemPrompt),
		"user_prompt_len", len(userPrompt),
		"request_body_len", len(body),
	)

	httpReq, err := http.NewRequestWithContext(ctx, http.MethodPost, p.baseURL, bytes.NewReader(body))
	if err != nil {
		return ReflectionResult{}, fmt.Errorf("create openai reflection request: %w", err)
	}
	httpReq.Header.Set("Content-Type", "application/json")
	httpReq.Header.Set("Authorization", "Bearer "+p.apiKey)

	start := time.Now()
	resp, err := doRequestWithRetry(ctx, p.client, httpReq, p.maxRetries, p.backoff)
	elapsed := time.Since(start)
	if err != nil {
		p.logger.Error("❌ openai reflection request failed",
			"provider", p.Name(),
			"mode", mode,
			"duration_ms", elapsed.Milliseconds(),
			"error", err,
		)
		return ReflectionResult{}, fmt.Errorf("openai-compatible reflection request failed: %w", err)
	}
	defer resp.Body.Close()

	responseBody, err := io.ReadAll(io.LimitReader(resp.Body, 2<<20))
	if err != nil {
		return ReflectionResult{}, fmt.Errorf("read openai reflection response: %w", err)
	}

	p.logger.Info("📥 openai reflection response",
		"provider", p.Name(),
		"mode", mode,
		"status", resp.StatusCode,
		"duration_ms", elapsed.Milliseconds(),
		"response_body_len", len(responseBody),
	)

	if resp.StatusCode >= 300 {
		p.logger.Error("❌ openai reflection response failed",
			"status", resp.StatusCode,
			"provider", p.Name(),
			"mode", mode,
			"duration_ms", elapsed.Milliseconds(),
			"body", truncateBody(responseBody, 2048),
		)
		return ReflectionResult{}, fmt.Errorf("openai-compatible reflection status %d: %s", resp.StatusCode, truncateBody(responseBody, 256))
	}

	var decoded openAIChatResponse
	if err := json.Unmarshal(responseBody, &decoded); err != nil {
		p.logger.Error("❌ openai reflection decode failed",
			"provider", p.Name(),
			"mode", mode,
			"status", resp.StatusCode,
			"duration_ms", elapsed.Milliseconds(),
			"body", truncateBody(responseBody, 2048),
			"error", err,
		)
		return ReflectionResult{}, fmt.Errorf("decode openai reflection response: %w", err)
	}
	if len(decoded.Choices) == 0 {
		p.logger.Error("❌ openai reflection empty choices",
			"provider", p.Name(),
			"mode", mode,
			"duration_ms", elapsed.Milliseconds(),
		)
		return ReflectionResult{}, fmt.Errorf("openai-compatible reflection response contained no choices")
	}

	text := flattenOpenAIContent(decoded.Choices[0].Message.Content)
	reflectionResp, err := parseReflectionResponse(text)
	if err != nil {
		p.logger.Error("❌ openai reflection parse failed",
			"provider", p.Name(),
			"mode", mode,
			"duration_ms", elapsed.Milliseconds(),
			"raw_text", truncateBody([]byte(text), 1024),
			"error", err,
		)
		return ReflectionResult{}, err
	}

	p.logger.Info("✅ openai reflection complete",
		"provider", p.Name(),
		"model", decoded.Model,
		"mode", mode,
		"duration_ms", elapsed.Milliseconds(),
		"input_tokens", decoded.Usage.PromptTokens,
		"output_tokens", decoded.Usage.CompletionTokens,
		"title", truncateBody([]byte(reflectionResp.Title), 80),
	)

	return ReflectionResult{
		Response: reflectionResp,
		Provider: p.Name(),
		Model:    decoded.Model,
		Usage: Usage{
			InputTokens:  decoded.Usage.PromptTokens,
			OutputTokens: decoded.Usage.CompletionTokens,
		},
	}, nil
}

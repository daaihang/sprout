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

func (p *AnthropicProvider) GenerateReflection(ctx context.Context, req ReflectionRequest, user UserContext) (ReflectionResult, error) {
	return p.runReflection(ctx, req, user, "generate")
}

func (p *AnthropicProvider) ReplayReflection(ctx context.Context, req ReflectionRequest, user UserContext) (ReflectionResult, error) {
	return p.runReflection(ctx, req, user, "replay")
}

func (p *AnthropicProvider) runReflection(
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
	payload := anthropicRequest{
		Model:     p.model,
		MaxTokens: 700,
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
		return ReflectionResult{}, fmt.Errorf("marshal anthropic reflection request: %w", err)
	}

	p.logger.Info("📤 anthropic reflection request",
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
		return ReflectionResult{}, fmt.Errorf("create anthropic reflection request: %w", err)
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
		p.logger.Error("❌ anthropic reflection request failed",
			"provider", p.Name(),
			"mode", mode,
			"duration_ms", elapsed.Milliseconds(),
			"error", err,
		)
		return ReflectionResult{}, fmt.Errorf("anthropic reflection request failed: %w", err)
	}
	defer resp.Body.Close()

	responseBody, err := io.ReadAll(io.LimitReader(resp.Body, 2<<20))
	if err != nil {
		return ReflectionResult{}, fmt.Errorf("read anthropic reflection response: %w", err)
	}

	p.logger.Info("📥 anthropic reflection response",
		"provider", p.Name(),
		"mode", mode,
		"status", resp.StatusCode,
		"duration_ms", elapsed.Milliseconds(),
		"response_body_len", len(responseBody),
	)

	if resp.StatusCode >= 300 {
		p.logger.Error("❌ anthropic reflection response failed",
			"status", resp.StatusCode,
			"provider", p.Name(),
			"mode", mode,
			"duration_ms", elapsed.Milliseconds(),
			"body", truncateBody(responseBody, 2048),
		)
		return ReflectionResult{}, fmt.Errorf("anthropic reflection status %d", resp.StatusCode)
	}

	var decoded anthropicResponse
	if err := json.Unmarshal(responseBody, &decoded); err != nil {
		p.logger.Error("❌ anthropic reflection decode failed",
			"provider", p.Name(),
			"mode", mode,
			"duration_ms", elapsed.Milliseconds(),
			"body", truncateBody(responseBody, 2048),
			"error", err,
		)
		return ReflectionResult{}, fmt.Errorf("decode anthropic reflection response: %w", err)
	}

	reflectionResp, err := parseReflectionResponse(joinAnthropicText(decoded.Content))
	if err != nil {
		p.logger.Error("❌ anthropic reflection parse failed",
			"provider", p.Name(),
			"mode", mode,
			"duration_ms", elapsed.Milliseconds(),
			"error", err,
		)
		return ReflectionResult{}, err
	}

	p.logger.Info("✅ anthropic reflection complete",
		"provider", p.Name(),
		"model", decoded.Model,
		"mode", mode,
		"duration_ms", elapsed.Milliseconds(),
		"input_tokens", decoded.Usage.InputTokens,
		"output_tokens", decoded.Usage.OutputTokens,
		"title", truncateBody([]byte(reflectionResp.Title), 80),
	)

	return ReflectionResult{
		Response: reflectionResp,
		Provider: p.Name(),
		Model:    decoded.Model,
		Usage: Usage{
			InputTokens:  decoded.Usage.InputTokens,
			OutputTokens: decoded.Usage.OutputTokens,
		},
	}, nil
}

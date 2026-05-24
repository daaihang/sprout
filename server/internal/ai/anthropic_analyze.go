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

func (p *AnthropicProvider) Analyze(ctx context.Context, req AnalyzeRequest, user UserContext) (AnalyzeResult, error) {
	if err := req.Validate(); err != nil {
		return AnalyzeResult{}, err
	}

	userPrompt, err := buildAnalyzeUserPrompt(req, user)
	if err != nil {
		return AnalyzeResult{}, err
	}

	systemPrompt := buildAnalyzeSystemPromptForProfile(req.DebugOptions.PromptProfileOrDefault())
	payload := anthropicRequest{
		Model:     p.model,
		MaxTokens: 800,
		System:    systemPrompt,
		Messages: []anthropicMessage{{
			Role: "user",
			Content: []anthropicContentRequest{{
				Type: "text",
				Text: userPrompt,
			}},
		}},
		Tools: []anthropicTool{analyzeResponseTool()},
		ToolChoice: &anthropicToolChoice{
			Type: "tool",
			Name: "submit_analyze_response",
		},
	}

	body, err := json.Marshal(payload)
	if err != nil {
		return AnalyzeResult{}, fmt.Errorf("marshal anthropic request: %w", err)
	}

	p.logger.Info("📤 anthropic analyze request",
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
		return AnalyzeResult{}, fmt.Errorf("create anthropic request: %w", err)
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
		p.logger.Error("❌ anthropic analyze request failed",
			"provider", p.Name(),
			"duration_ms", elapsed.Milliseconds(),
			"error", err,
		)
		return AnalyzeResult{}, fmt.Errorf("anthropic request failed: %w", err)
	}
	defer resp.Body.Close()

	responseBody, err := io.ReadAll(io.LimitReader(resp.Body, 2<<20))
	if err != nil {
		return AnalyzeResult{}, fmt.Errorf("read anthropic response: %w", err)
	}

	p.logger.Info("📥 anthropic analyze response",
		"provider", p.Name(),
		"status", resp.StatusCode,
		"duration_ms", elapsed.Milliseconds(),
		"response_body_len", len(responseBody),
	)

	if resp.StatusCode >= 300 {
		p.logger.Error("❌ anthropic analyze response failed",
			"status", resp.StatusCode,
			"provider", p.Name(),
			"duration_ms", elapsed.Milliseconds(),
			"body", truncateBody(responseBody, 2048),
		)
		return AnalyzeResult{}, fmt.Errorf("anthropic status %d", resp.StatusCode)
	}

	var decoded anthropicResponse
	if err := json.Unmarshal(responseBody, &decoded); err != nil {
		p.logger.Error("❌ anthropic analyze decode failed",
			"provider", p.Name(),
			"duration_ms", elapsed.Milliseconds(),
			"body", truncateBody(responseBody, 2048),
			"error", err,
		)
		return AnalyzeResult{}, fmt.Errorf("decode anthropic response: %w", err)
	}

	analyzeResp, err := anthropicToolResponse(decoded.Content)
	if err != nil {
		p.logger.Error("❌ anthropic analyze parse failed",
			"provider", p.Name(),
			"duration_ms", elapsed.Milliseconds(),
			"error", err,
		)
		return AnalyzeResult{}, err
	}

	p.logger.Info("✅ anthropic analyze complete",
		"provider", p.Name(),
		"model", decoded.Model,
		"duration_ms", elapsed.Milliseconds(),
		"input_tokens", decoded.Usage.InputTokens,
		"output_tokens", decoded.Usage.OutputTokens,
		"entities_found", len(analyzeResp.Entities),
		"tags_found", len(analyzeResp.Tags),
		"edges_found", len(analyzeResp.Edges),
	)

	return AnalyzeResult{
		Response: analyzeResp,
		Provider: p.Name(),
		Model:    decoded.Model,
		Usage: Usage{
			InputTokens:  decoded.Usage.InputTokens,
			OutputTokens: decoded.Usage.OutputTokens,
		},
	}, nil
}

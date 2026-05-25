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

func (p *AnthropicProvider) Analyze(ctx context.Context, req AnalysisRequest, user UserContext) (AnalysisResult, error) {
	if err := req.Validate(); err != nil {
		return AnalysisResult{}, err
	}

	userPrompt, err := buildAnalysisUserPrompt(req, user)
	if err != nil {
		return AnalysisResult{}, err
	}

	systemPrompt := buildAnalysisSystemPrompt()
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
		Tools:      []anthropicTool{analysisResponseTool()},
		ToolChoice: &anthropicToolChoice{Type: "tool", Name: "submit_analysis_response"},
	}

	body, err := json.Marshal(payload)
	if err != nil {
		return AnalysisResult{}, fmt.Errorf("marshal anthropic analysis request: %w", err)
	}

	p.logger.Info("📤 anthropic analysis request",
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
		return AnalysisResult{}, fmt.Errorf("create anthropic analysis request: %w", err)
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
		p.logger.Error("❌ anthropic analysis request failed",
			"provider", p.Name(),
			"duration_ms", elapsed.Milliseconds(),
			"error", err,
		)
		return AnalysisResult{}, fmt.Errorf("anthropic analysis request failed: %w", err)
	}
	defer resp.Body.Close()

	responseBody, err := io.ReadAll(io.LimitReader(resp.Body, 2<<20))
	if err != nil {
		return AnalysisResult{}, fmt.Errorf("read anthropic analysis response: %w", err)
	}

	p.logger.Info("📥 anthropic analysis response",
		"provider", p.Name(),
		"status", resp.StatusCode,
		"duration_ms", elapsed.Milliseconds(),
		"response_body_len", len(responseBody),
	)

	if resp.StatusCode >= 300 {
		p.logger.Error("❌ anthropic analysis response failed",
			"status", resp.StatusCode,
			"provider", p.Name(),
			"duration_ms", elapsed.Milliseconds(),
			"body", truncateBody(responseBody, 2048),
		)
		return AnalysisResult{}, fmt.Errorf("anthropic analysis status %d", resp.StatusCode)
	}

	var decoded anthropicResponse
	if err := json.Unmarshal(responseBody, &decoded); err != nil {
		p.logger.Error("❌ anthropic analysis decode failed",
			"provider", p.Name(),
			"duration_ms", elapsed.Milliseconds(),
			"body", truncateBody(responseBody, 2048),
			"error", err,
		)
		return AnalysisResult{}, fmt.Errorf("decode anthropic analysis response: %w", err)
	}

	analyzeResp, err := anthropicAnalysisResponse(decoded.Content)
	if err != nil {
		p.logger.Error("❌ anthropic analysis parse failed",
			"provider", p.Name(),
			"duration_ms", elapsed.Milliseconds(),
			"body", truncateBody(responseBody, 1024),
			"error", err,
		)
		return AnalysisResult{}, err
	}

	return AnalysisResult{
		Response: analyzeResp,
		Provider: p.Name(),
		Model:    decoded.Model,
		Usage: Usage{
			InputTokens:  decoded.Usage.InputTokens,
			OutputTokens: decoded.Usage.OutputTokens,
		},
	}, nil
}

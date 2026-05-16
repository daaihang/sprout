package ai

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"strings"
	"time"

	"sprout/server/internal/config"
)

type AnthropicProvider struct {
	client      *http.Client
	logger      *slog.Logger
	apiKey      string
	baseURL     string
	model       string
	version     string
	heliconeKey string
	maxRetries  int
	backoff     time.Duration
}

type anthropicRequest struct {
	Model      string               `json:"model"`
	MaxTokens  int                  `json:"max_tokens"`
	System     string               `json:"system"`
	Messages   []anthropicMessage   `json:"messages"`
	Tools      []anthropicTool      `json:"tools,omitempty"`
	ToolChoice *anthropicToolChoice `json:"tool_choice,omitempty"`
}

type anthropicMessage struct {
	Role    string                    `json:"role"`
	Content []anthropicContentRequest `json:"content"`
}

type anthropicContentRequest struct {
	Type string `json:"type"`
	Text string `json:"text"`
}

type anthropicResponse struct {
	Model   string                  `json:"model"`
	Content []anthropicContentBlock `json:"content"`
	Usage   anthropicUsage          `json:"usage"`
}

type anthropicContentBlock struct {
	Type  string          `json:"type"`
	Text  string          `json:"text"`
	Name  string          `json:"name"`
	Input json.RawMessage `json:"input"`
}

type anthropicUsage struct {
	InputTokens  int `json:"input_tokens"`
	OutputTokens int `json:"output_tokens"`
}

type anthropicTool struct {
	Name        string         `json:"name"`
	Description string         `json:"description"`
	InputSchema map[string]any `json:"input_schema"`
}

type anthropicToolChoice struct {
	Type string `json:"type"`
	Name string `json:"name"`
}

func NewAnthropicProvider(client *http.Client, logger *slog.Logger, cfg config.Config) *AnthropicProvider {
	baseURL := strings.TrimSpace(cfg.AIBaseURL)
	if baseURL == "" {
		baseURL = "https://api.anthropic.com/v1/messages"
	}
	return &AnthropicProvider{
		client:      client,
		logger:      logger,
		apiKey:      cfg.AIAPIKey,
		baseURL:     baseURL,
		model:       cfg.AIModel,
		version:     cfg.AnthropicVersion,
		heliconeKey: cfg.HeliconeKey,
		maxRetries:  cfg.AIMaxRetries,
		backoff:     cfg.AIRetryBackoff,
	}
}

func (p *AnthropicProvider) Name() string {
	return "anthropic"
}

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

func analyzeResponseTool() anthropicTool {
	return anthropicTool{
		Name:        "submit_analyze_response",
		Description: "Submit the final structured analyze response for the journaling record.",
		InputSchema: map[string]any{
			"type": "object",
			"properties": map[string]any{
				"tags": map[string]any{"type": "array", "items": map[string]any{"type": "string"}},
				"emotion": map[string]any{
					"type": "object",
					"properties": map[string]any{
						"label":      map[string]any{"type": "string"},
						"intensity":  map[string]any{"type": "number"},
						"confidence": map[string]any{"type": "number"},
					},
					"required": []string{"label"},
				},
				"entities": map[string]any{
					"type": "array",
					"items": map[string]any{
						"type": "object",
						"properties": map[string]any{
							"kind":                map[string]any{"type": "string"},
							"name":                map[string]any{"type": "string"},
							"canonical_name":      map[string]any{"type": "string"},
							"confidence":          map[string]any{"type": "number"},
							"source_artifact_ids": map[string]any{"type": "array", "items": map[string]any{"type": "string"}},
						},
						"required": []string{"kind", "name"},
					},
				},
				"candidate_edges": map[string]any{
					"type": "array",
					"items": map[string]any{
						"type": "object",
						"properties": map[string]any{
							"from_name":   map[string]any{"type": "string"},
							"from_kind":   map[string]any{"type": "string"},
							"to_name":     map[string]any{"type": "string"},
							"to_kind":     map[string]any{"type": "string"},
							"relation":    map[string]any{"type": "string"},
							"confidence":  map[string]any{"type": "number"},
						},
						"required": []string{"from_name", "from_kind", "to_name", "to_kind", "relation"},
					},
				},
				"insight": map[string]any{"type": "string"},
				"summary": map[string]any{"type": "string"},
				"salience_score": map[string]any{"type": "number"},
				"retrieval_terms": map[string]any{
					"type": "array",
					"items": map[string]any{"type": "string"},
				},
				"reflection_hint": map[string]any{"type": "string"},
				"follow_up": map[string]any{
					"anyOf": []any{
						map[string]any{"type": "null"},
						map[string]any{
							"type": "object",
							"properties": map[string]any{
								"question":   map[string]any{"type": "string"},
								"expires_at": map[string]any{"type": "string"},
							},
							"required": []string{"question"},
						},
					},
				},
			},
			"required": []string{"tags", "emotion", "entities", "candidate_edges", "insight"},
		},
	}
}

func anthropicToolResponse(blocks []anthropicContentBlock) (AnalyzeResponse, error) {
	for _, block := range blocks {
		if block.Type != "tool_use" || block.Name != "submit_analyze_response" {
			continue
		}
		var response AnalyzeResponse
		if err := json.Unmarshal(block.Input, &response); err != nil {
			return AnalyzeResponse{}, fmt.Errorf("decode anthropic tool response: %w", err)
		}
		return NormalizeResponse(response), nil
	}

	text := joinAnthropicText(blocks)
	return parseAnalyzeResponse(text)
}

func joinAnthropicText(blocks []anthropicContentBlock) string {
	var builder strings.Builder
	for _, block := range blocks {
		if block.Type != "text" {
			continue
		}
		if builder.Len() > 0 {
			builder.WriteByte('\n')
		}
		builder.WriteString(block.Text)
	}
	return builder.String()
}

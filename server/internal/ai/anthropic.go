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

	payload := anthropicRequest{
		Model:     p.model,
		MaxTokens: 800,
		System:    buildAnalyzeSystemPrompt(),
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

	resp, err := doRequestWithRetry(ctx, p.client, httpReq, p.maxRetries, p.backoff)
	if err != nil {
		return AnalyzeResult{}, fmt.Errorf("anthropic request failed: %w", err)
	}
	defer resp.Body.Close()

	responseBody, err := io.ReadAll(io.LimitReader(resp.Body, 2<<20))
	if err != nil {
		return AnalyzeResult{}, fmt.Errorf("read anthropic response: %w", err)
	}
	if resp.StatusCode >= 300 {
		p.logger.Error("anthropic response failed", "status", resp.StatusCode, "provider", p.Name())
		return AnalyzeResult{}, fmt.Errorf("anthropic status %d", resp.StatusCode)
	}

	var decoded anthropicResponse
	if err := json.Unmarshal(responseBody, &decoded); err != nil {
		return AnalyzeResult{}, fmt.Errorf("decode anthropic response: %w", err)
	}

	analyzeResp, err := anthropicToolResponse(decoded.Content)
	if err != nil {
		return AnalyzeResult{}, err
	}

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
						"intensity":  map[string]any{"type": "integer"},
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

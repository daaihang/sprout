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

type OpenAICompatibleProvider struct {
	client     *http.Client
	logger     *slog.Logger
	apiKey     string
	baseURL    string
	model      string
	maxRetries int
	backoff    time.Duration
}

type openAIChatRequest struct {
	Model          string            `json:"model"`
	ResponseFormat map[string]string `json:"response_format,omitempty"`
	Messages       []openAIMessage   `json:"messages"`
	Temperature    float64           `json:"temperature"`
}

type openAIMessage struct {
	Role    string `json:"role"`
	Content string `json:"content"`
}

type openAIChatResponse struct {
	Model   string         `json:"model"`
	Choices []openAIChoice `json:"choices"`
	Usage   openAIUsage    `json:"usage"`
}

type openAIChoice struct {
	Message openAIChoiceMessage `json:"message"`
}

type openAIChoiceMessage struct {
	Content any `json:"content"`
}

type openAIUsage struct {
	PromptTokens     int `json:"prompt_tokens"`
	CompletionTokens int `json:"completion_tokens"`
}

func NewOpenAICompatibleProvider(client *http.Client, logger *slog.Logger, cfg config.Config) *OpenAICompatibleProvider {
	baseURL := resolveOpenAICompatibleEndpoint(cfg.AIBaseURL)
	return &OpenAICompatibleProvider{
		client:     client,
		logger:     logger,
		apiKey:     cfg.AIAPIKey,
		baseURL:    baseURL,
		model:      cfg.AIModel,
		maxRetries: cfg.AIMaxRetries,
		backoff:    cfg.AIRetryBackoff,
	}
}

func resolveOpenAICompatibleEndpoint(raw string) string {
	baseURL := strings.TrimSpace(raw)
	if baseURL == "" {
		return "https://api.openai.com/v1/chat/completions"
	}

	baseURL = strings.TrimRight(baseURL, "/")
	switch {
	case strings.HasSuffix(baseURL, "/chat/completions"):
		return baseURL
	case strings.HasSuffix(baseURL, "/v1"):
		return baseURL + "/chat/completions"
	case strings.HasSuffix(baseURL, "/chat"):
		return baseURL + "/completions"
	default:
		return baseURL + "/chat/completions"
	}
}

func (p *OpenAICompatibleProvider) Name() string {
	return "openai_compatible"
}

func (p *OpenAICompatibleProvider) Analyze(ctx context.Context, req AnalyzeRequest, user UserContext) (AnalyzeResult, error) {
	if err := req.Validate(); err != nil {
		return AnalyzeResult{}, err
	}

	userPrompt, err := buildAnalyzeUserPrompt(req, user)
	if err != nil {
		return AnalyzeResult{}, err
	}

	payload := openAIChatRequest{
		Model:          p.model,
		ResponseFormat: map[string]string{"type": "json_object"},
		Temperature:    0.2,
		Messages: []openAIMessage{
			{Role: "system", Content: buildAnalyzeSystemPrompt()},
			{Role: "user", Content: userPrompt},
		},
	}

	body, err := json.Marshal(payload)
	if err != nil {
		return AnalyzeResult{}, fmt.Errorf("marshal openai request: %w", err)
	}

	httpReq, err := http.NewRequestWithContext(ctx, http.MethodPost, p.baseURL, bytes.NewReader(body))
	if err != nil {
		return AnalyzeResult{}, fmt.Errorf("create openai request: %w", err)
	}
	httpReq.Header.Set("Content-Type", "application/json")
	httpReq.Header.Set("Authorization", "Bearer "+p.apiKey)

	resp, err := doRequestWithRetry(ctx, p.client, httpReq, p.maxRetries, p.backoff)
	if err != nil {
		return AnalyzeResult{}, fmt.Errorf("openai-compatible request failed: %w", err)
	}
	defer resp.Body.Close()

	responseBody, err := io.ReadAll(io.LimitReader(resp.Body, 2<<20))
	if err != nil {
		return AnalyzeResult{}, fmt.Errorf("read openai response: %w", err)
	}
	if resp.StatusCode >= 300 {
		p.logger.Error("openai-compatible response failed", "status", resp.StatusCode, "provider", p.Name())
		return AnalyzeResult{}, fmt.Errorf("openai-compatible status %d", resp.StatusCode)
	}

	var decoded openAIChatResponse
	if err := json.Unmarshal(responseBody, &decoded); err != nil {
		return AnalyzeResult{}, fmt.Errorf("decode openai response: %w", err)
	}
	if len(decoded.Choices) == 0 {
		return AnalyzeResult{}, fmt.Errorf("openai-compatible response contained no choices")
	}

	text := flattenOpenAIContent(decoded.Choices[0].Message.Content)
	analyzeResp, err := parseAnalyzeResponse(text)
	if err != nil {
		return AnalyzeResult{}, err
	}

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

func flattenOpenAIContent(content any) string {
	switch value := content.(type) {
	case string:
		return value
	case []any:
		var builder strings.Builder
		for _, item := range value {
			block, ok := item.(map[string]any)
			if !ok {
				continue
			}
			textValue, _ := block["text"].(string)
			if textValue == "" {
				if nested, ok := block["text"].(map[string]any); ok {
					textValue, _ = nested["value"].(string)
				}
			}
			if textValue == "" {
				continue
			}
			if builder.Len() > 0 {
				builder.WriteByte('\n')
			}
			builder.WriteString(textValue)
		}
		return builder.String()
	default:
		return ""
	}
}

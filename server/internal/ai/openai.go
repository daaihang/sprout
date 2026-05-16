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
	Thinking       *thinkingConfig   `json:"thinking,omitempty"`
}

// thinkingConfig controls DeepSeek v4-pro thinking mode.
// Set Type to "disabled" to use non-thinking (standard chat) mode.
type thinkingConfig struct {
	Type string `json:"type"` // "enabled" or "disabled"
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

// thinkingConfig returns a disabled thinking config for DeepSeek v4-pro models.
// For non-DeepSeek models, returns nil (field omitted from JSON).
func (p *OpenAICompatibleProvider) thinkingConfig() *thinkingConfig {
	if strings.Contains(p.model, "deepseek") {
		return &thinkingConfig{Type: "disabled"}
	}
	return nil
}

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

func truncateBody(body []byte, limit int) string {
	if len(body) <= limit {
		return string(body)
	}
	return string(body[:limit]) + "…"
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

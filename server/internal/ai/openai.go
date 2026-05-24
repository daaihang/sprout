package ai

import (
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

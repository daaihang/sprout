package ai

import (
	"encoding/json"
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

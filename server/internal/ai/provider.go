package ai

import (
	"fmt"
	"log/slog"
	"net/http"

	"sprout/server/internal/config"
)

func NewProvider(cfg config.Config, logger *slog.Logger) (Provider, error) {
	if cfg.AIMode == config.AIModeMock {
		return NewMockProvider(), nil
	}

	client := &http.Client{Timeout: cfg.HTTPTimeout}

	switch cfg.AIProvider {
	case config.AIProviderAnthropic:
		return NewAnthropicProvider(client, logger, cfg), nil
	case config.AIProviderOpenAICompatible:
		return NewOpenAICompatibleProvider(client, logger, cfg), nil
	default:
		return nil, fmt.Errorf("unsupported AI provider %q", cfg.AIProvider)
	}
}

package config

import (
	"errors"
	"fmt"
	"log/slog"
	"os"
	"strconv"
	"strings"
	"time"

	"github.com/joho/godotenv"
)

const (
	AIModeMock = "mock"
	AIModeLive = "live"

	AIProviderMock             = "mock"
	AIProviderAnthropic        = "anthropic"
	AIProviderOpenAICompatible = "openai_compatible"
)

type Config struct {
	AppEnv                            string
	Port                              string
	JWTSecret                         string
	JWTIssuer                         string
	TokenTTL                          time.Duration
	RequestTimeout                    time.Duration
	SQLitePath                        string
	DevAuthEnabled                    bool
	DevAuthUserID                     string
	DefaultTier                       string
	SubscriptionMode                  string
	AppleAudiences                    []string
	AppleIssuer                       string
	AppleJWKSURL                      string
	AppleJWKSTTL                      time.Duration
	AppleHTTPTimeout                  time.Duration
	AIMode                            string
	AIProvider                        string
	AIModel                           string
	AIBaseURL                         string
	AIAPIKey                          string
	AnthropicVersion                  string
	HeliconeKey                       string
	HTTPTimeout                       time.Duration
	AIMaxRetries                      int
	AIRetryBackoff                    time.Duration
	APNSEnabled                       bool
	APNSEnvironment                   string
	APNSKeyID                         string
	APNSTeamID                        string
	APNSTopic                         string
	APNSAuthKeyPath                   string
	APNSAuthKey                       string
	APNSBaseURL                       string
	PushDeliveryWorkerEnabled         bool
	PushDeliveryInterval              time.Duration
	PushDeliveryBatchSize             int
	PushDeliveryMaxAttempts           int
	PushDeliveryRetryBackoff          time.Duration
	PushDeliveryAlertFailureThreshold int
}

func Load() (Config, error) {
	// Load .env file if it exists
	_ = godotenv.Load(".env")

	cfg := Config{
		AppEnv:                            envString("APP_ENV", "development"),
		Port:                              envString("PORT", "8080"),
		JWTSecret:                         envString("JWT_SECRET", ""),
		JWTIssuer:                         envString("JWT_ISSUER", "sprout-server"),
		TokenTTL:                          envDuration("JWT_TTL", 1*time.Hour),
		RequestTimeout:                    envDuration("REQUEST_TIMEOUT", 15*time.Second),
		SQLitePath:                        envString("SQLITE_PATH", "./sprout.db"),
		DevAuthEnabled:                    envBool("DEV_AUTH_ENABLED", true),
		DevAuthUserID:                     envString("DEV_AUTH_USER_ID", "dev-user"),
		DefaultTier:                       envString("DEFAULT_TIER", "seed"),
		SubscriptionMode:                  envString("SUBSCRIPTION_MODE", "mock"),
		AppleAudiences:                    envStringList("APPLE_AUDIENCES", []string{"com.speculolabs.mory"}),
		AppleIssuer:                       envString("APPLE_ISSUER", "https://appleid.apple.com"),
		AppleJWKSURL:                      envString("APPLE_JWKS_URL", "https://appleid.apple.com/auth/keys"),
		AppleJWKSTTL:                      envDuration("APPLE_JWKS_TTL", 6*time.Hour),
		AppleHTTPTimeout:                  envDuration("APPLE_HTTP_TIMEOUT", 10*time.Second),
		AIMode:                            envString("AI_MODE", AIModeMock),
		AIProvider:                        envString("AI_PROVIDER", AIProviderMock),
		AIModel:                           envString("AI_MODEL", ""),
		AIBaseURL:                         envString("AI_BASE_URL", ""),
		AIAPIKey:                          envString("AI_API_KEY", ""),
		AnthropicVersion:                  envString("ANTHROPIC_VERSION", "2023-06-01"),
		HeliconeKey:                       envString("HELICONE_KEY", ""),
		HTTPTimeout:                       envDuration("HTTP_TIMEOUT", 20*time.Second),
		AIMaxRetries:                      envInt("AI_MAX_RETRIES", 2),
		AIRetryBackoff:                    envDuration("AI_RETRY_BACKOFF", 300*time.Millisecond),
		APNSEnabled:                       envBool("APNS_ENABLED", false),
		APNSEnvironment:                   envString("APNS_ENVIRONMENT", "sandbox"),
		APNSKeyID:                         envString("APNS_KEY_ID", ""),
		APNSTeamID:                        envString("APNS_TEAM_ID", ""),
		APNSTopic:                         envString("APNS_TOPIC", firstString(envStringList("APPLE_AUDIENCES", []string{"com.speculolabs.mory"}))),
		APNSAuthKeyPath:                   envString("APNS_AUTH_KEY_PATH", ""),
		APNSAuthKey:                       envString("APNS_AUTH_KEY", ""),
		APNSBaseURL:                       envString("APNS_BASE_URL", ""),
		PushDeliveryWorkerEnabled:         envBool("PUSH_DELIVERY_WORKER_ENABLED", true),
		PushDeliveryInterval:              envDuration("PUSH_DELIVERY_INTERVAL", 30*time.Second),
		PushDeliveryBatchSize:             envInt("PUSH_DELIVERY_BATCH_SIZE", 32),
		PushDeliveryMaxAttempts:           envInt("PUSH_DELIVERY_MAX_ATTEMPTS", 5),
		PushDeliveryRetryBackoff:          envDuration("PUSH_DELIVERY_RETRY_BACKOFF", 2*time.Minute),
		PushDeliveryAlertFailureThreshold: envInt("PUSH_DELIVERY_ALERT_FAILURE_THRESHOLD", 3),
	}

	if cfg.JWTSecret == "" {
		if cfg.AppEnv == "production" {
			return Config{}, errors.New("JWT_SECRET is required in production")
		}
		cfg.JWTSecret = "dev-secret-change-me"
	}

	if cfg.AIMode != AIModeMock && cfg.AIMode != AIModeLive {
		return Config{}, fmt.Errorf("unsupported AI_MODE %q", cfg.AIMode)
	}

	if cfg.AIMode == AIModeMock {
		cfg.AIProvider = AIProviderMock
	}

	if cfg.AIMode == AIModeLive {
		if cfg.AIProvider != AIProviderAnthropic && cfg.AIProvider != AIProviderOpenAICompatible {
			return Config{}, fmt.Errorf("unsupported AI_PROVIDER %q", cfg.AIProvider)
		}
		if cfg.AIAPIKey == "" {
			return Config{}, errors.New("AI_API_KEY is required when AI_MODE=live")
		}
		if cfg.AIModel == "" {
			return Config{}, errors.New("AI_MODEL is required when AI_MODE=live")
		}
	}

	return cfg, nil
}

func firstString(values []string) string {
	for _, value := range values {
		if trimmed := strings.TrimSpace(value); trimmed != "" {
			return trimmed
		}
	}
	return ""
}

func (c Config) ListenAddr() string {
	return ":" + c.Port
}

func (c Config) LogLevel() slog.Level {
	if strings.EqualFold(c.AppEnv, "production") {
		return slog.LevelInfo
	}
	return slog.LevelDebug
}

func envString(key, fallback string) string {
	if value := strings.TrimSpace(os.Getenv(key)); value != "" {
		return value
	}
	return fallback
}

func envBool(key string, fallback bool) bool {
	value := strings.TrimSpace(os.Getenv(key))
	if value == "" {
		return fallback
	}
	parsed, err := strconv.ParseBool(value)
	if err != nil {
		return fallback
	}
	return parsed
}

func envInt(key string, fallback int) int {
	value := strings.TrimSpace(os.Getenv(key))
	if value == "" {
		return fallback
	}
	parsed, err := strconv.Atoi(value)
	if err != nil {
		return fallback
	}
	return parsed
}

func envDuration(key string, fallback time.Duration) time.Duration {
	value := strings.TrimSpace(os.Getenv(key))
	if value == "" {
		return fallback
	}
	parsed, err := time.ParseDuration(value)
	if err != nil {
		return fallback
	}
	return parsed
}

func envStringList(key string, fallback []string) []string {
	value := strings.TrimSpace(os.Getenv(key))
	if value == "" {
		return fallback
	}

	parts := strings.Split(value, ",")
	values := make([]string, 0, len(parts))
	for _, part := range parts {
		if trimmed := strings.TrimSpace(part); trimmed != "" {
			values = append(values, trimmed)
		}
	}
	if len(values) == 0 {
		return fallback
	}
	return values
}

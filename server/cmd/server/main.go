package main

import (
	"context"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"sprout/server/internal/ai"
	"sprout/server/internal/auth"
	"sprout/server/internal/config"
	"sprout/server/internal/db"
	httpapi "sprout/server/internal/http"
	"sprout/server/internal/push"
	"sprout/server/internal/subscription"
)

func main() {
	cfg, err := config.Load()
	if err != nil {
		slog.Error("load config", "error", err)
		os.Exit(1)
	}

	logger := slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{
		Level: cfg.LogLevel(),
	}))

	store, err := db.NewSQLiteStore(cfg.SQLitePath)
	if err != nil {
		logger.Error("open sqlite", "error", err)
		os.Exit(1)
	}
	defer store.Close()

	authenticator := auth.NewAuthenticator(cfg.JWTSecret, cfg.JWTIssuer, cfg.TokenTTL)
	appleVerifier := auth.NewAppleIdentityVerifier(cfg, logger)
	subscriptionService := subscription.NewService(cfg.SubscriptionMode, cfg.DefaultTier)

	aiProvider, err := ai.NewProvider(cfg, logger)
	if err != nil {
		logger.Error("init ai provider", "error", err)
		os.Exit(1)
	}
	apnsClient, err := push.NewAPNSClient(push.APNSClientConfig{
		Enabled:     cfg.APNSEnabled,
		Environment: cfg.APNSEnvironment,
		KeyID:       cfg.APNSKeyID,
		TeamID:      cfg.APNSTeamID,
		Topic:       cfg.APNSTopic,
		AuthKeyPath: cfg.APNSAuthKeyPath,
		AuthKeyPEM:  cfg.APNSAuthKey,
		BaseURL:     cfg.APNSBaseURL,
		Logger:      logger,
	})
	if err != nil {
		logger.Error("init apns client", "error", err)
		os.Exit(1)
	}

	pushDeliveryWorker := push.NewPushDeliveryWorkerWithOptions(
		store,
		apnsClient,
		logger,
		firstNonEmpty(cfg.APNSTopic, firstAudienceOrFallback(cfg.AppleAudiences, "com.speculolabs.mory")),
		push.PushDeliveryWorkerOptions{
			MaxAttempts:           cfg.PushDeliveryMaxAttempts,
			RetryBackoff:          cfg.PushDeliveryRetryBackoff,
			AlertFailureThreshold: cfg.PushDeliveryAlertFailureThreshold,
		},
	)

	app := httpapi.NewServer(httpapi.Dependencies{
		Config:             cfg,
		Logger:             logger,
		Authenticator:      authenticator,
		AppleVerifier:      appleVerifier,
		AIProvider:         aiProvider,
		Subscription:       subscriptionService,
		PushTokens:         store,
		UserProfiles:       store,
		PushDeliveryWorker: pushDeliveryWorker,
	})

	srv := &http.Server{
		Addr:              cfg.ListenAddr(),
		Handler:           app.Handler(),
		ReadHeaderTimeout: 5 * time.Second,
	}

	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()

	if cfg.PushDeliveryWorkerEnabled {
		go pushDeliveryWorker.RunScheduledDeliveryLoop(
			ctx,
			cfg.PushDeliveryInterval,
			cfg.PushDeliveryBatchSize,
		)
	}

	go func() {
		logger.Info("🚀 server starting",
			"addr", cfg.ListenAddr(),
			"ai_mode", cfg.AIMode,
			"ai_provider", cfg.AIProvider,
			"ai_model", cfg.AIModel,
			"ai_base_url", cfg.AIBaseURL,
			"ai_api_key_set", cfg.AIAPIKey != "",
			"ai_api_key_preview", maskAPIKey(cfg.AIAPIKey),
			"request_timeout", cfg.RequestTimeout.String(),
			"http_timeout", cfg.HTTPTimeout.String(),
			"ai_max_retries", cfg.AIMaxRetries,
			"ai_retry_backoff", cfg.AIRetryBackoff.String(),
			"dev_auth_enabled", cfg.DevAuthEnabled,
			"sqlite_path", cfg.SQLitePath,
			"apns_enabled", cfg.APNSEnabled,
			"apns_environment", cfg.APNSEnvironment,
			"apns_topic", cfg.APNSTopic,
			"push_delivery_worker_enabled", cfg.PushDeliveryWorkerEnabled,
			"push_delivery_interval", cfg.PushDeliveryInterval.String(),
			"push_delivery_batch_size", cfg.PushDeliveryBatchSize,
			"push_delivery_max_attempts", cfg.PushDeliveryMaxAttempts,
			"push_delivery_retry_backoff", cfg.PushDeliveryRetryBackoff.String(),
			"push_delivery_alert_failure_threshold", cfg.PushDeliveryAlertFailureThreshold,
		)
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			logger.Error("server failed", "error", err)
			stop()
		}
	}()

	<-ctx.Done()
	shutdownCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	if err := srv.Shutdown(shutdownCtx); err != nil {
		logger.Error("shutdown failed", "error", err)
	}
}

func maskAPIKey(key string) string {
	if len(key) <= 8 {
		return "***"
	}
	return key[:4] + "..." + key[len(key)-4:]
}

func firstAudienceOrFallback(values []string, fallback string) string {
	for _, value := range values {
		if value != "" {
			return value
		}
	}
	return fallback
}

func firstNonEmpty(values ...string) string {
	for _, value := range values {
		if value != "" {
			return value
		}
	}
	return ""
}

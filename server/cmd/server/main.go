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

	app := httpapi.NewServer(httpapi.Dependencies{
		Config:        cfg,
		Logger:        logger,
		Authenticator: authenticator,
		AppleVerifier: appleVerifier,
		AIProvider:    aiProvider,
		Subscription:  subscriptionService,
		PushTokens:    store,
	})

	srv := &http.Server{
		Addr:              cfg.ListenAddr(),
		Handler:           app.Handler(),
		ReadHeaderTimeout: 5 * time.Second,
	}

	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()

	go func() {
		logger.Info("server starting", "addr", cfg.ListenAddr(), "ai_mode", cfg.AIMode, "ai_provider", cfg.AIProvider)
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

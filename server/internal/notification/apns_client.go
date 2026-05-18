package notification

import (
	"bytes"
	"context"
	"crypto/ecdsa"
	"crypto/rand"
	"crypto/sha256"
	"crypto/x509"
	"encoding/base64"
	"encoding/json"
	"encoding/pem"
	"errors"
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"net/url"
	"os"
	"strings"
	"sync"
	"time"
)

const (
	apnsProductionBaseURL = "https://api.push.apple.com"
	apnsSandboxBaseURL    = "https://api.sandbox.push.apple.com"
	apnsTokenMaxAge       = 50 * time.Minute
)

type APNSClientConfig struct {
	Enabled     bool
	Environment string
	KeyID       string
	TeamID      string
	Topic       string
	AuthKeyPath string
	AuthKeyPEM  string
	BaseURL     string
	HTTPClient  *http.Client
	Logger      *slog.Logger
}

type TokenAPNSClient struct {
	keyID      string
	teamID     string
	topic      string
	baseURL    string
	privateKey *ecdsa.PrivateKey
	httpClient *http.Client
	logger     *slog.Logger
	tokenCache apnsTokenCache
}

type apnsTokenCache struct {
	mu       sync.Mutex
	token    string
	issuedAt time.Time
}

func NewAPNSClient(cfg APNSClientConfig) (APNSClient, error) {
	if !cfg.Enabled {
		return DisabledAPNSClient{}, nil
	}

	keyID := strings.TrimSpace(cfg.KeyID)
	teamID := strings.TrimSpace(cfg.TeamID)
	topic := strings.TrimSpace(cfg.Topic)
	if keyID == "" || teamID == "" || topic == "" {
		return nil, errors.New("APNS_KEY_ID, APNS_TEAM_ID, and APNS_TOPIC are required when APNS_ENABLED=true")
	}

	keyPEM := strings.TrimSpace(cfg.AuthKeyPEM)
	if keyPEM == "" && strings.TrimSpace(cfg.AuthKeyPath) != "" {
		data, err := os.ReadFile(strings.TrimSpace(cfg.AuthKeyPath))
		if err != nil {
			return nil, fmt.Errorf("read APNS auth key: %w", err)
		}
		keyPEM = string(data)
	}
	if keyPEM == "" {
		return nil, errors.New("APNS_AUTH_KEY or APNS_AUTH_KEY_PATH is required when APNS_ENABLED=true")
	}

	privateKey, err := parseAPNSPrivateKey(keyPEM)
	if err != nil {
		return nil, err
	}

	httpClient := cfg.HTTPClient
	if httpClient == nil {
		httpClient = &http.Client{Timeout: 10 * time.Second}
	}

	return &TokenAPNSClient{
		keyID:      keyID,
		teamID:     teamID,
		topic:      topic,
		baseURL:    apnsBaseURL(cfg),
		privateKey: privateKey,
		httpClient: httpClient,
		logger:     cfg.Logger,
	}, nil
}

func (c *TokenAPNSClient) Send(ctx context.Context, message APNSMessage) error {
	deviceToken := strings.TrimSpace(message.DeviceToken)
	if deviceToken == "" {
		return errors.New("apns device token is required")
	}

	token, err := c.bearerToken(time.Now)
	if err != nil {
		return err
	}

	payload, err := json.Marshal(apnsPayload(message))
	if err != nil {
		return fmt.Errorf("marshal apns payload: %w", err)
	}

	endpoint, err := url.JoinPath(c.baseURL, "3", "device", deviceToken)
	if err != nil {
		return fmt.Errorf("build apns endpoint: %w", err)
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, endpoint, bytes.NewReader(payload))
	if err != nil {
		return err
	}
	req.Header.Set("Authorization", "bearer "+token)
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("apns-topic", firstNonEmpty(message.Topic, c.topic))
	req.Header.Set("apns-push-type", "alert")
	req.Header.Set("apns-priority", "10")
	if strings.TrimSpace(message.IntentID) != "" {
		req.Header.Set("apns-collapse-id", strings.TrimSpace(message.IntentID))
	}

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return fmt.Errorf("send apns request: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 200 && resp.StatusCode < 300 {
		return nil
	}

	body, _ := io.ReadAll(io.LimitReader(resp.Body, 4096))
	return fmt.Errorf("apns send failed: status=%d body=%s", resp.StatusCode, strings.TrimSpace(string(body)))
}

func (c *TokenAPNSClient) bearerToken(now func() time.Time) (string, error) {
	c.tokenCache.mu.Lock()
	defer c.tokenCache.mu.Unlock()

	current := now().UTC()
	if c.tokenCache.token != "" && current.Sub(c.tokenCache.issuedAt) < apnsTokenMaxAge {
		return c.tokenCache.token, nil
	}

	header, err := json.Marshal(map[string]string{
		"alg": "ES256",
		"kid": c.keyID,
	})
	if err != nil {
		return "", err
	}
	claims, err := json.Marshal(map[string]any{
		"iss": c.teamID,
		"iat": current.Unix(),
	})
	if err != nil {
		return "", err
	}

	encodedHeader := base64.RawURLEncoding.EncodeToString(header)
	encodedClaims := base64.RawURLEncoding.EncodeToString(claims)
	signingInput := encodedHeader + "." + encodedClaims
	digest := sha256.Sum256([]byte(signingInput))

	r, s, err := ecdsa.Sign(rand.Reader, c.privateKey, digest[:])
	if err != nil {
		return "", fmt.Errorf("sign apns token: %w", err)
	}
	signature := make([]byte, 64)
	r.FillBytes(signature[:32])
	s.FillBytes(signature[32:])

	c.tokenCache.token = signingInput + "." + base64.RawURLEncoding.EncodeToString(signature)
	c.tokenCache.issuedAt = current
	return c.tokenCache.token, nil
}

func parseAPNSPrivateKey(raw string) (*ecdsa.PrivateKey, error) {
	normalized := strings.ReplaceAll(strings.TrimSpace(raw), `\n`, "\n")
	block, _ := pem.Decode([]byte(normalized))
	if block == nil {
		return nil, errors.New("APNS auth key must be PEM encoded")
	}

	key, err := x509.ParsePKCS8PrivateKey(block.Bytes)
	if err == nil {
		privateKey, ok := key.(*ecdsa.PrivateKey)
		if !ok {
			return nil, errors.New("APNS auth key must be an ECDSA private key")
		}
		return privateKey, nil
	}

	privateKey, ecErr := x509.ParseECPrivateKey(block.Bytes)
	if ecErr == nil {
		return privateKey, nil
	}
	return nil, fmt.Errorf("parse APNS private key: %w", err)
}

func apnsBaseURL(cfg APNSClientConfig) string {
	if trimmed := strings.TrimSpace(cfg.BaseURL); trimmed != "" {
		return strings.TrimRight(trimmed, "/")
	}
	switch strings.ToLower(strings.TrimSpace(cfg.Environment)) {
	case "production", "prod":
		return apnsProductionBaseURL
	default:
		return apnsSandboxBaseURL
	}
}

func apnsPayload(message APNSMessage) map[string]any {
	moryPayload := NormalizeDeliveryPayload(DeliveryIntent{
		IntentID:     message.IntentID,
		Kind:         message.Kind,
		Title:        message.Title,
		Body:         message.Body,
		TargetType:   message.TargetType,
		TargetID:     message.TargetID,
		PrivacyLevel: message.PrivacyLevel,
		DeepLink:     message.DeepLink,
		Payload:      message.Payload,
		ScheduledAt:  time.Now().UTC(),
	})

	return map[string]any{
		"aps": map[string]any{
			"alert": map[string]string{
				"title": message.Title,
				"body":  message.Body,
			},
			"sound":    "default",
			"category": "mory.notification.intent",
		},
		"mory_notification_intent_id":   message.IntentID,
		"mory_notification_kind":        message.Kind,
		"mory_notification_target_type": message.TargetType,
		"mory_notification_target_id":   message.TargetID,
		"mory":                          moryPayload,
	}
}

func firstNonEmpty(values ...string) string {
	for _, value := range values {
		if trimmed := strings.TrimSpace(value); trimmed != "" {
			return trimmed
		}
	}
	return ""
}

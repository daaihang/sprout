package notification

import (
	"context"
	"crypto/ecdsa"
	"crypto/elliptic"
	"crypto/rand"
	"crypto/x509"
	"encoding/json"
	"encoding/pem"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func TestTokenAPNSClientSendsProductionPayload(t *testing.T) {
	privateKey, err := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
	if err != nil {
		t.Fatalf("generate key: %v", err)
	}
	der, err := x509.MarshalPKCS8PrivateKey(privateKey)
	if err != nil {
		t.Fatalf("marshal key: %v", err)
	}
	keyPEM := string(pem.EncodeToMemory(&pem.Block{Type: "PRIVATE KEY", Bytes: der}))

	var capturedPath string
	var capturedAuth string
	var capturedTopic string
	var capturedPayload map[string]any
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		capturedPath = r.URL.Path
		capturedAuth = r.Header.Get("Authorization")
		capturedTopic = r.Header.Get("apns-topic")
		if err := json.NewDecoder(r.Body).Decode(&capturedPayload); err != nil {
			t.Fatalf("decode payload: %v", err)
		}
		w.WriteHeader(http.StatusOK)
	}))
	defer server.Close()

	client, err := NewAPNSClient(APNSClientConfig{
		Enabled:    true,
		KeyID:      "KEY123",
		TeamID:     "TEAM123",
		Topic:      "com.speculolabs.mory",
		AuthKeyPEM: keyPEM,
		BaseURL:    server.URL,
		HTTPClient: server.Client(),
	})
	if err != nil {
		t.Fatalf("new client: %v", err)
	}

	err = client.Send(context.Background(), APNSMessage{
		DeviceToken:  "device-token",
		Title:        "Mory",
		Body:         "A decision is ready.",
		IntentID:     "intent-1",
		Kind:         "analysisReady",
		TargetType:   "decision",
		TargetID:     "decision-1",
		PrivacyLevel: "contextual",
		DeepLink:     "mory://insights/decision/decision-1",
		Payload: DeliveryPayload{
			SchemaVersion: 1,
			Target: DeliveryTarget{
				Type:       "decision",
				ID:         "decision-1",
				EntityKind: "decision",
				Label:      "Reduce scope",
			},
		},
	})
	if err != nil {
		t.Fatalf("send: %v", err)
	}

	if capturedPath != "/3/device/device-token" {
		t.Fatalf("unexpected path: %s", capturedPath)
	}
	if !strings.HasPrefix(capturedAuth, "bearer ") {
		t.Fatalf("expected bearer auth header, got %q", capturedAuth)
	}
	if capturedTopic != "com.speculolabs.mory" {
		t.Fatalf("unexpected topic: %s", capturedTopic)
	}
	if capturedPayload["mory_notification_target_type"] != "decision" {
		t.Fatalf("expected flat target type for iOS userInfo, got %+v", capturedPayload)
	}

	moryPayload, ok := capturedPayload["mory"].(map[string]any)
	if !ok {
		t.Fatalf("missing mory payload: %+v", capturedPayload)
	}
	target, ok := moryPayload["target"].(map[string]any)
	if !ok || target["type"] != "decision" || target["label"] != "Reduce scope" {
		t.Fatalf("unexpected target payload: %+v", moryPayload["target"])
	}
}

func TestNewAPNSClientRequiresCredentialsWhenEnabled(t *testing.T) {
	_, err := NewAPNSClient(APNSClientConfig{Enabled: true})
	if err == nil {
		t.Fatal("expected credential error")
	}
}

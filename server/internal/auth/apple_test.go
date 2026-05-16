package auth

import (
	"context"
	"crypto"
	"crypto/rand"
	"crypto/rsa"
	"crypto/sha256"
	"encoding/base64"
	"encoding/json"
	"math/big"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"
)

func TestVerifyIdentityTokenRS256(t *testing.T) {
	privateKey, err := rsa.GenerateKey(rand.Reader, 2048)
	if err != nil {
		t.Fatalf("generate rsa key: %v", err)
	}

	jwks := appleJWKSet{
		Keys: []appleJWK{
			{
				Kty: "RSA",
				Kid: "test-kid",
				Use: "sig",
				Alg: "RS256",
				N:   base64.RawURLEncoding.EncodeToString(privateKey.PublicKey.N.Bytes()),
				E:   base64.RawURLEncoding.EncodeToString(big.NewInt(int64(privateKey.PublicKey.E)).Bytes()),
			},
		},
	}

	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		_ = json.NewEncoder(w).Encode(jwks)
	}))
	defer server.Close()

	verifier := &appleIdentityVerifier{
		client:    &http.Client{Timeout: 2 * time.Second},
		issuer:    "https://appleid.apple.com",
		audiences: map[string]struct{}{"com.speculolabs.mory": {}},
		jwksURL:   server.URL,
		cacheTTL:  time.Hour,
	}

	nonce := "raw-nonce"
	token := signedAppleJWT(t, privateKey, "test-kid", map[string]any{
		"iss":   "https://appleid.apple.com",
		"aud":   "com.speculolabs.mory",
		"exp":   time.Now().UTC().Add(time.Hour).Unix(),
		"iat":   time.Now().UTC().Unix(),
		"sub":   "apple-user-1",
		"email": "user@example.com",
		"nonce": sha256Hex(nonce),
	})

	identity, err := verifier.VerifyIdentityToken(context.Background(), token, nonce)
	if err != nil {
		t.Fatalf("verify identity token: %v", err)
	}
	if identity.Subject != "apple-user-1" {
		t.Fatalf("subject = %q", identity.Subject)
	}
	if identity.Audience != "com.speculolabs.mory" {
		t.Fatalf("audience = %q", identity.Audience)
	}
}

func signedAppleJWT(t *testing.T, privateKey *rsa.PrivateKey, kid string, claims map[string]any) string {
	t.Helper()

	header := map[string]any{
		"alg": "RS256",
		"kid": kid,
		"typ": "JWT",
	}
	headerJSON, err := json.Marshal(header)
	if err != nil {
		t.Fatalf("marshal header: %v", err)
	}
	claimsJSON, err := json.Marshal(claims)
	if err != nil {
		t.Fatalf("marshal claims: %v", err)
	}

	unsigned := base64.RawURLEncoding.EncodeToString(headerJSON) + "." + base64.RawURLEncoding.EncodeToString(claimsJSON)
	sum := sha256.Sum256([]byte(unsigned))
	signature, err := rsa.SignPKCS1v15(rand.Reader, privateKey, crypto.SHA256, sum[:])
	if err != nil {
		t.Fatalf("sign token: %v", err)
	}
	return unsigned + "." + base64.RawURLEncoding.EncodeToString(signature)
}

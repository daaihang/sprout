package auth

import (
	"context"
	"crypto/ecdsa"
	"crypto/elliptic"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log/slog"
	"math/big"
	"net/http"
	"strings"
	"sync"
	"time"

	"sprout/server/internal/config"
)

var (
	ErrAppleIdentityTokenInvalid = errors.New("invalid apple identity token")
	ErrAppleNonceMismatch        = errors.New("apple nonce mismatch")
)

type AppleIdentity struct {
	Subject  string
	Email    string
	Audience string
	Nonce    string
}

type AppleIdentityVerifier interface {
	VerifyIdentityToken(ctx context.Context, identityToken, expectedNonce string) (AppleIdentity, error)
}

type appleIdentityVerifier struct {
	client    *http.Client
	logger    *slog.Logger
	issuer    string
	audiences map[string]struct{}
	jwksURL   string
	cacheTTL  time.Duration

	mu         sync.RWMutex
	cachedKeys map[string]ecdsa.PublicKey
	cacheUntil time.Time
}

type appleJWKSet struct {
	Keys []appleJWK `json:"keys"`
}

type appleJWK struct {
	Kty string `json:"kty"`
	Kid string `json:"kid"`
	Use string `json:"use"`
	Alg string `json:"alg"`
	Crv string `json:"crv"`
	X   string `json:"x"`
	Y   string `json:"y"`
}

type appleTokenHeader struct {
	Alg string `json:"alg"`
	Kid string `json:"kid"`
	Typ string `json:"typ"`
}

type appleTokenClaims struct {
	Iss   string `json:"iss"`
	Aud   any    `json:"aud"`
	Exp   int64  `json:"exp"`
	Iat   int64  `json:"iat"`
	Sub   string `json:"sub"`
	Email string `json:"email"`
	Nonce string `json:"nonce"`
}

func NewAppleIdentityVerifier(cfg config.Config, logger *slog.Logger) AppleIdentityVerifier {
	audiences := make(map[string]struct{}, len(cfg.AppleAudiences))
	for _, aud := range cfg.AppleAudiences {
		audiences[aud] = struct{}{}
	}

	return &appleIdentityVerifier{
		client:    &http.Client{Timeout: cfg.AppleHTTPTimeout},
		logger:    logger,
		issuer:    cfg.AppleIssuer,
		audiences: audiences,
		jwksURL:   cfg.AppleJWKSURL,
		cacheTTL:  cfg.AppleJWKSTTL,
	}
}

func (v *appleIdentityVerifier) VerifyIdentityToken(ctx context.Context, identityToken, expectedNonce string) (AppleIdentity, error) {
	parts := strings.Split(identityToken, ".")
	if len(parts) != 3 {
		return AppleIdentity{}, ErrAppleIdentityTokenInvalid
	}

	var header appleTokenHeader
	if err := decodeJWTPart(parts[0], &header); err != nil {
		return AppleIdentity{}, ErrAppleIdentityTokenInvalid
	}
	if header.Alg != "ES256" || header.Kid == "" {
		return AppleIdentity{}, ErrAppleIdentityTokenInvalid
	}

	var claims appleTokenClaims
	if err := decodeJWTPart(parts[1], &claims); err != nil {
		return AppleIdentity{}, ErrAppleIdentityTokenInvalid
	}
	if claims.Iss != v.issuer || claims.Sub == "" {
		return AppleIdentity{}, ErrAppleIdentityTokenInvalid
	}
	if time.Now().UTC().Unix() >= claims.Exp {
		return AppleIdentity{}, ErrExpiredToken
	}

	audience, ok := extractAudience(claims.Aud, v.audiences)
	if !ok {
		return AppleIdentity{}, ErrAppleIdentityTokenInvalid
	}
	if expectedNonce != "" && claims.Nonce != sha256Hex(expectedNonce) {
		return AppleIdentity{}, ErrAppleNonceMismatch
	}

	publicKey, err := v.publicKey(ctx, header.Kid)
	if err != nil {
		return AppleIdentity{}, err
	}

	if err := verifyES256(parts[0]+"."+parts[1], parts[2], publicKey); err != nil {
		return AppleIdentity{}, ErrAppleIdentityTokenInvalid
	}

	return AppleIdentity{
		Subject:  claims.Sub,
		Email:    claims.Email,
		Audience: audience,
		Nonce:    claims.Nonce,
	}, nil
}

func (v *appleIdentityVerifier) publicKey(ctx context.Context, kid string) (ecdsa.PublicKey, error) {
	v.mu.RLock()
	if key, ok := v.cachedKeys[kid]; ok && time.Now().UTC().Before(v.cacheUntil) {
		v.mu.RUnlock()
		return key, nil
	}
	v.mu.RUnlock()

	v.mu.Lock()
	defer v.mu.Unlock()
	if key, ok := v.cachedKeys[kid]; ok && time.Now().UTC().Before(v.cacheUntil) {
		return key, nil
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodGet, v.jwksURL, nil)
	if err != nil {
		return ecdsa.PublicKey{}, fmt.Errorf("create apple jwks request: %w", err)
	}

	resp, err := doRequestWithRetry(ctx, v.client, req, 1, 250*time.Millisecond)
	if err != nil {
		return ecdsa.PublicKey{}, fmt.Errorf("fetch apple jwks: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 300 {
		return ecdsa.PublicKey{}, fmt.Errorf("apple jwks status %d", resp.StatusCode)
	}

	body, err := io.ReadAll(io.LimitReader(resp.Body, 1<<20))
	if err != nil {
		return ecdsa.PublicKey{}, fmt.Errorf("read apple jwks: %w", err)
	}

	var jwks appleJWKSet
	if err := json.Unmarshal(body, &jwks); err != nil {
		return ecdsa.PublicKey{}, fmt.Errorf("decode apple jwks: %w", err)
	}

	keys := make(map[string]ecdsa.PublicKey, len(jwks.Keys))
	for _, key := range jwks.Keys {
		publicKey, err := jwkToECDSA(key)
		if err != nil {
			continue
		}
		keys[key.Kid] = publicKey
	}
	if len(keys) == 0 {
		return ecdsa.PublicKey{}, fmt.Errorf("apple jwks contained no usable keys")
	}

	v.cachedKeys = keys
	v.cacheUntil = time.Now().UTC().Add(v.cacheTTL)

	key, ok := v.cachedKeys[kid]
	if !ok {
		return ecdsa.PublicKey{}, ErrAppleIdentityTokenInvalid
	}
	return key, nil
}

func decodeJWTPart[T any](encoded string, out *T) error {
	decoded, err := base64.RawURLEncoding.DecodeString(encoded)
	if err != nil {
		return err
	}
	return json.Unmarshal(decoded, out)
}

func extractAudience(aud any, allowed map[string]struct{}) (string, bool) {
	switch value := aud.(type) {
	case string:
		_, ok := allowed[value]
		return value, ok
	case []any:
		for _, item := range value {
			aud, ok := item.(string)
			if !ok {
				continue
			}
			if _, allowed := allowed[aud]; allowed {
				return aud, true
			}
		}
	}
	return "", false
}

func verifyES256(unsignedToken, encodedSignature string, publicKey ecdsa.PublicKey) error {
	signature, err := base64.RawURLEncoding.DecodeString(encodedSignature)
	if err != nil {
		return err
	}
	if len(signature) != 64 {
		return ErrAppleIdentityTokenInvalid
	}

	sum := sha256.Sum256([]byte(unsignedToken))
	r := new(big.Int).SetBytes(signature[:32])
	s := new(big.Int).SetBytes(signature[32:])
	if !ecdsa.Verify(&publicKey, sum[:], r, s) {
		return ErrAppleIdentityTokenInvalid
	}
	return nil
}

func jwkToECDSA(jwk appleJWK) (ecdsa.PublicKey, error) {
	if jwk.Kty != "EC" || jwk.Crv != "P-256" || jwk.X == "" || jwk.Y == "" {
		return ecdsa.PublicKey{}, ErrAppleIdentityTokenInvalid
	}
	xBytes, err := base64.RawURLEncoding.DecodeString(jwk.X)
	if err != nil {
		return ecdsa.PublicKey{}, err
	}
	yBytes, err := base64.RawURLEncoding.DecodeString(jwk.Y)
	if err != nil {
		return ecdsa.PublicKey{}, err
	}

	publicKey := ecdsa.PublicKey{
		Curve: elliptic.P256(),
		X:     new(big.Int).SetBytes(xBytes),
		Y:     new(big.Int).SetBytes(yBytes),
	}
	if !publicKey.Curve.IsOnCurve(publicKey.X, publicKey.Y) {
		return ecdsa.PublicKey{}, ErrAppleIdentityTokenInvalid
	}
	return publicKey, nil
}

func sha256Hex(value string) string {
	sum := sha256.Sum256([]byte(value))
	return hex.EncodeToString(sum[:])
}

func doRequestWithRetry(ctx context.Context, client *http.Client, req *http.Request, maxRetries int, backoff time.Duration) (*http.Response, error) {
	var lastErr error
	for attempt := 0; attempt <= maxRetries; attempt++ {
		cloned := req.Clone(ctx)
		resp, err := client.Do(cloned)
		if err == nil && resp.StatusCode < 500 && resp.StatusCode != http.StatusTooManyRequests {
			return resp, nil
		}
		if resp != nil && err == nil {
			lastErr = fmt.Errorf("status %d", resp.StatusCode)
			resp.Body.Close()
		} else {
			lastErr = err
		}
		if attempt == maxRetries {
			break
		}
		select {
		case <-ctx.Done():
			return nil, ctx.Err()
		case <-time.After(backoff * time.Duration(attempt+1)):
		}
	}
	return nil, lastErr
}

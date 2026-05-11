package auth

import (
	"context"
	"crypto/hmac"
	"crypto/sha256"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"strings"
	"time"
)

var (
	ErrInvalidToken = errors.New("invalid token")
	ErrExpiredToken = errors.New("expired token")
)

type Claims struct {
	UserID string `json:"user_id"`
	Tier   string `json:"tier"`
	Issuer string `json:"iss"`
	Issued int64  `json:"iat"`
	Expiry int64  `json:"exp"`
}

type Authenticator struct {
	secret []byte
	issuer string
	ttl    time.Duration
}

func NewAuthenticator(secret, issuer string, ttl time.Duration) *Authenticator {
	return &Authenticator{
		secret: []byte(secret),
		issuer: issuer,
		ttl:    ttl,
	}
}

func (a *Authenticator) IssueToken(userID, tier string) (string, Claims, error) {
	now := time.Now().UTC()
	claims := Claims{
		UserID: userID,
		Tier:   tier,
		Issuer: a.issuer,
		Issued: now.Unix(),
		Expiry: now.Add(a.ttl).Unix(),
	}

	token, err := a.sign(claims)
	if err != nil {
		return "", Claims{}, err
	}

	return token, claims, nil
}

func (a *Authenticator) RefreshToken(claims Claims) (string, Claims, error) {
	return a.IssueToken(claims.UserID, claims.Tier)
}

func (a *Authenticator) ValidateToken(token string) (Claims, error) {
	parts := strings.Split(token, ".")
	if len(parts) != 3 {
		return Claims{}, ErrInvalidToken
	}

	unsigned := parts[0] + "." + parts[1]
	expected := a.signature(unsigned)
	if !hmac.Equal([]byte(expected), []byte(parts[2])) {
		return Claims{}, ErrInvalidToken
	}

	payload, err := base64.RawURLEncoding.DecodeString(parts[1])
	if err != nil {
		return Claims{}, ErrInvalidToken
	}

	var claims Claims
	if err := json.Unmarshal(payload, &claims); err != nil {
		return Claims{}, ErrInvalidToken
	}
	if claims.UserID == "" || claims.Issuer != a.issuer {
		return Claims{}, ErrInvalidToken
	}
	if time.Now().UTC().Unix() >= claims.Expiry {
		return Claims{}, ErrExpiredToken
	}
	return claims, nil
}

func (a *Authenticator) sign(claims Claims) (string, error) {
	header, err := json.Marshal(map[string]string{
		"alg": "HS256",
		"typ": "JWT",
	})
	if err != nil {
		return "", fmt.Errorf("marshal jwt header: %w", err)
	}

	payload, err := json.Marshal(claims)
	if err != nil {
		return "", fmt.Errorf("marshal jwt claims: %w", err)
	}

	unsigned := base64.RawURLEncoding.EncodeToString(header) + "." + base64.RawURLEncoding.EncodeToString(payload)
	return unsigned + "." + a.signature(unsigned), nil
}

func (a *Authenticator) signature(unsigned string) string {
	mac := hmac.New(sha256.New, a.secret)
	_, _ = mac.Write([]byte(unsigned))
	return base64.RawURLEncoding.EncodeToString(mac.Sum(nil))
}

type contextKey string

const claimsContextKey contextKey = "auth_claims"

func ContextWithClaims(ctx context.Context, claims Claims) context.Context {
	return context.WithValue(ctx, claimsContextKey, claims)
}

func ClaimsFromContext(ctx context.Context) (Claims, bool) {
	claims, ok := ctx.Value(claimsContextKey).(Claims)
	return claims, ok
}

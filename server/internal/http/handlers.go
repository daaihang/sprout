package http

import (
	"encoding/json"
	"errors"
	"net/http"
	"strings"
	"time"

	"sprout/server/internal/ai"
	"sprout/server/internal/auth"
	"sprout/server/internal/db"
)

type authAppleRequest struct {
	IdentityToken string `json:"identity_token"`
	Nonce         string `json:"nonce"`
}

type authResponse struct {
	AccessToken string   `json:"access_token"`
	ExpiresAt   string   `json:"expires_at"`
	User        authUser `json:"user"`
	Mode        string   `json:"mode"`
}

type authUser struct {
	ID   string `json:"id"`
	Tier string `json:"tier"`
}

type pushRegisterRequest struct {
	DeviceID         string `json:"device_id"`
	APNSToken        string `json:"apns_token"`
	Timezone         string `json:"timezone"`
	HasQuestionReady bool   `json:"has_question_ready"`
}

type pushRegisterResponse struct {
	Registered bool   `json:"registered"`
	UserID     string `json:"user_id"`
}

type analyzeResponseEnvelope struct {
	ai.AnalyzeResponse
	Meta analyzeMeta `json:"meta"`
}

type analyzeMeta struct {
	Provider string   `json:"provider"`
	Model    string   `json:"model"`
	Usage    ai.Usage `json:"usage"`
}

func (s *Server) handleHealthz(w http.ResponseWriter, _ *http.Request) {
	writeJSON(w, http.StatusOK, map[string]string{
		"status": "ok",
	})
}

func (s *Server) handleMetrics(w http.ResponseWriter, _ *http.Request) {
	writeText(w, http.StatusOK, metricsText(s.metrics.Snapshot()))
}

func (s *Server) handleAuthApple(w http.ResponseWriter, r *http.Request) {
	var req authAppleRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid JSON body")
		return
	}

	identityToken := strings.TrimSpace(req.IdentityToken)
	var userID string
	mode := "apple"

	switch {
	case s.cfg.DevAuthEnabled && !looksLikeJWT(identityToken):
		userID = identityToken
		if userID == "" {
			userID = s.cfg.DevAuthUserID
		}
		mode = "development_stub"
	case identityToken == "":
		writeError(w, http.StatusBadRequest, "identity_token is required")
		return
	default:
		if s.appleVerifier == nil {
			writeError(w, http.StatusInternalServerError, "apple verifier is not configured")
			return
		}
		identity, err := s.appleVerifier.VerifyIdentityToken(r.Context(), identityToken, strings.TrimSpace(req.Nonce))
		if err != nil {
			switch {
			case errors.Is(err, auth.ErrExpiredToken):
				writeError(w, http.StatusUnauthorized, "apple identity token expired")
			case errors.Is(err, auth.ErrAppleNonceMismatch):
				writeError(w, http.StatusUnauthorized, "apple nonce mismatch")
			case errors.Is(err, auth.ErrAppleIssuerMismatch):
				writeError(w, http.StatusUnauthorized, "apple issuer mismatch")
			case errors.Is(err, auth.ErrAppleAudienceMismatch):
				writeError(w, http.StatusUnauthorized, "apple audience mismatch")
			case errors.Is(err, auth.ErrAppleJWKSUnavailable):
				writeError(w, http.StatusServiceUnavailable, "apple jwks unavailable")
			case errors.Is(err, auth.ErrAppleKeyNotFound):
				writeError(w, http.StatusUnauthorized, "apple jwks key not found")
			case errors.Is(err, auth.ErrAppleTokenSignatureInvalid):
				writeError(w, http.StatusUnauthorized, "apple token signature invalid")
			default:
				writeError(w, http.StatusUnauthorized, "invalid apple identity token")
			}
			return
		}
		userID = identity.Subject
	}

	status, err := s.subscription.Verify(r.Context(), userID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "failed to resolve subscription")
		return
	}

	token, claims, err := s.authenticator.IssueToken(userID, status.Tier)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "failed to issue token")
		return
	}

	writeJSON(w, http.StatusOK, authResponse{
		AccessToken: token,
		ExpiresAt:   unixToRFC3339(claims.Expiry),
		User: authUser{
			ID:   userID,
			Tier: status.Tier,
		},
		Mode: mode,
	})
}

func (s *Server) handleAuthRefresh(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.ClaimsFromContext(r.Context())
	if !ok {
		writeError(w, http.StatusUnauthorized, "missing auth claims")
		return
	}

	token, refreshed, err := s.authenticator.RefreshToken(claims)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "failed to refresh token")
		return
	}

	writeJSON(w, http.StatusOK, authResponse{
		AccessToken: token,
		ExpiresAt:   unixToRFC3339(refreshed.Expiry),
		User: authUser{
			ID:   refreshed.UserID,
			Tier: refreshed.Tier,
		},
		Mode: "jwt_refresh",
	})
}

func (s *Server) handleAnalyze(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.ClaimsFromContext(r.Context())
	if !ok {
		writeError(w, http.StatusUnauthorized, "missing auth claims")
		return
	}

	var req ai.AnalyzeRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid JSON body")
		return
	}
	if err := req.Validate(); err != nil {
		writeError(w, http.StatusBadRequest, "invalid analyze request")
		return
	}

	result, err := s.aiProvider.Analyze(r.Context(), req, ai.UserContext{
		UserID: claims.UserID,
		Tier:   claims.Tier,
	})
	if err != nil {
		if errors.Is(err, ai.ErrInvalidAnalyzeRequest) {
			writeError(w, http.StatusBadRequest, "invalid analyze request")
			return
		}
		writeError(w, http.StatusBadGateway, "analysis request failed")
		return
	}

	writeJSON(w, http.StatusOK, analyzeResponseEnvelope{
		AnalyzeResponse: result.Response,
		Meta: analyzeMeta{
			Provider: result.Provider,
			Model:    result.Model,
			Usage:    result.Usage,
		},
	})
}

func (s *Server) handleSubscriptionVerify(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.ClaimsFromContext(r.Context())
	if !ok {
		writeError(w, http.StatusUnauthorized, "missing auth claims")
		return
	}

	status, err := s.subscription.Verify(r.Context(), claims.UserID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "failed to verify subscription")
		return
	}
	writeJSON(w, http.StatusOK, status)
}

func (s *Server) handlePushRegister(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.ClaimsFromContext(r.Context())
	if !ok {
		writeError(w, http.StatusUnauthorized, "missing auth claims")
		return
	}

	var req pushRegisterRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid JSON body")
		return
	}
	if strings.TrimSpace(req.DeviceID) == "" || strings.TrimSpace(req.APNSToken) == "" || strings.TrimSpace(req.Timezone) == "" {
		writeError(w, http.StatusBadRequest, "device_id, apns_token, and timezone are required")
		return
	}

	if err := s.pushTokens.UpsertPushToken(r.Context(), db.PushToken{
		UserID:           claims.UserID,
		DeviceID:         strings.TrimSpace(req.DeviceID),
		APNSToken:        strings.TrimSpace(req.APNSToken),
		Timezone:         strings.TrimSpace(req.Timezone),
		HasQuestionReady: req.HasQuestionReady,
	}); err != nil {
		writeError(w, http.StatusInternalServerError, "failed to register push token")
		return
	}

	writeJSON(w, http.StatusOK, pushRegisterResponse{
		Registered: true,
		UserID:     claims.UserID,
	})
}

func unixToRFC3339(value int64) string {
	return time.Unix(value, 0).UTC().Format(time.RFC3339)
}

func looksLikeJWT(value string) bool {
	return strings.Count(value, ".") == 2
}

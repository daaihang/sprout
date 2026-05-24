package http

import (
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"strings"
	"time"

	"sprout/server/internal/auth"
)

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
			if s.cfg.DevAuthEnabled {
				if fallbackUserID, fallbackErr := devAppleFallbackUserID(identityToken); fallbackErr == nil {
					s.logger.Warn(
						"apple auth verification failed; using development fallback",
						"error", err.Error(),
						"user_id", fallbackUserID,
					)
					userID = fallbackUserID
					mode = "development_stub"
					break
				}
			}

			s.logger.Warn("apple auth verification failed", "error", err.Error())
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
				writeError(w, http.StatusUnauthorized, fmt.Sprintf("invalid apple identity token: %v", err))
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
	profile, isNewUser, err := s.userProfiles.GetOrCreateUserProfile(r.Context(), userID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "failed to resolve user profile")
		return
	}

	accessToken, accessClaims, refreshToken, _, err := s.authenticator.IssueToken(userID, status.Tier)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "failed to issue token")
		return
	}

	writeJSON(w, http.StatusOK, authResponse{
		AccessToken:  accessToken,
		RefreshToken: refreshToken,
		ExpiresAt:    unixToRFC3339(accessClaims.Expiry),
		User: authUser{
			ID:   userID,
			Tier: status.Tier,
		},
		Mode:                   mode,
		IsNewUser:              isNewUser,
		HasCompletedOnboarding: profile.HasCompletedOnboarding,
	})
}

func (s *Server) handleAuthRefresh(w http.ResponseWriter, r *http.Request) {
	authorization := strings.TrimSpace(r.Header.Get("Authorization"))
	if !strings.HasPrefix(authorization, "Bearer ") {
		writeError(w, http.StatusUnauthorized, "missing bearer token")
		return
	}

	refreshToken := strings.TrimSpace(strings.TrimPrefix(authorization, "Bearer "))
	refreshClaims, err := s.authenticator.ValidateRefreshToken(refreshToken)
	if err != nil {
		if errors.Is(err, auth.ErrExpiredToken) {
			writeError(w, http.StatusUnauthorized, "refresh token expired")
			return
		}
		writeError(w, http.StatusUnauthorized, "invalid refresh token")
		return
	}

	accessToken, refreshed, newRefreshToken, _, err := s.authenticator.IssueToken(refreshClaims.UserID, refreshClaims.Tier)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "failed to refresh token")
		return
	}
	profile, _, err := s.userProfiles.GetOrCreateUserProfile(r.Context(), refreshed.UserID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "failed to resolve user profile")
		return
	}

	writeJSON(w, http.StatusOK, authResponse{
		AccessToken:  accessToken,
		RefreshToken: newRefreshToken,
		ExpiresAt:    unixToRFC3339(refreshed.Expiry),
		User: authUser{
			ID:   refreshed.UserID,
			Tier: refreshed.Tier,
		},
		Mode:                   "jwt_refresh",
		IsNewUser:              false,
		HasCompletedOnboarding: profile.HasCompletedOnboarding,
	})
}
func (s *Server) handleOnboardingComplete(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.ClaimsFromContext(r.Context())
	if !ok {
		writeError(w, http.StatusUnauthorized, "missing auth claims")
		return
	}

	profile, err := s.userProfiles.MarkOnboardingComplete(r.Context(), claims.UserID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "failed to update onboarding state")
		return
	}

	writeJSON(w, http.StatusOK, onboardingCompleteResponse{
		HasCompletedOnboarding: profile.HasCompletedOnboarding,
	})
}
func unixToRFC3339(value int64) string {
	return time.Unix(value, 0).UTC().Format(time.RFC3339)
}

func looksLikeJWT(value string) bool {
	return strings.Count(value, ".") == 2
}

func devAppleFallbackUserID(identityToken string) (string, error) {
	parts := strings.Split(strings.TrimSpace(identityToken), ".")
	if len(parts) != 3 {
		return "", errors.New("identity token is not a JWT")
	}

	var claims struct {
		Iss string `json:"iss"`
		Sub string `json:"sub"`
	}
	if err := auth.DecodeAppleJWTClaimsForDevelopment(parts[1], &claims); err != nil {
		return "", err
	}
	if claims.Iss != "https://appleid.apple.com" {
		return "", errors.New("token issuer is not Apple")
	}
	if strings.TrimSpace(claims.Sub) == "" {
		return "", errors.New("token subject is empty")
	}
	return claims.Sub, nil
}

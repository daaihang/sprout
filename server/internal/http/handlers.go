package http

import (
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"strings"
	"time"

	"sprout/server/internal/ai"
	"sprout/server/internal/auth"
	"sprout/server/internal/db"
	"sprout/server/internal/notification"
)

type authAppleRequest struct {
	IdentityToken string `json:"identity_token"`
	Nonce         string `json:"nonce"`
}

type authResponse struct {
	AccessToken            string   `json:"access_token"`
	RefreshToken           string   `json:"refresh_token,omitempty"`
	ExpiresAt              string   `json:"expires_at"`
	User                   authUser `json:"user"`
	Mode                   string   `json:"mode"`
	IsNewUser              bool     `json:"is_new_user"`
	HasCompletedOnboarding bool     `json:"has_completed_onboarding"`
}

type authUser struct {
	ID   string `json:"id"`
	Tier string `json:"tier"`
}

type onboardingCompleteResponse struct {
	HasCompletedOnboarding bool `json:"has_completed_onboarding"`
}

type analyzePreviewResponseEnvelope struct {
	ai.AnalyzeResponse
	Mode string `json:"mode"`
}

type pushRegisterRequest struct {
	DeviceID                           string `json:"device_id"`
	APNSToken                          string `json:"apns_token"`
	Timezone                           string `json:"timezone"`
	HasQuestionReady                   bool   `json:"has_question_ready"`
	NotificationsEnabled               bool   `json:"notifications_enabled"`
	BackgroundDoneEnabled              bool   `json:"background_done_enabled"`
	DailyQuestionEnabled               bool   `json:"daily_question_enabled"`
	RepeatedThemeEnabled               bool   `json:"repeated_theme_enabled"`
	StageFormingEnabled                bool   `json:"stage_forming_enabled"`
	RevisitEnabled                     bool   `json:"revisit_enabled"`
	DeliveryPace                       string `json:"delivery_pace"`
	MaxPerDay                          int    `json:"max_per_day"`
	MinimumMinutesBetweenNotifications int    `json:"minimum_minutes_between_notifications"`
	QuietStart                         string `json:"quiet_start"`
	QuietEnd                           string `json:"quiet_end"`
	RichPreviewsEnabled                bool   `json:"rich_previews_enabled"`
	LocalIntelligenceEnabled           bool   `json:"local_intelligence_enabled"`
	CloudIntelligenceEnabled           bool   `json:"cloud_intelligence_enabled"`
	SemanticSearchEnabled              bool   `json:"semantic_search_enabled"`
	HomeSuggestionsEnabled             bool   `json:"home_suggestions_enabled"`
}

type pushRegisterResponse struct {
	Registered bool   `json:"registered"`
	UserID     string `json:"user_id"`
}

type pushDeliveryWritebackRequest struct {
	DeviceID   string `json:"device_id"`
	IntentID   string `json:"intent_id"`
	Action     string `json:"action"`
	Kind       string `json:"kind"`
	TargetType string `json:"target_type"`
	TargetID   string `json:"target_id"`
	OccurredAt string `json:"occurred_at"`
}

type pushDeliveryWritebackResponse struct {
	Accepted bool   `json:"accepted"`
	UserID   string `json:"user_id"`
}

type pushEnqueueRequest struct {
	IntentID     string                       `json:"intent_id"`
	Kind         string                       `json:"kind"`
	Title        string                       `json:"title"`
	Body         string                       `json:"body"`
	TargetType   string                       `json:"target_type"`
	TargetID     string                       `json:"target_id"`
	PrivacyLevel string                       `json:"privacy_level"`
	DeepLink     string                       `json:"deep_link"`
	Target       notification.DeliveryTarget  `json:"target"`
	Payload      notification.DeliveryPayload `json:"payload"`
	ScheduledAt  string                       `json:"scheduled_at"`
}

type pushEnqueueResponse struct {
	Accepted     bool   `json:"accepted"`
	UserID       string `json:"user_id"`
	QueuedCount  int    `json:"queued_count"`
	SkippedCount int    `json:"skipped_count"`
	SentCount    int    `json:"sent_count"`
	FailedCount  int    `json:"failed_count"`
}

type analyzeResponseEnvelope struct {
	ai.AnalyzeResponse
	Meta analyzeMeta `json:"meta"`
}

type analyzeMeta struct {
	Provider  string   `json:"provider"`
	Model     string   `json:"model"`
	Usage     ai.Usage `json:"usage"`
	RequestID string   `json:"request_id,omitempty"`
}

type transcriptRefinementResponseEnvelope struct {
	ai.TranscriptRefinementResponse
	Meta analyzeMeta `json:"meta"`
}

type questionSuggestionResponseEnvelope struct {
	ai.QuestionSuggestionResponse
	Meta analyzeMeta `json:"meta"`
}

type chapterSuggestionResponseEnvelope struct {
	ai.ChapterSuggestionResponse
	Meta analyzeMeta `json:"meta"`
}

type photoSemanticAnalysisResponseEnvelope struct {
	ai.PhotoSemanticAnalysisResponse
	Meta analyzeMeta `json:"meta"`
}

type notificationIntentSuggestionResponseEnvelope struct {
	ai.NotificationIntentSuggestionResponse
	Meta analyzeMeta `json:"meta"`
}

type reflectionRequest struct {
	RecordShell   ai.AnalyzeRecordShell     `json:"record_shell"`
	Artifacts     []ai.AnalyzeArtifact      `json:"artifacts"`
	LinkedArcID   string                    `json:"linked_arc_id,omitempty"`
	KnownEntities []ai.KnownEntityReference `json:"known_entities,omitempty"`
	Prompt        string                    `json:"prompt,omitempty"`
	DebugOptions  *ai.DebugOptions          `json:"debug_options,omitempty"`
}

type reflectionResponse struct {
	Title           string      `json:"title"`
	Body            string      `json:"body"`
	EvidenceSummary string      `json:"evidence_summary"`
	Confidence      float64     `json:"confidence"`
	SourceRecordIDs []string    `json:"source_record_ids"`
	Meta            analyzeMeta `json:"meta"`
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

func (s *Server) handleAnalyzePreview(w http.ResponseWriter, r *http.Request) {
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
		UserID: "preview",
		Tier:   "preview",
	})
	if err != nil {
		if errors.Is(err, ai.ErrInvalidAnalyzeRequest) {
			writeError(w, http.StatusBadRequest, "invalid analyze request")
			return
		}
		writeError(w, http.StatusBadGateway, fmt.Sprintf("analysis request failed: %v", err))
		return
	}

	writeJSON(w, http.StatusOK, analyzePreviewResponseEnvelope{
		AnalyzeResponse: result.Response,
		Mode:            "preview",
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
		writeError(w, http.StatusBadGateway, fmt.Sprintf("analysis request failed: %v", err))
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

func (s *Server) handleReflectionGenerate(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.ClaimsFromContext(r.Context())
	if !ok {
		writeError(w, http.StatusUnauthorized, "missing auth claims")
		return
	}

	var req reflectionRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid JSON body")
		return
	}

	providerReq := ai.ReflectionRequest(req)
	if err := providerReq.ValidateGenerate(); err != nil {
		writeError(w, http.StatusBadRequest, "invalid reflection generate request")
		return
	}

	result, err := s.aiProvider.GenerateReflection(r.Context(), providerReq, ai.UserContext{
		UserID: claims.UserID,
		Tier:   claims.Tier,
	})
	if err != nil {
		if errors.Is(err, ai.ErrInvalidAnalyzeRequest) {
			writeError(w, http.StatusBadRequest, "invalid reflection generate request")
			return
		}
		writeError(w, http.StatusBadGateway, fmt.Sprintf("reflection generate failed: %v", err))
		return
	}

	writeJSON(w, http.StatusOK, reflectionResponse{
		Title:           result.Response.Title,
		Body:            result.Response.Body,
		EvidenceSummary: result.Response.EvidenceSummary,
		Confidence:      result.Response.Confidence,
		SourceRecordIDs: result.Response.SourceRecordIDs,
		Meta: analyzeMeta{
			Provider: result.Provider,
			Model:    result.Model,
			Usage:    result.Usage,
		},
	})
}

func (s *Server) handleReflectionReplay(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.ClaimsFromContext(r.Context())
	if !ok {
		writeError(w, http.StatusUnauthorized, "missing auth claims")
		return
	}

	var req reflectionRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid JSON body")
		return
	}

	providerReq := ai.ReflectionRequest(req)
	if err := providerReq.ValidateReplay(); err != nil {
		writeError(w, http.StatusBadRequest, "invalid reflection replay request")
		return
	}

	result, err := s.aiProvider.ReplayReflection(r.Context(), providerReq, ai.UserContext{
		UserID: claims.UserID,
		Tier:   claims.Tier,
	})
	if err != nil {
		if errors.Is(err, ai.ErrInvalidAnalyzeRequest) {
			writeError(w, http.StatusBadRequest, "invalid reflection replay request")
			return
		}
		writeError(w, http.StatusBadGateway, fmt.Sprintf("reflection replay failed: %v", err))
		return
	}

	writeJSON(w, http.StatusOK, reflectionResponse{
		Title:           result.Response.Title,
		Body:            result.Response.Body,
		EvidenceSummary: result.Response.EvidenceSummary,
		Confidence:      result.Response.Confidence,
		SourceRecordIDs: result.Response.SourceRecordIDs,
		Meta: analyzeMeta{
			Provider: result.Provider,
			Model:    result.Model,
			Usage:    result.Usage,
		},
	})
}

func (s *Server) handleTranscriptRefinement(w http.ResponseWriter, r *http.Request) {
	user, ok := userContextFromRequest(w, r)
	if !ok {
		return
	}

	var req ai.TranscriptRefinementRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid JSON body")
		return
	}
	if err := req.Validate(); err != nil {
		writeError(w, http.StatusBadRequest, "invalid transcript refinement request")
		return
	}

	result, err := s.aiProvider.RefineTranscript(r.Context(), req, user)
	if err != nil {
		if errors.Is(err, ai.ErrInvalidAnalyzeRequest) {
			writeError(w, http.StatusBadRequest, "invalid transcript refinement request")
			return
		}
		writeError(w, http.StatusBadGateway, fmt.Sprintf("transcript refinement failed: %v", err))
		return
	}

	writeJSON(w, http.StatusOK, transcriptRefinementResponseEnvelope{
		TranscriptRefinementResponse: result.Response,
		Meta:                         s.metaForResult(r, result.Provider, result.Model, result.Usage),
	})
}

func (s *Server) handleQuestionSuggestions(w http.ResponseWriter, r *http.Request) {
	user, ok := userContextFromRequest(w, r)
	if !ok {
		return
	}

	var req ai.QuestionSuggestionRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid JSON body")
		return
	}
	if err := req.Validate(); err != nil {
		writeError(w, http.StatusBadRequest, "invalid question suggestion request")
		return
	}

	result, err := s.aiProvider.SuggestQuestions(r.Context(), req, user)
	if err != nil {
		if errors.Is(err, ai.ErrInvalidAnalyzeRequest) {
			writeError(w, http.StatusBadRequest, "invalid question suggestion request")
			return
		}
		writeError(w, http.StatusBadGateway, fmt.Sprintf("question suggestion failed: %v", err))
		return
	}

	writeJSON(w, http.StatusOK, questionSuggestionResponseEnvelope{
		QuestionSuggestionResponse: result.Response,
		Meta:                       s.metaForResult(r, result.Provider, result.Model, result.Usage),
	})
}

func (s *Server) handleChapterSuggestions(w http.ResponseWriter, r *http.Request) {
	user, ok := userContextFromRequest(w, r)
	if !ok {
		return
	}

	var req ai.ChapterSuggestionRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid JSON body")
		return
	}
	if err := req.Validate(); err != nil {
		writeError(w, http.StatusBadRequest, "invalid chapter suggestion request")
		return
	}

	result, err := s.aiProvider.SuggestChapters(r.Context(), req, user)
	if err != nil {
		if errors.Is(err, ai.ErrInvalidAnalyzeRequest) {
			writeError(w, http.StatusBadRequest, "invalid chapter suggestion request")
			return
		}
		writeError(w, http.StatusBadGateway, fmt.Sprintf("chapter suggestion failed: %v", err))
		return
	}

	writeJSON(w, http.StatusOK, chapterSuggestionResponseEnvelope{
		ChapterSuggestionResponse: result.Response,
		Meta:                      s.metaForResult(r, result.Provider, result.Model, result.Usage),
	})
}

func (s *Server) handlePhotoSemanticAnalysis(w http.ResponseWriter, r *http.Request) {
	user, ok := userContextFromRequest(w, r)
	if !ok {
		return
	}

	var req ai.PhotoSemanticAnalysisRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid JSON body")
		return
	}
	if err := req.Validate(); err != nil {
		writeError(w, http.StatusBadRequest, "invalid photo semantic analysis request")
		return
	}

	result, err := s.aiProvider.AnalyzePhotoSemantics(r.Context(), req, user)
	if err != nil {
		if errors.Is(err, ai.ErrInvalidAnalyzeRequest) {
			writeError(w, http.StatusBadRequest, "invalid photo semantic analysis request")
			return
		}
		writeError(w, http.StatusBadGateway, fmt.Sprintf("photo semantic analysis failed: %v", err))
		return
	}

	writeJSON(w, http.StatusOK, photoSemanticAnalysisResponseEnvelope{
		PhotoSemanticAnalysisResponse: result.Response,
		Meta:                          s.metaForResult(r, result.Provider, result.Model, result.Usage),
	})
}

func (s *Server) handleNotificationIntentSuggestion(w http.ResponseWriter, r *http.Request) {
	user, ok := userContextFromRequest(w, r)
	if !ok {
		return
	}

	var req ai.NotificationIntentSuggestionRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid JSON body")
		return
	}
	if err := req.Validate(); err != nil {
		writeError(w, http.StatusBadRequest, "invalid notification intent suggestion request")
		return
	}

	result, err := s.aiProvider.SuggestNotificationIntent(r.Context(), req, user)
	if err != nil {
		if errors.Is(err, ai.ErrInvalidAnalyzeRequest) {
			writeError(w, http.StatusBadRequest, "invalid notification intent suggestion request")
			return
		}
		writeError(w, http.StatusBadGateway, fmt.Sprintf("notification intent suggestion failed: %v", err))
		return
	}

	writeJSON(w, http.StatusOK, notificationIntentSuggestionResponseEnvelope{
		NotificationIntentSuggestionResponse: result.Response,
		Meta:                                 s.metaForResult(r, result.Provider, result.Model, result.Usage),
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

func userContextFromRequest(w http.ResponseWriter, r *http.Request) (ai.UserContext, bool) {
	claims, ok := auth.ClaimsFromContext(r.Context())
	if !ok {
		writeError(w, http.StatusUnauthorized, "missing auth claims")
		return ai.UserContext{}, false
	}
	return ai.UserContext{
		UserID: claims.UserID,
		Tier:   claims.Tier,
	}, true
}

func (s *Server) metaForResult(r *http.Request, provider string, model string, usage ai.Usage) analyzeMeta {
	return analyzeMeta{
		Provider:  provider,
		Model:     model,
		Usage:     usage,
		RequestID: requestIDFromContext(r.Context()),
	}
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
		UserID:                             claims.UserID,
		DeviceID:                           strings.TrimSpace(req.DeviceID),
		APNSToken:                          strings.TrimSpace(req.APNSToken),
		Timezone:                           strings.TrimSpace(req.Timezone),
		HasQuestionReady:                   req.HasQuestionReady,
		NotificationsEnabled:               req.NotificationsEnabled,
		BackgroundDoneEnabled:              req.BackgroundDoneEnabled,
		DailyQuestionEnabled:               req.DailyQuestionEnabled,
		RepeatedThemeEnabled:               req.RepeatedThemeEnabled,
		StageFormingEnabled:                req.StageFormingEnabled,
		RevisitEnabled:                     req.RevisitEnabled,
		DeliveryPace:                       strings.TrimSpace(req.DeliveryPace),
		MaxPerDay:                          req.MaxPerDay,
		MinimumMinutesBetweenNotifications: req.MinimumMinutesBetweenNotifications,
		QuietStart:                         strings.TrimSpace(req.QuietStart),
		QuietEnd:                           strings.TrimSpace(req.QuietEnd),
		RichPreviewsEnabled:                req.RichPreviewsEnabled,
		LocalIntelligenceEnabled:           req.LocalIntelligenceEnabled,
		CloudIntelligenceEnabled:           req.CloudIntelligenceEnabled,
		SemanticSearchEnabled:              req.SemanticSearchEnabled,
		HomeSuggestionsEnabled:             req.HomeSuggestionsEnabled,
	}); err != nil {
		writeError(w, http.StatusInternalServerError, "failed to register push token")
		return
	}

	writeJSON(w, http.StatusOK, pushRegisterResponse{
		Registered: true,
		UserID:     claims.UserID,
	})
}

func (s *Server) handlePushEnqueue(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.ClaimsFromContext(r.Context())
	if !ok {
		writeError(w, http.StatusUnauthorized, "missing auth claims")
		return
	}
	if s.pushDeliveryWorker == nil {
		writeError(w, http.StatusInternalServerError, "push delivery worker is not configured")
		return
	}

	var req pushEnqueueRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid JSON body")
		return
	}

	intentID := strings.TrimSpace(req.IntentID)
	kind := strings.TrimSpace(req.Kind)
	title := strings.TrimSpace(req.Title)
	body := strings.TrimSpace(req.Body)
	targetType := strings.TrimSpace(req.TargetType)
	targetID := strings.TrimSpace(req.TargetID)
	if strings.TrimSpace(req.Target.Type) != "" {
		targetType = strings.TrimSpace(req.Target.Type)
	}
	if strings.TrimSpace(req.Target.ID) != "" {
		targetID = strings.TrimSpace(req.Target.ID)
	}
	if intentID == "" || kind == "" || title == "" || body == "" || targetType == "" || targetID == "" {
		writeError(w, http.StatusBadRequest, "intent_id, kind, title, body, target_type, and target_id are required")
		return
	}
	if !notification.SupportedTargetType(targetType) {
		writeError(w, http.StatusBadRequest, "target_type must be one of record, artifact, question, entity, place, theme, decision, chapter, or reflection")
		return
	}

	scheduledAt := time.Now().UTC()
	if rawScheduledAt := strings.TrimSpace(req.ScheduledAt); rawScheduledAt != "" {
		parsed, err := time.Parse(time.RFC3339, rawScheduledAt)
		if err != nil {
			writeError(w, http.StatusBadRequest, "scheduled_at must be RFC3339")
			return
		}
		scheduledAt = parsed.UTC()
	}

	enqueueReport, err := s.pushDeliveryWorker.EnqueueIntent(
		r.Context(),
		claims.UserID,
		notification.DeliveryIntent{
			IntentID:     intentID,
			Kind:         kind,
			Title:        title,
			Body:         body,
			TargetType:   targetType,
			TargetID:     targetID,
			PrivacyLevel: strings.TrimSpace(req.PrivacyLevel),
			DeepLink:     strings.TrimSpace(req.DeepLink),
			Target:       req.Target,
			Payload:      req.Payload,
			ScheduledAt:  scheduledAt,
		},
		time.Now().UTC(),
	)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "failed to enqueue push delivery")
		return
	}

	deliveryReport, err := s.pushDeliveryWorker.DeliverDue(r.Context(), time.Now().UTC(), 32)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "failed to deliver queued push notifications")
		return
	}

	writeJSON(w, http.StatusOK, pushEnqueueResponse{
		Accepted:     true,
		UserID:       claims.UserID,
		QueuedCount:  enqueueReport.QueuedCount,
		SkippedCount: enqueueReport.SkippedCount,
		SentCount:    deliveryReport.SentCount,
		FailedCount:  deliveryReport.FailedCount,
	})
}

func (s *Server) handlePushDeliveryWriteback(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.ClaimsFromContext(r.Context())
	if !ok {
		writeError(w, http.StatusUnauthorized, "missing auth claims")
		return
	}

	var req pushDeliveryWritebackRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid JSON body")
		return
	}

	deviceID := strings.TrimSpace(req.DeviceID)
	intentID := strings.TrimSpace(req.IntentID)
	action := strings.TrimSpace(req.Action)
	targetType := strings.TrimSpace(req.TargetType)
	targetID := strings.TrimSpace(req.TargetID)
	if deviceID == "" || intentID == "" || action == "" || targetType == "" || targetID == "" {
		writeError(w, http.StatusBadRequest, "device_id, intent_id, action, target_type, and target_id are required")
		return
	}

	occurredAt := time.Now().UTC()
	if rawOccurredAt := strings.TrimSpace(req.OccurredAt); rawOccurredAt != "" {
		parsed, err := time.Parse(time.RFC3339, rawOccurredAt)
		if err != nil {
			writeError(w, http.StatusBadRequest, "occurred_at must be RFC3339")
			return
		}
		occurredAt = parsed.UTC()
	}

	if err := s.pushTokens.InsertPushDeliveryEvent(r.Context(), db.PushDeliveryEvent{
		UserID:     claims.UserID,
		DeviceID:   deviceID,
		IntentID:   intentID,
		Action:     action,
		Kind:       strings.TrimSpace(req.Kind),
		TargetType: targetType,
		TargetID:   targetID,
		OccurredAt: occurredAt,
	}); err != nil {
		writeError(w, http.StatusInternalServerError, "failed to write push delivery event")
		return
	}

	writeJSON(w, http.StatusOK, pushDeliveryWritebackResponse{
		Accepted: true,
		UserID:   claims.UserID,
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

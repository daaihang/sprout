package http

import (
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"time"

	"sprout/server/internal/ai"
	"sprout/server/internal/auth"
)

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

	start := time.Now()
	result, err := s.aiProvider.Analyze(r.Context(), req, ai.UserContext{
		UserID: "preview",
		Tier:   "preview",
	})
	s.recordAI("analyze_preview", result.Provider, result.Usage, time.Since(start), err)
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

	start := time.Now()
	result, err := s.aiProvider.Analyze(r.Context(), req, ai.UserContext{
		UserID: claims.UserID,
		Tier:   claims.Tier,
	})
	s.recordAI("analyze_record", result.Provider, result.Usage, time.Since(start), err)
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

func (s *Server) handleAnalyzeV7(w http.ResponseWriter, r *http.Request) {
	user, ok := userContextFromRequest(w, r)
	if !ok {
		return
	}

	var req ai.AnalyzeV7Request
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid JSON body")
		return
	}
	if err := req.Validate(); err != nil {
		writeError(w, http.StatusBadRequest, "invalid analyze v7 request")
		return
	}
	if !s.allowAIRequest(w, r, user.UserID, "analyze_v7") {
		return
	}

	start := time.Now()
	result, err := s.aiProvider.AnalyzeV7(r.Context(), req, user)
	s.recordAI("analyze_v7", result.Provider, result.Usage, time.Since(start), err)
	if err != nil {
		writeAIProviderError(w, r, "analysis v7 request failed", err)
		return
	}

	writeJSON(w, http.StatusOK, analyzeV7ResponseEnvelope{
		AnalyzeV7Response: result.Response,
		Meta: analyzeMeta{
			Provider:      result.Provider,
			Model:         result.Model,
			Usage:         result.Usage,
			RequestID:     requestIDFromContext(r.Context()),
			PromptVersion: ai.V7AnalyzePromptVersion,
		},
	})
}

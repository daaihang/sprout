package http

import (
	"encoding/json"
	"net/http"
	"time"

	"sprout/server/internal/ai"
)

func (s *Server) handleAnalyze(w http.ResponseWriter, r *http.Request) {
	user, ok := userContextFromRequest(w, r)
	if !ok {
		return
	}

	var req ai.AnalysisRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid JSON body")
		return
	}
	if err := req.Validate(); err != nil {
		writeError(w, http.StatusBadRequest, "invalid analysis request")
		return
	}
	if !s.allowAIRequest(w, r, user.UserID, "analysis") {
		return
	}

	start := time.Now()
	result, err := s.aiProvider.Analyze(r.Context(), req, user)
	s.recordAI("analysis", result.Provider, result.Usage, time.Since(start), err)
	if err != nil {
		writeAIProviderError(w, r, "analysis request failed", err)
		return
	}

	writeJSON(w, http.StatusOK, analyzeMemoryResponseEnvelope{
		AnalysisResponse: result.Response,
		Meta: analyzeMeta{
			Provider:      result.Provider,
			Model:         result.Model,
			Usage:         result.Usage,
			RequestID:     requestIDFromContext(r.Context()),
			PromptVersion: ai.AnalysisPromptVersion,
		},
	})
}

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

	start := time.Now()
	result, err := s.aiProvider.GenerateReflection(r.Context(), providerReq, ai.UserContext{
		UserID: claims.UserID,
		Tier:   claims.Tier,
	})
	s.recordAI("reflection_generate", result.Provider, result.Usage, time.Since(start), err)
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

	start := time.Now()
	result, err := s.aiProvider.ReplayReflection(r.Context(), providerReq, ai.UserContext{
		UserID: claims.UserID,
		Tier:   claims.Tier,
	})
	s.recordAI("reflection_replay", result.Provider, result.Usage, time.Since(start), err)
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

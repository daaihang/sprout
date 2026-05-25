package http

import (
	"encoding/json"
	"net/http"
	"time"

	"sprout/server/internal/ai"
)

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
	if !s.allowAIRequest(w, r, user.UserID, "refine_transcript") {
		return
	}

	start := time.Now()
	result, err := s.aiProvider.RefineTranscript(r.Context(), req, user)
	s.recordAI("refine_transcript", result.Provider, result.Usage, time.Since(start), err)
	if err != nil {
		writeAIProviderError(w, r, "transcript refinement failed", err)
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
	if !s.allowAIRequest(w, r, user.UserID, "suggest_questions") {
		return
	}

	start := time.Now()
	result, err := s.aiProvider.SuggestQuestions(r.Context(), req, user)
	s.recordAI("suggest_questions", result.Provider, result.Usage, time.Since(start), err)
	if err != nil {
		writeAIProviderError(w, r, "question suggestion failed", err)
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
	if !s.allowAIRequest(w, r, user.UserID, "suggest_chapters") {
		return
	}

	start := time.Now()
	result, err := s.aiProvider.SuggestChapters(r.Context(), req, user)
	s.recordAI("suggest_chapters", result.Provider, result.Usage, time.Since(start), err)
	if err != nil {
		writeAIProviderError(w, r, "chapter suggestion failed", err)
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
	if !s.allowAIRequest(w, r, user.UserID, "analyze_photo_semantics") {
		return
	}

	start := time.Now()
	result, err := s.aiProvider.AnalyzePhotoSemantics(r.Context(), req, user)
	s.recordAI("analyze_photo_semantics", result.Provider, result.Usage, time.Since(start), err)
	if err != nil {
		writeAIProviderError(w, r, "photo semantic analysis failed", err)
		return
	}

	writeJSON(w, http.StatusOK, photoSemanticAnalysisResponseEnvelope{
		PhotoSemanticAnalysisResponse: result.Response,
		Meta:                          s.metaForResult(r, result.Provider, result.Model, result.Usage),
	})
}

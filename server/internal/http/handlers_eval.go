package http

import (
	"net/http"
	"strings"
	"time"

	"sprout/server/internal/ai"
)

func (s *Server) handleCloudIntelligenceEval(w http.ResponseWriter, r *http.Request) {
	user, ok := userContextFromRequest(w, r)
	if !ok {
		return
	}
	if !s.allowAIRequest(w, r, user.UserID, "provider_eval") {
		return
	}

	cases := []cloudIntelligenceEvalCase{
		s.evalTranscriptRefinement(r, user),
		s.evalQuestionSuggestion(r, user),
	}
	writeJSON(w, http.StatusOK, cloudIntelligenceEvalResponse{
		PromptVersion: ai.V6PromptVersion,
		RequestID:     requestIDFromContext(r.Context()),
		Cases:         cases,
	})
}

func (s *Server) evalTranscriptRefinement(r *http.Request, user ai.UserContext) cloudIntelligenceEvalCase {
	operation := "refine_transcript"
	req := ai.TranscriptRefinementRequest{
		SchemaVersion: 1,
		Locale:        "en-US",
		RawTranscript: "um today I kept thinking about the project and and I need to write down the smaller next step",
		Style:         "clean_spoken_memory",
		AllowTitle:    true,
	}
	start := time.Now()
	result, err := s.aiProvider.RefineTranscript(r.Context(), req, user)
	s.recordAI(operation, result.Provider, result.Usage, time.Since(start), err)
	if err != nil {
		return evalErrorCase(operation, err)
	}
	return cloudIntelligenceEvalCase{
		Operation: operation,
		Success:   strings.TrimSpace(result.Response.RefinedTranscript) != "",
		Provider:  result.Provider,
		Model:     result.Model,
	}
}

func (s *Server) evalQuestionSuggestion(r *http.Request, user ai.UserContext) cloudIntelligenceEvalCase {
	operation := "suggest_questions"
	req := ai.QuestionSuggestionRequest{
		SchemaVersion: 1,
		Locale:        "en-US",
		Target: ai.IntelligenceTarget{
			Type: "record",
			ID:   "eval-record",
			Kind: "dailyReflection",
		},
		Evidence: []ai.EvidenceSnippet{
			{RecordID: "eval-record", Snippet: "I mentioned work pressure twice this week and wanted to remember the concrete blocker."},
		},
		UserPreferences: ai.QuestionSuggestionPreferences{
			AllowSensitiveQuestions: false,
			QuestionTone:            "evidence_based",
		},
	}
	start := time.Now()
	result, err := s.aiProvider.SuggestQuestions(r.Context(), req, user)
	s.recordAI(operation, result.Provider, result.Usage, time.Since(start), err)
	if err != nil {
		return evalErrorCase(operation, err)
	}
	return cloudIntelligenceEvalCase{
		Operation: operation,
		Success:   len(result.Response.Questions) > 0,
		Provider:  result.Provider,
		Model:     result.Model,
	}
}

func evalErrorCase(operation string, err error) cloudIntelligenceEvalCase {
	class, retryable := classifyAIError(err)
	return cloudIntelligenceEvalCase{
		Operation:  operation,
		Success:    false,
		Error:      err.Error(),
		ErrorClass: string(class),
		Retryable:  retryable,
	}
}

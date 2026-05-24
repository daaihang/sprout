package http

import (
	"net/http"

	"sprout/server/internal/ai"
	"sprout/server/internal/auth"
)

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
		Provider:      provider,
		Model:         model,
		Usage:         usage,
		RequestID:     requestIDFromContext(r.Context()),
		PromptVersion: ai.V6PromptVersion,
	}
}

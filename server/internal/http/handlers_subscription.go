package http

import (
	"net/http"

	"sprout/server/internal/auth"
)

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
